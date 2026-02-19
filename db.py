# db.py
import json
import os
import platform
import socket
import sqlite3
from datetime import datetime, timezone
from utils.resource_path import user_data_path

# ---------------------------------------------------------
# FILE PATHS
# ---------------------------------------------------------
OLD_DB_FILE = user_data_path("mypsy.db")            # legacy combined DB
LOCAL_DB_FILE = user_data_path("mypsy_local.db")     # clinician / settings (plain)
PATIENT_DB_FILENAME = "mypsy_patients.db"            # default patient DB name


# =========================================================
# LOCAL DATABASE — clinician details + settings (no password)
# =========================================================
class LocalDatabase:
    def __init__(self):
        self.conn = sqlite3.connect(LOCAL_DB_FILE)
        self.conn.row_factory = sqlite3.Row
        self._create_tables()

    def _create_tables(self):
        cur = self.conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS clinician (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                full_name TEXT,
                role_title TEXT,
                discipline TEXT,
                registration_body TEXT,
                registration_number TEXT,
                phone TEXT,
                email TEXT,
                team_service TEXT,
                hospital_org TEXT,
                ward_department TEXT,
                signature_block TEXT,
                user_role TEXT DEFAULT 'admin'
            )
        """)
        # Migration: add user_role if missing (pre-existing DBs)
        try:
            cur.execute("ALTER TABLE clinician ADD COLUMN user_role TEXT DEFAULT 'admin'")
        except sqlite3.OperationalError:
            pass  # column already exists
        cur.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        """)
        self.conn.commit()

    # ---------------------------------------------------------
    # CLINICIAN — LOAD / SAVE
    # ---------------------------------------------------------
    def get_clinician_details(self):
        cur = self.conn.cursor()
        cur.execute("SELECT * FROM clinician WHERE id = 1")
        return cur.fetchone()

    def save_clinician_details(
        self, full_name, role_title, discipline,
        registration_body, registration_number,
        phone, email, team_service,
        hospital_org, ward_department,
        signature_block
    ):
        cur = self.conn.cursor()
        cur.execute("DELETE FROM clinician WHERE id = 1")
        cur.execute("""
            INSERT INTO clinician (
                id, full_name, role_title, discipline,
                registration_body, registration_number,
                phone, email, team_service,
                hospital_org, ward_department,
                signature_block
            )
            VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            full_name, role_title, discipline,
            registration_body, registration_number,
            phone, email, team_service,
            hospital_org, ward_department,
            signature_block
        ))
        self.conn.commit()

    # ---------------------------------------------------------
    # SETTINGS — key/value store
    # ---------------------------------------------------------
    def get_setting(self, key: str) -> str | None:
        cur = self.conn.cursor()
        cur.execute("SELECT value FROM settings WHERE key = ?", (key,))
        row = cur.fetchone()
        return row["value"] if row else None

    def set_setting(self, key: str, value: str):
        cur = self.conn.cursor()
        cur.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
            (key, value),
        )
        self.conn.commit()


# =========================================================
# PATIENT DATABASE — shared SQLite file (drive-encrypted)
# =========================================================
class PatientDatabase:
    _STALE_HOURS = 4  # prune sessions older than this

    def __init__(self, db_path: str):
        self._filepath = db_path
        self._sessions_path = db_path + ".sessions"
        self._session_id = f"{socket.gethostname()}:{os.getpid()}"

        self._register_session()

        self.conn = sqlite3.connect(db_path, timeout=10)
        self.conn.row_factory = sqlite3.Row
        # journal_mode=DELETE is safe for network/exFAT filesystems
        self.conn.execute("PRAGMA journal_mode=DELETE")
        # busy_timeout lets SQLite retry on write contention (concurrent users)
        self.conn.execute("PRAGMA busy_timeout=5000")
        self._create_tables()

    # ---------------------------------------------------------
    # SESSION REGISTRY (.sessions) — multi-user awareness
    # ---------------------------------------------------------
    def _register_session(self):
        """Register this session in the shared session registry.

        The registry is informational — it tracks who is connected
        but does NOT block concurrent access. SQLite's built-in
        locking (with busy_timeout) handles write serialisation.
        """
        sessions = self._read_sessions()

        # Prune stale sessions (dead processes on same host, or aged-out)
        live = []
        my_host = socket.gethostname()
        now = datetime.now(timezone.utc)
        for s in sessions:
            same_host = (s.get("host") == my_host)
            if same_host:
                try:
                    os.kill(s["pid"], 0)
                    live.append(s)  # still alive
                except OSError:
                    pass  # dead — drop it
            else:
                # Remote host — keep if under stale threshold
                try:
                    since = datetime.fromisoformat(s.get("since", ""))
                    if (now - since).total_seconds() / 3600 < self._STALE_HOURS:
                        live.append(s)
                except (ValueError, TypeError):
                    pass  # unparseable — drop it

        # Log other active sessions
        others = [s for s in live if s.get("host") != my_host or s.get("pid") != os.getpid()]
        if others:
            names = ", ".join(f"{s.get('user','?')}@{s.get('host','?')}" for s in others)
            print(f"[PatientDB] Other active sessions: {names}")

        # Add ourselves
        live.append({
            "pid": os.getpid(),
            "host": my_host,
            "user": os.environ.get("USER") or os.environ.get("USERNAME", "unknown"),
            "since": now.isoformat(),
        })

        self._write_sessions(live)
        print(f"[PatientDB] Session registered ({len(live)} active)")

    def _unregister_session(self):
        """Remove this session from the registry."""
        sessions = self._read_sessions()
        my_host = socket.gethostname()
        my_pid = os.getpid()
        updated = [s for s in sessions
                    if not (s.get("host") == my_host and s.get("pid") == my_pid)]
        self._write_sessions(updated)
        remaining = len(updated)
        print(f"[PatientDB] Session unregistered ({remaining} remaining)")

    def _read_sessions(self):
        """Read the session registry file."""
        if not os.path.exists(self._sessions_path):
            return []
        try:
            with open(self._sessions_path, "r") as f:
                data = json.load(f)
            return data if isinstance(data, list) else []
        except (json.JSONDecodeError, OSError):
            return []

    def _write_sessions(self, sessions):
        """Write the session registry file."""
        try:
            with open(self._sessions_path, "w") as f:
                json.dump(sessions, f, indent=2)
        except OSError as e:
            print(f"[PatientDB] Warning: could not write sessions file: {e}")

    def close(self):
        """Close the database connection and unregister the session."""
        try:
            self.conn.close()
        except Exception as e:
            print(f"[PatientDB] Warning: error closing connection: {e}")
        self._unregister_session()

    def _create_tables(self):
        cur = self.conn.cursor()

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                first_name TEXT,
                last_name TEXT,
                date_of_birth TEXT,
                nhs_number TEXT,
                address TEXT,
                phone TEXT,
                email TEXT,
                gp_name TEXT,
                gp_address TEXT,
                next_of_kin TEXT,
                next_of_kin_phone TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_medication (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                medication_name TEXT,
                dose TEXT,
                frequency TEXT,
                start_date TEXT,
                end_date TEXT,
                notes TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_clinical_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                condition TEXT,
                diagnosis_date TEXT,
                notes TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_blood_result (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                test_name TEXT,
                result_value TEXT,
                unit TEXT,
                reference_range TEXT,
                test_date TEXT,
                notes TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_vital (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                vital_type TEXT,
                value TEXT,
                recorded_at TEXT DEFAULT CURRENT_TIMESTAMP,
                notes TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_risk_assessment (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                risk_type TEXT,
                risk_level TEXT,
                description TEXT,
                assessed_at TEXT DEFAULT CURRENT_TIMESTAMP,
                assessor TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS patient_document (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER NOT NULL,
                document_name TEXT,
                document_type TEXT,
                file_path TEXT,
                uploaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
                notes TEXT,
                FOREIGN KEY (patient_id) REFERENCES patient(id)
            )
        """)

        self.conn.commit()

    # ---------------------------------------------------------
    # PATIENT CRUD
    # ---------------------------------------------------------
    def add_patient(self, **kwargs):
        cols = ", ".join(kwargs.keys())
        placeholders = ", ".join("?" for _ in kwargs)
        cur = self.conn.cursor()
        cur.execute(
            f"INSERT INTO patient ({cols}) VALUES ({placeholders})",
            tuple(kwargs.values()),
        )
        self.conn.commit()
        return cur.lastrowid

    def update_patient(self, patient_id: int, **kwargs):
        sets = ", ".join(f"{k} = ?" for k in kwargs)
        cur = self.conn.cursor()
        cur.execute(
            f"UPDATE patient SET {sets}, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (*kwargs.values(), patient_id),
        )
        self.conn.commit()

    def get_patient(self, patient_id: int):
        cur = self.conn.cursor()
        cur.execute("SELECT * FROM patient WHERE id = ?", (patient_id,))
        return cur.fetchone()

    def search_patients(self, query: str):
        cur = self.conn.cursor()
        cur.execute(
            "SELECT * FROM patient WHERE first_name LIKE ? OR last_name LIKE ? OR nhs_number LIKE ? ORDER BY last_name, first_name",
            (f"%{query}%", f"%{query}%", f"%{query}%"),
        )
        return cur.fetchall()

    def get_all_patients(self):
        cur = self.conn.cursor()
        cur.execute("SELECT * FROM patient ORDER BY last_name, first_name")
        return cur.fetchall()

    def delete_patient(self, patient_id: int):
        cur = self.conn.cursor()
        for table in (
            "patient_medication", "patient_clinical_history",
            "patient_blood_result", "patient_vital",
            "patient_risk_assessment", "patient_document",
        ):
            cur.execute(f"DELETE FROM {table} WHERE patient_id = ?", (patient_id,))
        cur.execute("DELETE FROM patient WHERE id = ?", (patient_id,))
        self.conn.commit()


# ---------------------------------------------------------
# BACKWARD COMPATIBILITY — old import keeps working
# from db import DatabaseManager as Database
# ---------------------------------------------------------
DatabaseManager = LocalDatabase


# =========================================================
# MIGRATION — move clinician data from old mypsy.db
# =========================================================
def migrate_old_database():
    """Migrate clinician data from the legacy combined DB into the new local DB.

    Called once on first run after the split.  Returns True if migration
    occurred, False if there was nothing to migrate.
    """
    if not os.path.exists(OLD_DB_FILE):
        return False

    # Already migrated?
    if os.path.exists(LOCAL_DB_FILE):
        return False

    print(f"[Migration] Found legacy DB at {OLD_DB_FILE}")

    try:
        old = sqlite3.connect(OLD_DB_FILE)
        old.row_factory = sqlite3.Row

        local = LocalDatabase()
        try:
            row = old.execute("SELECT * FROM clinician WHERE id = 1").fetchone()
            if row:
                local.save_clinician_details(
                    row["full_name"], row["role_title"], row["discipline"],
                    row["registration_body"], row["registration_number"],
                    row["phone"], row["email"], row["team_service"],
                    row["hospital_org"], row["ward_department"],
                    row["signature_block"],
                )
                print("[Migration] Clinician data migrated to local DB")
        except Exception as e:
            print(f"[Migration] Clinician migration skipped: {e}")

        old.close()

        # Rename old file so migration doesn't re-run
        backup = OLD_DB_FILE + ".bak"
        os.rename(OLD_DB_FILE, backup)
        print(f"[Migration] Old DB backed up to {backup}")

        return True

    except Exception as e:
        print(f"[Migration] ERROR: {e}")
        return False

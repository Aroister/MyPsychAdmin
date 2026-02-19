# db_crypto.py
import base64
import hashlib
import os
import sqlite3
import tempfile

from cryptography.fernet import Fernet, InvalidToken


def derive_key(password: str, salt: bytes | None = None) -> tuple[bytes, bytes]:
    """Derive a Fernet-compatible key from a password using PBKDF2.

    Returns (fernet_key, salt).  If *salt* is None a fresh 16-byte salt is
    generated.
    """
    if salt is None:
        salt = os.urandom(16)
    raw = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, iterations=480_000)
    fernet_key = base64.urlsafe_b64encode(raw)
    return fernet_key, salt


# --- file format: SALT (16 bytes) || Fernet token (rest) ---

def encrypt_db(conn: sqlite3.Connection, filepath: str, password: str) -> None:
    """Dump an in-memory SQLite database to an encrypted file."""
    # Serialize the in-memory DB to bytes
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    try:
        tmp.close()
        disk = sqlite3.connect(tmp.name)
        conn.backup(disk)
        disk.close()
        with open(tmp.name, "rb") as f:
            plaintext = f.read()
    finally:
        os.unlink(tmp.name)

    salt = os.urandom(16)
    key, salt = derive_key(password, salt)
    token = Fernet(key).encrypt(plaintext)

    with open(filepath, "wb") as f:
        f.write(salt)
        f.write(token)


def decrypt_db(filepath: str, password: str) -> sqlite3.Connection:
    """Decrypt an encrypted DB file and return an in-memory SQLite connection.

    Raises ``InvalidToken`` if the password is wrong.
    """
    with open(filepath, "rb") as f:
        salt = f.read(16)
        token = f.read()

    key, _ = derive_key(password, salt)
    plaintext = Fernet(key).decrypt(token)

    # Write plaintext to a temp file, then load into memory
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    try:
        tmp.write(plaintext)
        tmp.close()
        disk = sqlite3.connect(tmp.name)
        mem = sqlite3.connect(":memory:")
        disk.backup(mem)
        disk.close()
    finally:
        os.unlink(tmp.name)

    mem.row_factory = sqlite3.Row
    return mem

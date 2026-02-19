# ============================================================
#  HISTORY EXTRACTOR V12E — FULL EXPLICIT PIPELINE ONLY
#  RIO vs CARENOTES chosen by dropdown → NO AUTODETECT ANYWHERE
#  Avie Luthra — MyPsy 2.4
# ============================================================

from __future__ import annotations
import re
from datetime import datetime, timedelta

DEBUG = True
print(">>> ACTIVE EXTRACTOR FILE:", __file__)

# ============================================================
#  ORIGINAL 18 CANONICAL CATEGORIES
# ============================================================

CATEGORIES_ORDERED = [
    "Legal",
    "Diagnosis",
    "Circumstances of Admission",
    "History of Presenting Complaint",
    "Past Psychiatric History",
    "Medication History",
    "Drug and Alcohol History",
    "Past Medical History",
    "Forensic History",
    "Personal History",
    "Mental State Examination",
    "Risk",
    "Physical Examination",
    "ECG",
    "Impression",
    "Plan",
    "Capacity Assessment",
    "Summary",
]

CATEGORY_WEIGHTS = {cat: i for i, cat in enumerate(CATEGORIES_ORDERED, 1)}


# ============================================================
#  NORMALISERS
# ============================================================

def normalise(text: str) -> str:
    if not text:
        return ""
    return re.sub(r"\s+", " ", text).strip().lower()

def _norm(s: str) -> str:
    if not s:
        return ""
    t = s.strip().lower()
    t = re.sub(r"[\s\-\–\:]+$", "", t)
    return re.sub(r"\s+", " ", t)


# ============================================================
#  CATEGORY TERMS
# ============================================================

CATEGORY_TERMS = {
    "Legal": {
        "id": 1,
        "terms": [
            "legal", "legal status", "status", "mha status", "mha",
            "section", "detained",
        ],
    },
    "Diagnosis": {
        "id": 2,
        "terms": [
            "diagnosis", "diagnoses", "diagnosis of", "diagnosed with",
            "previous diagnosis", "icd",
        ],
    },
    "Circumstances of Admission": {
        "id": 3,
        "terms": [
            "circumstances of admission", "circumstances leading to",
            "background and circumstances", "background",
            "presenting circumstance", "presenting complaint",
            "presenting history", "pc", "assessment", "history",
            "referral source",
        ],
    },
    "History of Presenting Complaint": {
        "id": 4,
        "terms": [
            "history of presenting complaint", "hxpc", "hpc", "pc",
            "presenting complaint", "presenting issue", "presentation",
        ],
    },
    "Past Psychiatric History": {
        "id": 5,
        "terms": [
            "past psychiatric history", "psychiatric history",
            "past psych", "pph", "psych hx", "previous admissions",
            "previous mh history",
        ],
    },
    "Medication History": {
        "id": 6,
        "terms": [
            "medication history", "drug history", "dhx", "medication",
            "allerg", "allergies", "medications", "regular medication",
            "current medication",
        ],
    },
    "Drug and Alcohol History": {
        "id": 7,
        "terms": [
            "drug history", "alcohol history", "substance use",
            "substance misuse", "drugs", "alcohol", "illicit",
        ],
    },
    "Past Medical History": {
        "id": 8,
        "terms": [
            "past medical history", "medical history", "pmh",
            "physical health", "physical hx",
        ],
    },
    "Forensic History": {
        "id": 9,
        "terms": [
            "forensic history", "forensic", "offence", "offending",
            "criminal", "police", "charges",
        ],
    },
    "Personal History": {
        "id": 10,
        "terms": [
            "personal history", "social history", "social hx",
            "family history", "fhx", "relationships", "occupation",
            "employment", "childhood", "developmental",
        ],
    },
    "Mental State Examination": {
        "id": 11,
        "terms": [
            "mental state examination", "mental state", "mse",
            "appearance", "behaviour", "speech", "mood", "affect",
            "thought", "perception", "cognition", "insight",
        ],
    },
    "Risk": {
        "id": 12,
        "terms": [
            "risk", "suicide", "self harm", "violence",
            "risk assessment", "harm", "risk history",
        ],
    },
    "Physical Examination": {
        "id": 13,
        "terms": [
            "physical examination", "examination", "o/e",
            "observations", "obs",
        ],
    },
    "ECG": {"id": 14, "terms": ["ecg", "electrocardiogram"]},
    "Impression": {
        "id": 15,
        "terms": [
            "impression", "formulation", "overview",
            "clinical summary", "summary of presentation",
        ],
    },
    "Plan": {
        "id": 16,
        "terms": [
            "plan", "management", "treatment plan",
            "next steps", "actions",
        ],
    },
    "Capacity Assessment": {
        "id": 17,
        "terms": [
            "capacity", "mental capacity", "mca",
            "capacity assessment",
        ],
    },
    "Summary": {
        "id": 18,
        "terms": [
            "summary", "overall", "patient seen", "review",
        ],
    },
}


# ============================================================
#  HEADER DETECTION
# ============================================================

HEADER_LOOKUP = {}
for cat, meta in CATEGORY_TERMS.items():
    for t in meta["terms"]:
        HEADER_LOOKUP.setdefault(_norm(t), []).append(cat)


def _map_special(cat):
    if cat == "Capacity Assessment":
        return "Mental State Examination"
    if cat == "Summary":
        return "Impression"
    return cat


def _detect_header(line):
    nl = _norm(line)
    words = line.split()

    if ":" not in line and "-" not in line:
        if len(words) <= 2 and nl not in HEADER_LOOKUP:
            return None

    best = None
    best_w = -1

    for term, cats in HEADER_LOOKUP.items():
        if nl == term or nl.startswith(term):
            for c in cats:
                mapped = _map_special(c)
                w = CATEGORY_WEIGHTS.get(mapped, 0)
                if w > best_w:
                    best = mapped
                    best_w = w

    return best


# ============================================================
#  BLOCK SPLITTING
# ============================================================

def split_into_header_blocks(text):
    lines = text.splitlines()
    blocks = []
    cur_cat = None
    cur_lines = []

    def flush():
        nonlocal cur_lines, cur_cat
        if cur_lines:
            blocks.append({
                "category": cur_cat,
                "text": "\n".join(cur_lines).strip()
            })
            cur_lines = []

    for line in lines:
        d = _detect_header(line)
        if d:
            flush()
            cur_cat = d
            cur_lines = [line]
        else:
            cur_lines.append(line)

    flush()
    return blocks


def split_block_on_internal_headers(block):
    text = block["text"]
    lines = text.splitlines()

    subs = []
    cur_cat = block["category"]
    cur_lines = []

    def flush():
        nonlocal cur_lines, cur_cat
        if cur_lines:
            clean = cur_lines[:]
            if clean and _norm(clean[0]) in HEADER_LOOKUP:
                clean = clean[1:]
            subs.append({"category": cur_cat, "text": "\n".join(clean).strip()})
            cur_lines = []

    for line in lines:
        d = _detect_header(line)
        if d:
            flush()
            cur_cat = d
            cur_lines = [line]
        else:
            cur_lines.append(line)

    flush()
    return subs


def classify_blocks(blocks):
    out = []
    for b in blocks:
        subs = split_block_on_internal_headers(b)
        for sb in subs:
            if sb["category"]:
                out.append(sb)
            else:
                txt = sb["text"].lower()
                best = None
                best_score = 0
                for cat, meta in CATEGORY_TERMS.items():
                    mapped = _map_special(cat)
                    score = 0
                    for term in meta["terms"]:
                        if _norm(term) in txt:
                            score += CATEGORY_WEIGHTS[mapped]
                    if score > best_score:
                        best = mapped
                        best_score = score
                out.append({
                    "category": best or "Impression",
                    "text": sb["text"],
                })
    return out


# ============================================================
#  RIO CLERKING ENGINE
# ============================================================

CLERKING_TRIGGERS_RIO = [
    "admission clerking", "clerking", "duty doctor admission",
    "new admission", "new transfer", "circumstances of admission",
    "circumstances leading to admission", "New Client Assesment",
]
CLERKING_TRIGGERS_RIO = [t.lower() for t in CLERKING_TRIGGERS_RIO]

ROLE_TRIGGERS_RIO = [
    "physician associate", "medical", "senior house officer",
    "sho", "ct1", "ct2", "ct3", "st4", "doctor",
]
ROLE_TRIGGERS_RIO = [r.lower() for r in ROLE_TRIGGERS_RIO]


def is_medical_type(t):
    if not t:
        return False
    t = t.lower()
    return ("med" in t or "doctor" in t or "clinician" in t or "physician" in t)


def find_clerkings_rio(notes, admission_dates):
    clerkings = []
    seen = set()

    for adm in admission_dates:
        win_start = adm
        win_end = adm + timedelta(days=10)

        if DEBUG:
            print(f"\n[RIO] Window {win_start} → {win_end}")

        medical_notes = [
            n for n in notes
            if win_start <= n["date"].date() <= win_end
            and is_medical_type(n.get("type", ""))
        ]

        if DEBUG:
            print(f"[RIO] Medical notes: {len(medical_notes)}")

        for n in medical_notes:
            txt = normalise(n.get("text", "") or n.get("content", ""))

            t_hit = any(t in txt for t in CLERKING_TRIGGERS_RIO)
            r_hit = any(r in txt for r in ROLE_TRIGGERS_RIO)

            if not t_hit or not r_hit:
                continue

            key = (n["date"].date(), txt[:120])
            if key in seen:
                continue
            seen.add(key)

            clerkings.append({
                "date": n["date"],
                "content": n.get("text", n.get("content", "")),
                "source_note": n,
            })

            if DEBUG:
                print("\n[RIO] ---- CLERKING FOUND ----")
                print(f"DATE: {n['date']}")
                print(f"PREVIEW: {n['content'][:200]}")
                print("[RIO] ------------------------")

    if DEBUG:
        print(f"[RIO] TOTAL CLERKINGS: {len(clerkings)}")

    return clerkings


# ============================================================
#  CARENOTES CLERKING ENGINE
# ============================================================

CARENOTES_STRONG = [
    "title:", "mental health:", "physical health:", "observation level",
    "medication:", "activities", "risk behaviours:", "section:",
    "confirmed by", "presenting complaint", "assessment",
]
CARENOTES_STRONG = [t.lower() for t in CARENOTES_STRONG]


def find_clerkings_carenotes(notes, admission_dates):
    clerkings = []
    seen = set()

    if DEBUG:
        print("\n[CN] === CARENOTES SEARCH ===")

    for adm in admission_dates:
        win_start = adm - timedelta(days=5)
        win_end = adm + timedelta(days=5)

        within = [
            n for n in notes
            if win_start <= n["date"].date() <= win_end
        ]

        if DEBUG:
            print(f"[CN] Window {win_start} → {win_end} | {len(within)} notes")

        for n in within:
            txt = normalise(n.get("text", "") or n.get("content", ""))
            hit = any(s in txt for s in CARENOTES_STRONG)
            if not hit:
                continue

            key = (n["date"].date(), txt[:200])
            if key in seen:
                continue
            seen.add(key)

            clerkings.append({
                "date": n["date"],
                "content": n.get("text", n.get("content", "")),
                "source_note": n,
            })

            if DEBUG:
                print("\n[CN] ---- CLERKING FOUND ----")
                print(f"DATE: {n['date']}")
                print(f"PREVIEW: {n['content'][:200]}")
                print("[CN] ------------------------")

            break

    if DEBUG:
        print(f"[CN] TOTAL CLERKINGS: {len(clerkings)}")

    return clerkings


# ============================================================
#  MERGE & DEDUPE
# ============================================================

def dedupe_history(history):
    """
    V11 PRESENTATION MERGE + CLEANING:
    - Merge entries for same date
    - Remove all empty lines
    - Keep flow continuous
    """
    out = {cat: [] for cat in CATEGORIES_ORDERED}

    for cat in CATEGORIES_ORDERED:
        grouped = {}

        # Group text blocks by date
        for entry in history.get(cat, []):
            d = entry["date"]
            grouped.setdefault(d, []).append(entry["text"])

        merged_entries = []

        for d, texts in grouped.items():
            # Split into lines, remove empty lines, re-join
            cleaned_lines = []
            for t in texts:
                for line in t.splitlines():
                    if line.strip():   # keep only non-empty lines
                        cleaned_lines.append(line.strip())

            combined = "\n".join(cleaned_lines)

            merged_entries.append({
                "date": d,
                "text": combined.strip()
            })

        merged_entries.sort(key=lambda e: e["date"])
        out[cat] = merged_entries

    return out


def merge_histories(histories):
    merged = {cat: [] for cat in CATEGORIES_ORDERED}

    for h in histories:
        for cat in CATEGORIES_ORDERED:
            merged[cat].extend(h.get(cat, []))

    for cat in CATEGORIES_ORDERED:
        merged[cat].sort(key=lambda e: e["date"])

    return merged




# ============================================================
#  APPLY HEADER ENGINE
# ============================================================

def extract_history_from_single_clerking(c):
    date = c["date"]
    content = c["content"]

    blocks = split_into_header_blocks(content)
    blocks = classify_blocks(blocks)

    hist = {cat: [] for cat in CATEGORIES_ORDERED}

    for b in blocks:
        cat = b["category"]
        if cat not in hist:
            continue
        hist[cat].append({"date": date, "text": b["text"]})

        if DEBUG:
            print(f"[HIST] → {cat}: {b['text'][:120]}")

    return hist


# ============================================================
#  MASTER EXTRACTOR — NO AUTODETECT EVER
# ============================================================

# In your `history_extractor_sections.py` (or wherever this belongs):

def extract_patient_history(notes, episodes=None, pipeline="rio", debug=False):
    global DEBUG
    DEBUG = debug

    if not notes:
        return {
            "admissions": [],
            "history": {cat: [] for cat in CATEGORIES_ORDERED}
        }

    # Handle case when episodes is None
    if episodes is None:
        episodes = []

    admission_dates = [ep["start"] for ep in episodes if ep["type"] == "inpatient"]

    if DEBUG:
        print("\n[HIST] ADMISSIONS:", admission_dates)
        print("[HIST] PIPELINE:", pipeline.upper())

    if pipeline == "carenotes":
        clerkings = find_clerkings_carenotes(notes, admission_dates)
    else:
        clerkings = find_clerkings_rio(notes, admission_dates)

    if DEBUG:
        print(f"[HIST] CLERKINGS FOUND: {len(clerkings)}")

    histories = [extract_history_from_single_clerking(c) for c in clerkings]

    if not histories:
        return {
            "admissions": admission_dates,
            "history": {cat: [] for cat in CATEGORIES_ORDERED}
        }

    merged = merge_histories(histories)
    deduped = dedupe_history(merged)

    return {"admissions": admission_dates, "history": deduped}


# ============================================================
#  UI FORMATTERS
# ============================================================

def convert_to_ui_format(history_dict):
    admissions = history_dict.get("admissions", [])
    hist = history_dict.get("history", {})

    print("\n===== DEBUG: History =====")
    print(f"History: {hist}")
    print("===== END DEBUG =====")

    by_date = {}

    for category in CATEGORIES_ORDERED:
        for e in hist.get(category, []):
            d = e["date"].strftime("%Y-%m-%d")
            by_date.setdefault(d, {})
            by_date[d].setdefault(category, "")
            if by_date[d][category]:
                by_date[d][category] += "\n" + e["text"]
            else:
                by_date[d][category] = e["text"]

    by_date = dict(sorted(by_date.items(), key=lambda kv: kv[0]))

    print("\n===== DEBUG: By Date =====")
    print(f"By Date: {by_date}")
    print("===== END DEBUG =====")

    return {"admissions": admissions, "by_date": by_date}



# ============================================================
#  NEW PANEL FORMATTER (FOR PatientHistoryPanel)
# ============================================================

def convert_to_panel_format(history_dict):
    """
    Convert extractor output into the structure required by PatientHistoryPanel.
    """
    hist = history_dict.get("history", {})

    out = {"categories": {}}

    for idx, cat in enumerate(CATEGORIES_ORDERED, start=1):
        entries = hist.get(cat, [])

        items = [
            {"date": e["date"], "text": e["text"]}
            for e in entries
            if e.get("text")
        ]

        out["categories"][idx] = {
            "name": cat,
            "items": items
        }

    return out

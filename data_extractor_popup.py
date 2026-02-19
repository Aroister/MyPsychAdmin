from __future__ import annotations

import os
import re
from collections import defaultdict
from utils.resource_path import resource_path

from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QComboBox, QFileDialog, QApplication, QCheckBox
)
from shared_data_store import get_shared_store

from importer_rio import parse_rio_file
from importer_carenotes import parse_carenotes_file
from utils.document_ingestor import ingest_documents
from PySide6.QtCore import QTimer
from timeline_builder import build_timeline
from history_extractor_sections import (
    extract_patient_history,
    convert_to_panel_format,
)
from PySide6.QtWidgets import QScrollArea


# ==================================================
# DOCUMENT TYPE ROUTING
# ==================================================

DOC_TYPE_MAP = {
    "Reports": "reports",
    "Letters": "letters",
    "Notes": "notes",
}


TRIBUNAL_QUESTION_CATEGORY_MAP = {
    1: "SUMMARY",
    2: "PAST_PSYCH",
    3: "SOCIAL_HISTORY",
    4: "BACKGROUND_HISTORY",
    5: "RISK",
    6: "RISK",
    7: "PHYSICAL_HEALTH",
    8: "PLAN",
    9: "PLAN",
}

# ==================================================
# CANONICAL CATEGORY ENUM (extractor outputs ONLY these)
# ==================================================

CANONICAL_CATEGORIES = {
    "FRONT_PAGE",
    "HISTORY_OF_PRESENTING_COMPLAINT",
    "PAST_PSYCH",
    "BACKGROUND_HISTORY",
    "SOCIAL_HISTORY",
    "FORENSIC",
    "DRUGS_AND_ALCOHOL",
    "PHYSICAL_HEALTH",
    "FUNCTION",
    "MENTAL_STATE",  # Fixed: was "MENTAL STATE" with space
    "SUMMARY",
    "PLAN",
}


CANONICAL_TO_UI_CATEGORY = {
    "FRONT_PAGE": "Front Page",
    "HISTORY_OF_PRESENTING_COMPLAINT": "History of Presenting Complaint",
    "PAST_PSYCH": "Past Psychiatric History",
    "BACKGROUND_HISTORY": "Background History",
    "SOCIAL_HISTORY": "Social History",
    "FORENSIC": "Forensic History",
    "DRUGS_AND_ALCOHOL": "Drug and Alcohol History",
    "PHYSICAL_HEALTH": "Physical Health",
    "FUNCTION": "Function – Relationships",
    "MENTAL_STATE": "Mental State",
    "SUMMARY": "Summary",
    "PLAN": "Plan",
}

RC_UI_TO_CANONICAL = {
    # Standard RC / UI labels
    "Forensic History": "FORENSIC",
    "Past Psychiatric History": "PAST_PSYCH",
    "Psychiatric History": "PAST_PSYCH",
    "History of Presenting Complaint": "HISTORY_OF_PRESENTING_COMPLAINT",
    "Background History": "BACKGROUND_HISTORY",
    "Drug and Alcohol History": "DRUGS_AND_ALCOHOL",
    "Social History": "SOCIAL_HISTORY",
    "Physical Health": "PHYSICAL_HEALTH",
    "Mental State Examination": "MENTAL_STATE",
    "Summary": "SUMMARY",
    "Plan": "PLAN",
    "Front Page": "FRONT_PAGE",
    # Additional mappings from history_extractor_sections.py CATEGORIES_ORDERED
    "Legal": "FRONT_PAGE",
    "Diagnosis": "SUMMARY",
    "Circumstances of Admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "Medication History": "PAST_PSYCH",
    "Past Medical History": "PHYSICAL_HEALTH",
    "Personal History": "BACKGROUND_HISTORY",
    "Risk": "SUMMARY",
    "Physical Examination": "PHYSICAL_HEALTH",
    "ECG": "PHYSICAL_HEALTH",
    "Impression": "SUMMARY",
    "Capacity Assessment": "MENTAL_STATE",
}
LETTER_CATEGORY_ORDER = [
    "FRONT_PAGE",
    "HISTORY_OF_PRESENTING_COMPLAINT",
    "PAST_PSYCH",
    "BACKGROUND_HISTORY",
    "DRUGS_AND_ALCOHOL",
    "SOCIAL_HISTORY",
    "FORENSIC",
    "PHYSICAL_HEALTH",
    "FUNCTION",
    "MENTAL_STATE",
    "SUMMARY",
    "PLAN",
]

CANONICAL_TO_LETTER_LABEL = {
    "FRONT_PAGE": "Front Page",
    "HISTORY_OF_PRESENTING_COMPLAINT": "History of Presenting Complaint",
    "PAST_PSYCH": "Psychiatric History",
    "BACKGROUND_HISTORY": "Background History",
    "DRUGS_AND_ALCOHOL": "Drug and Alcohol History",
    "SOCIAL_HISTORY": "Social History",
    "FORENSIC": "Forensic History",
    "PHYSICAL_HEALTH": "Physical Health",
    "FUNCTION": "Function",
    "MENTAL_STATE": "Mental State Examination",
    "SUMMARY": "Summary",
    "PLAN": "Plan",
}


FRONT_PAGE_ALLOWED_HEADINGS = {
    "basic information",
    "patient information",
    "current medication",
    "medication",
    "diagnosis",
    "name",
    "dob",
    "date of report",
    "author",
    "responsible clinician",
    "name of rc",
    "care coordinator",
}


# ==================================================
# HEADING → CATEGORY (semantic intent only)
# ==================================================

HEADING_CATEGORY_MAP = {
    # Summary / overview
    "summary": "SUMMARY",

    # Background history
    "personal history": "BACKGROUND_HISTORY",
    "past and personal history": "BACKGROUND_HISTORY",
    "background history": "BACKGROUND_HISTORY",

    # Social
    "social history": "SOCIAL_HISTORY",
    "current social circumstances": "SOCIAL_HISTORY",

    # Past psychiatric
    "psychiatric history": "PAST_PSYCH",
    "mental health history": "PAST_PSYCH",
    "progress during past admissions": "PAST_PSYCH",

    # History of presenting complaint
    "circumstances of admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "circumstances of current admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "current admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "progress since admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "progress during admission": "HISTORY_OF_PRESENTING_COMPLAINT",

    # Other clinical domains
    "forensic history": "FORENSIC",
    "drug history": "DRUGS_AND_ALCOHOL",
    "alcohol history": "DRUGS_AND_ALCOHOL",
    "substance misuse": "DRUGS_AND_ALCOHOL",
    "physical health": "PHYSICAL_HEALTH",
    "medical history": "PHYSICAL_HEALTH",

    # Plan / risk
    "plan": "PLAN",
    "risk": "PLAN",
    "safeguarding": "PLAN",
}


# ==================================================
# PAST PSYCH BEHAVIOUR RULES
# ==================================================

PAST_PSYCH_CONTINUATION_HEADINGS = (
    "progress during",
    "during ",
)

PAST_PSYCH_EXIT_CATEGORIES = {
    "HISTORY_OF_PRESENTING_COMPLAINT",    
    "BACKGROUND_HISTORY",
    "SOCIAL_HISTORY",
    "FORENSIC",
    "DRUGS_AND_ALCOHOL",
    "PHYSICAL_HEALTH",
    "PAST MEDICAL HISTORY",
    "PLAN",
    "SUMMARY",
}



# ==================================================
# HARD BLOCK SPLITS (control flow only)
# ==================================================

HARD_OVERRIDE_HEADINGS = {
    # History of presenting complaint
    "circumstances of admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "circumstances of current admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "progress since admission": "HISTORY_OF_PRESENTING_COMPLAINT",
    "current admission": "HISTORY_OF_PRESENTING_COMPLAINT",

    # Background
    "personal history": "BACKGROUND_HISTORY",
    "background history": "BACKGROUND_HISTORY",

    # 🔑 SOCIAL — ADD THIS
    "current social circumstances": "SOCIAL_HISTORY",
    "social history": "SOCIAL_HISTORY",

    # Drugs & alcohol
    "substance misuse": "DRUGS_AND_ALCOHOL",
    "drug history": "DRUGS_AND_ALCOHOL",
    "alcohol history": "DRUGS_AND_ALCOHOL",

    # Plan / risk
    "safeguarding": "PLAN",
    "risk": "PLAN",
    "risk history": "PLAN",
    "appendix of risk history": "PLAN",
}

# --------------------------------------------------
# HARD OVERRIDES — ALWAYS EXIT CURRENT BLOCK
# --------------------------------------------------
HARD_OVERRIDE_HEADINGS = {
    # History of presenting complaint
    "circumstances of admission": "HISTORY OF PRESENTING COMPLAINT",
    "circumstances of current admission": "HISTORY OF PRESENTING COMPLAINT",
    "progress since admission": "HISTORY OF PRESENTING COMPLAINT",
    "current admission": "HISTORY OF PRESENTING COMPLAINT",

    # Background
    "personal history": "BACKGROUND HISTORY",

    # Drugs & alcohol
    "substance misuse": "DRUGS_AND_ALCOHOL",
    "drug history": "DRUGS_AND_ALCOHOL",
    "alcohol history": "DRUGS_AND_ALCOHOL",

    # Plan / risk
    "safeguarding": "Plan",
    "risk": "Plan",
    "risk history": "Plan",
    "appendix of risk history": "Plan",
}

HARD_OVERRIDE_HEADINGS.update({
    "circumstances of current admission": "HISTORY OF PRESENTING COMPLAINT",
})


def _category_from_heading(text: str) -> str | None:
    t = text.lower().strip()

    # Strip leading numbering
    t = re.sub(r"^\d{1,2}\.\s*", "", t)
    t = t.rstrip(":")

    # -----------------------------------------
    # AUTHORITATIVE HPC
    # -----------------------------------------
    if (
        t.startswith("progress at ")
        or t.startswith("progress in ")
        or t.startswith("progress on ")
        or t == "progress in custody"
        or t == "current progress"
    ):
        return "History of Presenting Complaint"

    for key, category in HEADING_CATEGORY_MAP.items():
        if key in t:
            return category

    return None


AUTO_DETECT_CONFIDENCE_MIN = 6
# =========================================================
# FREE TEXT (LETTERS / GENERIC REPORTS)
# =========================================================
def extract_from_free_text(notes):
    items = []

    for n in notes:
        text = (n.get("text") or "").strip()
        if not text:
            continue

        items.append({
            "date": n.get("date"),
            "text": text,
            "source": {"report": "Free Text"},
        })

    return {
        "categories": {
            "Summary": {
                "name": "Summary",
                "items": items,
            }
        }
    }


# =========================================================
# RANGE DEFINITIONS (LOCKED)
# =========================================================
# =========================================================
# NOTE:
# Tribunal extraction is intentionally HEADING-DRIVEN.
# Numeric question ranges are NOT used, as real-world
# documents vary across trusts and OCR outputs.
# =========================================================



# =========================================================
# CORE RANGE EXTRACTOR
# =========================================================
def extract_by_ranges(notes, report_type: str):
    print("[DEBUG extract_by_ranges] first note keys:", notes[0].keys() if notes else None)
    print("[DEBUG extract_by_ranges] first note source:", notes[0].get("source") if notes else None)

    from collections import defaultdict
    if not notes:
        print("[RANGES] ⚠️ No notes supplied — aborting extract_by_ranges")
        return {"categories": {}}

    report_type = notes[0].get("report_type")
    if not report_type:
        print("[RANGES] ⚠️ Missing report_type in notes — aborting extract_by_ranges")
        return {"categories": {}}

    # ------------------------------------------------------------------
    # Tribunal heading-based routing (PRIMARY) — per report type
    # Uses the authoritative tribunal question wording you provided.
    # ------------------------------------------------------------------
    HEADING_RULES = {
        "medical": [
            (["index offence", "forensic history"], "Forensic History"),
            (["previous involvement with mental health services", "including any admissions"], "Past Psychiatric History"),
            (["reasons for any previous admission", "previous admission or recall"], "Past Psychiatric History"),
            (["circumstances leading up to the patient's current admission"], "Circumstances of Admission"),
            (["now suffering from a mental disorder"], "Diagnosis"),
            (["medical treatment has been prescribed", "provided, offered or is planned"], "Medication History"),
            (["summary of the patient's current progress", "behaviour, capacity and insight"], "History of Presenting Complaint"),
            (["incidents where the patient has harmed themselves", "harmed themselves or others", "threatened to harm"], "Risk"),
            (["damaged property", "threatened to damage property"], "Risk"),
            (["if the patient was discharged from hospital, would they likely", "dangerous to themselves or others"], "Risk"),
            (["how any risks can be managed effectively in the community", "including the use of any lawful conditions"], "Risk"),
            (["strengths"], "Strengths"),
            (["positive factors"], "Strengths"),
            (["recommendations to the tribunal"], "Summary"),
        ],
        "nursing": [
            (["nature of nursing care and medication currently being made available"], "Medication History"),
            (["does the patient have contact with relatives", "friends or other patients"], "Function – Relationships"),
            (["what community support does the patient have"], "Function – Relationships"),
            (["summary of the patient's current progress", "engagement with nursing staff", "self-care and insight"], "History of Presenting Complaint"),
            (["absent without leave", "failed to return when required after having been granted leave"], "Risk"),
            (["incidents in hospital where the patient has harmed themselves", "threatened harm to others"], "Risk"),
            (["incidents where the patient has damaged property", "threatened to damage property"], "Risk"),
            (["secluded or restrained"], "Risk"),
            (["in all other cases is the provision of medical treatment in hospital", "justified or necessary"], "Risk"),
            (["if the patient was discharged from hospital, would they be likely", "dangerous to themselves or others"], "Risk"),
            (["please explain how risks could be managed effectively in the community", "including the use of any lawful conditions"], "Plan"),
            (["understanding of, compliance with, and likely future willingness to accept"], "Plan"),
            (["strengths"], "Strengths"),
            (["positive factors"], "Strengths"),
            (["any other relevant information that the tribunal should know"], "Summary"),
            (["recommendations to the tribunal"], "Summary"),
        ],
        "social": [
            (["index offence", "forensic history"], "Forensic History"),
            (["previous involvement with mental health services", "including any admissions"], "Past Psychiatric History"),
            (["previous response to community support", "section 117 aftercare"], "Past Psychiatric History"),
            (["home and family circumstances"], "Background History"),
            (["housing or accommodation would be available"], "Background History"),
            (["financial position", "including benefit entitlements"], "Background History"),
            (["available opportunities for employment"], "Background History"),
            (["views of the patient's nearest relative"], "Background History"),
            (["care pathway", "section 117 after-care"], "Plan"),
            (["proposed care plan"], "Plan"),
            (["summary of the patient's current progress", "behaviour, compliance and insight"], "History of Presenting Complaint"),
            (["incidents in hospital where the patient has harmed themselves", "threatened harm to others"], "Risk"),
            (["incidents where the patient has damaged property", "threatened to damage property"], "Risk"),
            (["in all other cases is the provision of medical treatment in hospital", "justified or necessary"], "Risk"),
            (["if the patient was discharged from hospital, would they be likely", "dangerous to themselves or others"], "Risk"),
            (["known to any mappa", "mappa meeting or agency"], "Forensic History"),
            (["strengths"], "Strengths"),
            (["positive factors"], "Strengths"),
            (["any other relevant information that the tribunal should know"], "Summary"),
            (["recommendations to the tribunal"], "Summary"),
        ],
    }

    # Questions we should ignore (checkbox / admin / not useful). Taken from your tribunal breakdown.
    IGNORE_NUMBERS = {
        "medical": {10, 16, 19, 20, 11},  # Removed 13 - Strengths should be extracted
        "nursing": {5, 8, 15},
        "social": {14, 15, 19, 21, 22, 24, 25},  # Removed 13 - Strengths should be extracted
    }

    rules = HEADING_RULES.get(report_type, [])
    ignore_numbers = IGNORE_NUMBERS.get(report_type, set())
    

    # ------------------------------------------------------------------
    # Build full text from notes (handles DOCX tables because ingestor flattens to text)
    # ------------------------------------------------------------------
    full_text = "\n".join(
        (n.get("text") or n.get("content") or "").strip()
        for n in notes
        if (n.get("text") or n.get("content"))
    ).strip()

    if not full_text:
        return {"categories": {}}

    # ------------------------------------------------------------------
    # STRICT question header finder:
    # - multiline
    # - ONLY 1–2 digit numbers at line start -> avoids “412” garbage from tables
    # - supports "4." or "4)" and tabs/spaces
    # ------------------------------------------------------------------
    header_re = re.compile(r"(?m)^\s*(\d{1,2})\s*[\.\)]\s*(.+?)\s*$")

    matches = list(header_re.finditer(full_text))
    if not matches:
        # Fallback: treat whole document as Summary
        return {
            "categories": {
                "Summary": {
                    "name": "Summary",
                    "items": [{
                        "date": None,
                        "text": full_text,
                        "source": {
                            "report": report_type.title() + " Report",
                            "file": (
                                notes[0].get("source_meta", {}).get("file")
                                if notes
                                else "Unknown file"
                            ),
                        },
                    }],
                }
            }
        }
    parsed_blocks = []
    for i, m in enumerate(matches):
        qnum = int(m.group(1))
        qhead = (m.group(2) or "").strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(full_text)
        block = full_text[start:end].strip()

        parsed_blocks.append((qnum, qhead, block))

    print("[DEBUG extract_by_ranges] detected question numbers:", [q for q, _, _ in parsed_blocks])

    detected_question_numbers = [q for q, _, _ in parsed_blocks]
    
    is_tribunal_style = (
        report_type == "medical"
        and isinstance(detected_question_numbers, (list, tuple))
        and len(detected_question_numbers) >= 5
    )
    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _classify_by_heading(qhead_text: str) -> str | None:
        t = " ".join((qhead_text or "").lower().split())
        for must_contain_list, category in rules:
            ok = True
            for frag in must_contain_list:
                if frag not in t:
                    ok = False
                    break
            if ok:
                return category
        return None

    def _clean_block(text: str) -> str:
        cleaned_lines = []
        seen = set()

        for line in (text or "").splitlines():
            line = line.strip()
            if not line:
                continue
            if re.fullmatch(r"(Yes|No|\[.*?\]|N/A)", line, re.I):
                continue
            if line.lower() == "see above":
                continue

            norm = " ".join(line.split()).lower()
            if norm in seen:
                continue
            seen.add(norm)
            cleaned_lines.append(line)

        return "\n".join(cleaned_lines).strip()

    # ------------------------------------------------------------------
    # Build categories by heading match
    # ------------------------------------------------------------------
    categories = defaultdict(list)

    source_meta = notes[0].get("source_meta", {}) or {}

    report_name = source_meta.get("report", report_type.title())
    file_name = source_meta.get("file", "Unknown file")

    for qnum, qhead, block in parsed_blocks:
        if qnum in ignore_numbers:
            continue

        category = _classify_by_heading(qhead)
        if not category:
            category = "Summary"

        cleaned = _clean_block(block)
        if not cleaned:
            continue

        source_meta = notes[0].get("source_meta", {})

        categories[category].append({
            "date": None,
            "text": cleaned,
            "source": {
                "report": report_name,
                "file": file_name,
            },
            "source_meta": {
                "source_label": source_meta.get("source_label"),
            },
        })


    # If nothing classified, fall back to Summary (better than empty)
    if not categories:
        categories["Summary"].append({
            "date": None,
            "text": full_text,
            "source": {
                "report": report_name,
                "file": file_name,
            },
        })

    return {
        "categories": {
            k: {"name": k, "items": v}
            for k, v in categories.items()
        }
    }


def load_letter_search_terms(path):
    """
    Load structural heading search terms for report classification.
    Format: TERM;CATEGORY;CATEGORY_NUMBER
    """
    terms = []
    seen = set()

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = [p.strip() for p in line.split(";")]
            if len(parts) != 3:
                continue

            term, category, number = parts
            key = term.lower()

            if key in seen:
                continue
            seen.add(key)

            terms.append({
                "term": key,
                "category": category,
                "number": int(number),
            })

    return terms
# =====================================================
# LOAD STRUCTURAL SEARCH TERMS (v2)
# =====================================================
LETTER_SEARCH_TERMS = load_letter_search_terms(
    resource_path("Letter_headings_search_v2.txt")
)
print(
    f"[CLASSIFIER] Loaded {len(LETTER_SEARCH_TERMS)} structural search terms"
)
# =====================================================
# LOAD CONTENT SEARCH TERMS (v1 — LINE BY LINE)
# =====================================================
LETTER_CONTENT_TERMS = load_letter_search_terms(
    resource_path("Letter headings search.txt")
)

print(
    f"[CLASSIFIER] Loaded {len(LETTER_CONTENT_TERMS)} content search terms (v1)"
)
# =========================================================
# ROUTED EXTRACTION ENTRY POINT
# =========================================================

def extract_notes(notes, detected_type=None, confidence=0):
    """
    Single authoritative router.
    DO NOT call extractors directly elsewhere.
    """

    if not notes:
        return {"categories": {}}

    # --- Tribunal path (LOCKED) ---
    if detected_type in ("medical", "nursing", "social") and confidence >= AUTO_DETECT_CONFIDENCE_MIN:
        print(f"[EXTRACTOR] Tribunal extractor ({detected_type})")
        return extract_by_ranges(notes, detected_type)

    # --- Reports / letters (content-first) ---
    print("[EXTRACTOR] Content-first report extractor")
    return extract_by_content_blocks(notes, LETTER_CONTENT_TERMS)


# =========================================================
# CONTENT-FIRST REPORT EXTRACTOR (NEW)
# =========================================================

def extract_by_content_blocks(notes, search_terms):
    """
    Primary extractor for letters / reports.
    CONTENT-FIRST, heading-assisted, block-based.
    """

    from collections import defaultdict
    import re
    DEBUG_CONTENT = False  # Set to True for debugging content block extraction

    # --------------------------------------------------
    # Provenance
    # --------------------------------------------------
    source_meta = notes[0].get("source_meta", {}) or {}
    report_label = source_meta.get("source_label", "Report")
    file_path = source_meta.get("file", "Unknown file")

    # --------------------------------------------------
    # Build full text
    # --------------------------------------------------
    full_text = "\n".join(
        (n.get("text") or "").strip()
        for n in notes
        if n.get("text")
    ).strip()

    if not full_text:
        return {"categories": {}}

    # --------------------------------------------------
    # Line split (INTENTIONAL — NOT PARAGRAPHS)
    # --------------------------------------------------
    raw_lines = [
        l.strip()
        for l in full_text.splitlines()
        if l.strip()
    ]

    if not raw_lines:
        return {"categories": {}}

    # --------------------------------------------------
    # Helpers
    # --------------------------------------------------
    # -----------------------------
    # EXTRACTOR CATEGORIES
    # -----------------------------
    FRONT_PAGE_CATEGORY = "FRONT PAGE"

    FRONT_PAGE_STOP_HEADINGS = (
        "reason for referral",
        "presenting complaint",
        "background",
        "history",
        "past medical history",
        "past psychiatric history",
        "forensic history",
    )

    # 🔒 Heading-locked categories (intent > content)

    HEADING_LOCKED_CATEGORIES = {
        # -----------------------------
        # HISTORY / REFERRAL
        # -----------------------------
        "reason for referral": "HISTORY OF PRESENTING COMPLAINT",
        "presenting complaint": "HISTORY OF PRESENTING COMPLAINT",
        "progress in custody": "HISTORY OF PRESENTING COMPLAINT",
        "progress at": "HISTORY OF PRESENTING COMPLAINT",

        # -----------------------------
        # PHYSICAL
        # -----------------------------
        "past medical history": "PHYSICAL HEALTH",
        "physical health": "PHYSICAL HEALTH",
        "medical history": "PHYSICAL HEALTH",

        # -----------------------------
        # PSYCHIATRIC
        # -----------------------------
        "past psychiatric history": "PAST PSYCH",
        "psychiatric history": "PAST PSYCH",
        "mental state": "MENTAL STATE",
        # -----------------------------
        # FORENSIC
        # -----------------------------
        "forensic history": "FORENSIC",
        "index offence": "FORENSIC",
        "offending history": "FORENSIC",

        # -----------------------------
        # MEDICATION
        # -----------------------------
        "medication": "PAST PSYCH",
        "regular": "PAST PSYCH",

        # -----------------------------
        # RISK / PLAN
        # -----------------------------
        "risk": "Plan",
        "potential risks": "Plan",
        "risks": "Plan",
        "plan": "Plan",
        "recommendations": "Plan",

        # -----------------------------
        # OPINION
        # -----------------------------
        "opinion": "SUMMARY",
        "opinion and recommendations": "SUMMARY",
    }




    def _looks_like_heading(line: str) -> bool:
        if len(line) > 100:
            return False

        tokens = line.split()
        if not tokens:
            return False

        first = tokens[0]

        # Numeric headings: "1.", "2)", "3"
        if re.match(r"^\d{1,2}[\.\)]?$", first):
            return True

        # Short non-narrative lines
        if (
            len(tokens) <= 10
            and not line.endswith(".")
            and not line.endswith("?")
            and not line.endswith("!")
        ):
            return True

        return False

    def _score_line(line_l: str):
        scores = defaultdict(int)
        hits = []

        for entry in search_terms:
            term = entry["term"]
            category = entry["category"]
            weight = entry["number"]

            if term not in line_l:
                continue

            # -----------------------------------------
            # 🔒 PHYSICAL HEALTH PRECISION GUARD
            # -----------------------------------------
            if category == "PHYSICAL HEALTH":
                if any(x in line_l for x in (
                    "delusion",
                    "delusional",
                    "hallucination",
                    "hallucinating",
                    "insight",
                    "thought",
                    "affect",
                    "mood",
                    "mental state",
                    "mse",
                    "behaviour",
                    "behavior",
                    "psychotic",
                    "paranoid",
                )):
                    continue

            scores[category] += weight
            hits.append((term, category, weight))

        if DEBUG_CONTENT and hits:
            print(
                "[CONTENT MATCH]",
                f"{line_l[:120]}",
                "→",
                hits,
                "→",
                dict(scores)
            )

        if not scores:
            return None, 0

        best_cat, best_score = max(
            scores.items(),
            key=lambda x: x[1]
        )

        return best_cat, best_score


    # --------------------------------------------------
    # Pass 1 — score every line
    # --------------------------------------------------
    scored_lines = []

    for i, line in enumerate(raw_lines):
        line_l = line.lower()
        category, score = _score_line(line_l)

        scored_lines.append({
            "index": i,
            "text": line,
            "category": category,
            "score": score,
            "is_heading": _looks_like_heading(line),
        })
        if DEBUG_CONTENT:
            print(
                "[LINE]",
                f"{i:04d}",
                "HEAD" if _looks_like_heading(line) else "TEXT",
                "| CAT:", category,
                "| SCORE:", score,
                "|",
                line[:120]
            )

    # --------------------------------------------------
    # Pass 2 — detect section anchors (HEADINGS ONLY)
    # Headings define boundaries, NOT categories
    # --------------------------------------------------
    anchors = [
        item for item in scored_lines
        if item["is_heading"]
    ]

    # If still no anchors, treat whole document as one block
    if not anchors:
        anchors = [scored_lines[0]]

    # --------------------------------------------------
    # Ensure a pre-heading anchor exists
    # --------------------------------------------------
    if anchors and anchors[0]["index"] > 0:
        anchors = [{
            "index": -1,
            "text": None,
            "is_heading": True,
        }] + anchors

    def _locked_category_from_heading(text):
        if not text:
            return None

        t = text.lower().strip().rstrip(":")

        for key, cat in HEADING_LOCKED_CATEGORIES.items():
            if key in t:
                return cat

        return None


    def _authoritative_heading_category(ln):
        """
        Returns a category ONLY if this heading is
        a strong semantic reset (e.g. 'Past medical history').
        """
        if not ln["is_heading"]:
            return None

        if ln["category"] and ln["score"] >= 6:
            return ln["category"]

        return None
    # --------------------------------------------------
    # Pass 3 — build blocks between anchors
    # --------------------------------------------------
    blocks = []

    # --------------------------------------------------
    # Initialise FRONT PAGE block (structure-first)
    # --------------------------------------------------
    current_block = {
        "lines": [],
        "scores": defaultdict(int),
        "locked": FRONT_PAGE_CATEGORY,
        "_seen": set(),
    }

    total_lines = len(scored_lines)
    summary_terminal_index = int(total_lines * 0.9)

    for ln in scored_lines:

        line_text = (ln.get("text") or "").strip()
        line_l = line_text.lower()

        if not line_text:
            continue
        category = (ln.get("category") or "").strip().upper().replace(" ", "_")

        # --------------------------------------------------
        # STEP 1 — CONDITIONAL ABSOLUTE LOCK GUARD
        # SUMMARY only terminal in final 10%
        # --------------------------------------------------
        if (
            current_block.get("locked") == "SUMMARY"
            and ln["index"] >= summary_terminal_index
        ):
            current_block["lines"].append(line_text)
            continue

        # --------------------------------------------------
        # STEP 1B — MEDICATION CONTINUITY (PAST PSYCH)
        # --------------------------------------------------
        if (
            current_block.get("locked") == "PAST PSYCH"
            and line_l in {"medication", "regular"}
        ):
            current_block["lines"].append(line_text)
            continue

        # --------------------------------------------------
        # STEP 2 — EMBEDDED LOCKED HEADING
        # (never allowed to ENTER PAST PSYCH)
        # --------------------------------------------------
        embedded_locked = None

        if ln.get("is_heading") and ln.get("category") is None:
            for key, cat in HEADING_LOCKED_CATEGORIES.items():
                if key in line_l:
                    embedded_locked = cat
                    break

            if embedded_locked == "PAST PSYCH":
                embedded_locked = None

            if embedded_locked and current_block.get("locked") != embedded_locked:
                if current_block["lines"]:
                    blocks.append(current_block)

                current_block = {
                    "lines": [],
                    "scores": defaultdict(int),
                    "locked": embedded_locked,
                    "_seen": set(),
                }

                if DEBUG_CONTENT:
                    print("[EMBEDDED LOCK]", line_text, "→", embedded_locked)

                continue


        # --------------------------------------------------
        # STEP 3 — STRUCTURAL HEADING = HARD BLOCK (MINIMAL)
        # --------------------------------------------------
        if ln.get("is_heading"):

                # --------------------------------------------------
                # 🔑 FORCE ENTRY — SOCIAL HISTORY
                # --------------------------------------------------
                if category == "SOCIAL_HISTORY":
                        if current_block["lines"]:
                                blocks.append(current_block)

                        current_block = {
                                "lines": [],
                                "scores": defaultdict(int),
                                "locked": "SOCIAL_HISTORY",
                                "_seen": set(),
                        }

                        if DEBUG_CONTENT:
                                print("[LOCKED HEADING]", line_text, "→ SOCIAL_HISTORY")

                        continue

                # --------------------------------------------------
                # 🧠 FORCE ENTRY — PAST PSYCH
                # --------------------------------------------------
                if category == "PAST_PSYCH":
                        if current_block["lines"]:
                                blocks.append(current_block)

                        current_block = {
                                "lines": [],
                                "scores": defaultdict(int),
                                "locked": "PAST_PSYCH",
                                "_seen": set(),
                        }

                        if DEBUG_CONTENT:
                                print("[LOCKED HEADING]", line_text, "→ PAST_PSYCH")

                        continue

                # --------------------------------------------------
                # 🧠 PAST PSYCH DOMINANCE (SINGLE RULE)
                # --------------------------------------------------
                if current_block.get("locked") == "PAST_PSYCH":

                        # Only authorised exits may break PAST PSYCH
                        if category in PAST_PSYCH_EXIT_CATEGORIES:
                                blocks.append(current_block)

                                current_block = {
                                        "lines": [],
                                        "scores": defaultdict(int),
                                        "locked": category,
                                        "_seen": set(),
                                }

                                if DEBUG_CONTENT:
                                        print("[PAST PSYCH EXIT]", line_text, "→", category)

                                continue

                        # Everything else stays inside
                        current_block["lines"].append(line_text)

                        if DEBUG_CONTENT:
                                print("[PAST PSYCH CONTINUE]", line_text)

                        continue

                # --------------------------------------------------
                # HARD OVERRIDES (never override PAST PSYCH)
                # --------------------------------------------------
                forced_locked = None
                for key, cat in HARD_OVERRIDE_HEADINGS.items():
                        if key in line_l:
                                forced_locked = cat
                                break

                if forced_locked:
                        if current_block["lines"]:
                                blocks.append(current_block)

                        current_block = {
                                "lines": [],
                                "scores": defaultdict(int),
                                "locked": forced_locked,
                                "_seen": set(),
                        }

                        if DEBUG_CONTENT:
                                print("[HARD OVERRIDE]", line_text, "→", forced_locked)

                        continue

                # --------------------------------------------------
                # FRONT PAGE GUARD
                # --------------------------------------------------
                if current_block.get("locked") == FRONT_PAGE_CATEGORY:

                    # Allow admin / demographic headings to remain in FRONT PAGE
                    if any(k in line_l for k in FRONT_PAGE_ALLOWED_HEADINGS):
                        current_block["lines"].append(line_text)
                        continue

                    # Stop only on real clinical headings
                    if any(stop in line_l for stop in FRONT_PAGE_STOP_HEADINGS):
                        pass  # fall through → real section starts
                    else:
                        if line_text not in current_block["_seen"]:
                            current_block["lines"].append(line_text)
                            current_block["_seen"].add(line_text)
                        continue


                # --------------------------------------------------
                # NORMAL STRUCTURAL SPLIT
                # --------------------------------------------------
                heading_locked = None
                for key, cat in HEADING_LOCKED_CATEGORIES.items():
                        if key in line_l:
                                heading_locked = cat
                                break

                if current_block["lines"]:
                        blocks.append(current_block)

                current_block = {
                        "lines": [],
                        "scores": defaultdict(int),
                        "locked": heading_locked,
                        "_seen": set(),
                }

                if DEBUG_CONTENT and heading_locked:
                        print("[LOCKED HEADING]", line_text, "→", heading_locked)

                continue

        # --------------------------------------------------
        # STEP 4 — DEFAULT LINE APPEND (DEDUPED)
        # --------------------------------------------------
        if line_text not in current_block["_seen"]:
            current_block["lines"].append(line_text)
            current_block["_seen"].add(line_text)

    # --------------------------------------------------
    # FINAL FLUSH
    # --------------------------------------------------
    if current_block["lines"]:
        blocks.append(current_block)

    # --------------------------------------------------
    # Pass 4 — resolve block categories (STRUCTURE WINS)
    # --------------------------------------------------
    resolved_blocks = []
    uncategorised = []

    for block in blocks:
        if not block.get("lines"):
            continue

        final_cat = None

        # 🔒 Locked heading ALWAYS wins (including FRONT PAGE)
        if block.get("locked"):
            final_cat = block["locked"]

        # 📊 Otherwise use accumulated scores
        elif block.get("scores"):
            final_cat = max(
                block["scores"].items(),
                key=lambda x: x[1]
            )[0]

        # 🚫 Nothing resolved — collect as uncategorised
        if not final_cat:
            uncategorised.append("\n".join(block["lines"]).strip())
            continue

        resolved_blocks.append({
            "category": final_cat,
            "text": "\n".join(block["lines"]).strip(),
        })

        if DEBUG_CONTENT:
            print(
                "[BLOCK RESOLVE]",
                final_cat,
                "| locked:",
                block.get("locked"),
                "| scores:",
                dict(block.get("scores", {}))
            )

    # --------------------------------------------------
    # Build panel format (FINAL, GUARANTEED NON-EMPTY)
    # --------------------------------------------------
    panel_data = {"categories": {}}

    for block in resolved_blocks:
        cat = block.get("category")
        text = block.get("text")

        if not cat:
            continue

        if not text and cat != FRONT_PAGE_CATEGORY:
            continue


        panel_data["categories"].setdefault(cat, {
            "name": cat,
            "items": [],
        })

        panel_data["categories"][cat]["items"].append({
            "date": None,
            "text": text,
            "source": {
                "report": report_label,
                "file": file_path,
            },
        })

    if DEBUG_CONTENT:
        print(
            "[CONTENT BLOCKS] Final categories:",
            list(panel_data["categories"].keys())
        )

    # --- Uncategorised bucket & coverage metadata ---
    total_blocks = len(blocks)
    if uncategorised:
        panel_data["categories"]["Uncategorised"] = {
            "name": "Uncategorised",
            "items": [{"date": None, "text": t} for t in uncategorised if t],
        }
    panel_data["_coverage"] = {
        "total_paragraphs": total_blocks,
        "categorised": len(resolved_blocks),
        "uncategorised": len(uncategorised),
    }
    print(
        f"[CONTENT BLOCKS] Coverage: {len(resolved_blocks)}/{total_blocks} blocks categorised, "
        f"{len(uncategorised)} uncategorised"
    )

    return panel_data


def extract_by_scored_classifier(notes, search_terms):
    """
    Fallback extractor for NON-UK-Govt reports.
    Uses scored keyword matching to assign paragraphs
    to letter categories.
    """
    DEBUG_CLASSIFIER = False  # Set to True for debugging classifier output

    from collections import defaultdict
    import re

    HEADING_CATEGORY_MAP = {
        "personal history": "Background History",
        "background history": "Background History",
        "social history": "Social History",
        "psychiatric history": "Psychiatric History",
        "mental health history": "Psychiatric History",
        "forensic history": "Forensic History",
        "physical health history": "Physical Health",
        "medical history": "Physical Health",
        "drug history": "Drug and Alcohol History",
        "alcohol history": "Drug and Alcohol History",
        "summary": "Summary",
        "plan": "Plan",
        "risk": "Risk",
    }

    def _category_from_heading(text: str) -> str | None:
        t = " ".join(text.lower().strip().rstrip(":").split())

        # AUTHORITATIVE HPC (explicit only)
        if (
            t.startswith("progress at ")
            or t.startswith("progress in ")
            or t.startswith("progress on ")
            or t == "progress in custody"
            or t == "current progress"
        ):
            return "History of Presenting Complaint"

        for key, category in HEADING_CATEGORY_MAP.items():
            if key in t:
                return category

        return None


    def _is_clinical_heading(paragraph: str) -> bool:
        """
        Returns True only for headings that represent
        real clinical sections (not document titles).
        """
        p = paragraph.strip().lower()

        if not _is_heading(paragraph):
            return False

        # ❌ Exclude document-level titles
        title_blacklist = (
            "assessment report",
            "referral assessment report",
            "psychiatric report",
            "medical report",
            "social work report",
            "risk assessment",
            "care plan",
        )

        for t in title_blacklist:
            if t in p:
                return False

        # Must map to a known category OR HPC
        return True

    def _looks_like_metadata_block(p: str) -> bool:
        p = p.strip().lower()
        if not p:
            return True

        metadata_markers = (
            "nhs number",
            "date of birth",
            "first language",
            "current location",
            "icd-10",
            "diagnoses",
            "referral assessment report",
        )

        if ":" in p and len(p.split()) < 40:
            return True

        return any(m in p for m in metadata_markers)

    def _is_heading(paragraph: str) -> bool:
        p = paragraph.strip()
        if not p:
            return False

        if re.match(r"^\d{1,2}\.\s+[A-Za-z]", p):
            return True

        if p.endswith(":"):
            core = p[:-1].strip()
            if core.endswith("."):
                return False
            return len(core.split()) <= 12

        if (
            len(p.split()) <= 10
            and not p.endswith(".")
            and not p.endswith("?")
            and not p.endswith("!")
            and p[0].isupper()
        ):
            if any(p.lower().startswith(w) for w in ("he ", "she ", "they ", "i ")):
                return False
            return True

        return False

    def _is_narrative_paragraph(p: str) -> bool:
        p = p.strip().lower()
        if not p or len(p.split()) <= 6:
            return False

        narrative_markers = (
            "he said",
            "she said",
            "he was assessed",
            "was assessed",
            "thank you for referring",
            "presented with",
            "reported that",
            "was referred",
        )

        return any(m in p for m in narrative_markers)

    HEADING_WEIGHT = 3
    BODY_WEIGHT = 1
    MIN_SCORE_TO_ASSIGN = 2

    CATEGORY_MIN_SCORES = {
        "Forensic History": 3,
        "Mental State Examination": 6,
        "Physical Health": 2,
        "Psychiatric History": 2,
        "Drug and Alcohol History": 2,
        "Background History": 1,
        "Social History": 1,
        "Function": 1,
        "Plan": 1,
        "Summary": 0,
    }

    # --------------------------------------------------
    # Provenance
    # --------------------------------------------------
    source_meta = notes[0].get("source_meta", {}) or {}
    report_label = source_meta.get("source_label", "Report")
    file_path = source_meta.get("file", "Unknown file")

    # --------------------------------------------------
    # Build full text
    # --------------------------------------------------
    full_text = "\n\n".join(
        (n.get("text") or "").strip()
        for n in notes
        if n.get("text")
    ).strip()

    if not full_text:
        return {"categories": {}}

    # --------------------------------------------------
    # Normalisation (DOCX / PDF safe)
    # --------------------------------------------------
    normalised_text = re.sub(
        r"(?im)(progress\s+(?:at|in|on)\s+[^:\n]{3,120}:)",
        r"\n\n\1\n\n",
        full_text
    )

    normalised_text = re.sub(
        r"(?m)^\s*([A-Za-z][A-Za-z /&\-\(\)]{2,60}:)\s*$",
        r"\n\n\1\n\n",
        normalised_text
    )

    normalised_text = re.sub(
        r"(?m)^\s*([A-Za-z][A-Za-z /&\-\(\)]{2,60}:)\s*(.+)",
        r"\n\n\1\n\n\2",
        normalised_text
    )

    normalised_text = re.sub(
        r"(Current location:\s*[^\n]+)",
        r"\1\n\n",
        normalised_text,
        flags=re.I
    )

    normalised_text = re.sub(
        r"(ICD-10 Diagnoses:\s*(?:[^\n]+\n?){1,6})",
        r"\1\n\n",
        normalised_text,
        flags=re.I
    )

    normalised_text = re.sub(
        r"(?i)(\n|\s)(thank you for referring\s+)",
        r"\n\n\2",
        normalised_text,
    )

    raw_paragraphs = [
        p.strip()
        for p in re.split(r"\n\s*\n", normalised_text)
        if p.strip()
    ]

    classified = []
    uncategorised = []

    current_section = None
    front_page_active = True
    entered_narrative = False
    section_set_by_heading = False



    for para in raw_paragraphs:
        scores = defaultdict(int)
        matched_terms = defaultdict(list)

        para_l = para.lower().rstrip(":")

        # ---------------- FRONT PAGE ----------------
        if not entered_narrative:
            if _is_narrative_paragraph(para) or _is_clinical_heading(para):
                entered_narrative = True
                front_page_active = False
            else:
                classified.append(("Front Page", para))
                continue
        # --------------------------------------------------
        # CLINICAL HEADING — ALWAYS AUTHORITATIVE
        # --------------------------------------------------
        if _is_clinical_heading(para):
            heading_category = _category_from_heading(para)

            if heading_category:
                current_section = heading_category
                entered_narrative = True
                front_page_active = False
                best_category = heading_category

                if DEBUG_CLASSIFIER:
                    print(f"[SECTION] Switched to {heading_category}")

                classified.append((best_category, para))
                continue


        # --------------------------------------------------
        # FRONT PAGE METADATA
        # --------------------------------------------------
        if front_page_active and _looks_like_metadata_block(para):
            classified.append(("Front Page", para))
            continue


        # --------------------------------------------------
        # BODY PARAGRAPH
        # --------------------------------------------------
        best_category = None
        best_score = 0

        if not front_page_active:
            for entry in search_terms:
                term = entry["term"]
                category = entry["category"]

                if term in para_l:
                    scores[category] += BODY_WEIGHT
                    matched_terms[category].append(term)

            if scores:
                candidate_cat, candidate_score = max(
                    scores.items(),
                    key=lambda x: x[1]
                )

                if candidate_score >= CATEGORY_MIN_SCORES.get(
                    candidate_cat,
                    MIN_SCORE_TO_ASSIGN
                ):
                    best_category = candidate_cat
                    best_score = candidate_score


        # --------------------------------------------------
        # FINAL RESOLUTION
        # --------------------------------------------------
        if best_category is None:
            # Collect uncategorised paragraphs for coverage reporting
            uncategorised.append(para)
            continue


        if best_category is not None:
            if DEBUG_CLASSIFIER:
                print(
                    f"[CLASSIFIER] {best_category} | "
                    f"{para[:120].replace(chr(10),' ')}"
                )

            classified.append((best_category, para))


    # --------------------------------------------------
    # Stitch paragraphs
    # --------------------------------------------------
    stitched = defaultdict(list)
    current_cat = None
    buffer = []

    for cat, para in classified:
        if cat != current_cat:
            if buffer and current_cat:
                stitched[current_cat].append("\n\n".join(buffer))
            buffer = [para]
            current_cat = cat
        else:
            buffer.append(para)

    if buffer and current_cat:
        stitched[current_cat].append("\n\n".join(buffer))

    # --------------------------------------------------
    # Build panel format
    # --------------------------------------------------
    panel_data = {"categories": {}}

    for category, blocks in stitched.items():
        panel_data["categories"][category] = {
            "name": category,
            "items": [
                {
                    "date": None,
                    "text": block.strip(),
                    "source": {
                        "report": report_label,
                        "file": file_path,
                    },
                }
                for block in blocks
            ],
        }

    # --- Uncategorised bucket & coverage metadata ---
    categorised_count = len(classified)
    total_count = len(raw_paragraphs)
    if uncategorised:
        panel_data["categories"]["Uncategorised"] = {
            "name": "Uncategorised",
            "items": [{"date": None, "text": t} for t in uncategorised],
        }
    panel_data["_coverage"] = {
        "total_paragraphs": total_count,
        "categorised": categorised_count,
        "uncategorised": len(uncategorised),
    }
    print(
        f"[CLASSIFIER] Coverage: {categorised_count}/{total_count} paragraphs categorised, "
        f"{len(uncategorised)} uncategorised"
    )

    return panel_data


class DateSectionWidget(QWidget):
    def __init__(self, date_label: str, text_lines: list[str], parent=None):
        super().__init__(parent)

        # 🔒 FORCE NON-NATIVE (macOS FIX)
        self.setAttribute(Qt.WA_NativeWindow, False)
        self.setAttribute(Qt.WA_DontCreateNativeAncestors, True)
        self.setWindowFlags(Qt.Widget)

        self.date_label = date_label
        self._collapsed = False

        outer = QVBoxLayout(self)
        outer.setContentsMargins(8, 6, 8, 6)
        outer.setSpacing(6)

        # ---------------- HEADER ----------------
        self.header_btn = QPushButton(date_label)
        self.header_btn.setCheckable(True)
        self.header_btn.setChecked(False)
        self.header_btn.setChecked(True)
        self.header_btn.setStyleSheet("""
            QPushButton {
                border: none;
                background: transparent;
                text-align: left;
                font-size: 16px;
                font-weight: 700;
                padding: 4px;
            }
            QPushButton:hover {
                background: rgba(0,0,0,0.05);
                border-radius: 6px;
            }
        """)
        self.header_btn.clicked.connect(self._toggle)

        outer.addWidget(self.header_btn)

        # ---------------- BODY ----------------
        self.body = QWidget()
        body_layout = QVBoxLayout(self.body)
        body_layout.setContentsMargins(12, 2, 0, 2)
        body_layout.setSpacing(4)

        for line in text_lines:
            lbl = QLabel(line, self)
            lbl.setAttribute(Qt.WA_NativeWindow, False)
            lbl.setAttribute(Qt.WA_DontCreateNativeAncestors, True)
            lbl.setWindowFlags(Qt.Widget)
            lbl.setWordWrap(True)
            lbl.setStyleSheet("""
                QLabel {
                    font-size: 12px;
                    font-weight: 400;
                }
            """)
            body_layout.addWidget(lbl)

        outer.addWidget(self.body)

    def _toggle(self):
        self._collapsed = not self._collapsed
        self.body.setVisible(not self._collapsed)
        arrow = "▸" if self._collapsed else "▾"
        self.header_btn.setText(f"{arrow} {self.date_label}")

# =========================================================
# DATA EXTRACTOR POPUP (RESTORED UI + CATEGORY FILTER)
# =========================================================
class DataExtractorPopup(QWidget):
    data_extracted = Signal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.Tool | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_DeleteOnClose)
        self.notes = []
        self._latest_panel_data = None
        self._panel_data_by_dtype = {}
        self._drag_offset = None
        self._new_item_keys = set()

        self._collapsed_blocks = set()
        
        self.setWindowTitle("Data Extractor")
        self.setWindowFlags(Qt.FramelessWindowHint)
        self.resize(720, 520)
        self.setStyleSheet("background: white;")
        

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        container = QWidget()
        container.setAttribute(Qt.WA_StyledBackground, True)
        container.setAttribute(Qt.WA_NoSystemBackground, False)
        container.setAutoFillBackground(True)

        container.mousePressEvent = self._drag_mouse_press
        container.mouseMoveEvent = self._drag_mouse_move
        container.mouseReleaseEvent = self._drag_mouse_release

        container.setObjectName("extractor_container")
        container.installEventFilter(self)
        container.setMouseTracking(True)

        outer.addWidget(container)


        container.setStyleSheet("""
            QWidget#extractor_container {
                background: white;
                border-radius: 14px;
                border: 1px solid rgba(0,0,0,0.25);
            }

            QLabel {
                color: #003c32;
                font-size: 13px;
                font-weight: 600;
            }

            QComboBox {
                padding: 6px 8px;
                border-radius: 6px;
                border: 1px solid rgba(0,0,0,0.25);
                background: white;
            }

            QPushButton {
                padding: 10px 14px;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 600;
            }

            QPushButton#primaryAction {
                background-color: #2563eb;
                color: white;
            }

            QPushButton#primaryAction:hover {
                background-color: #1d4ed8;
            }

            QPushButton#secondaryAction {
                background-color: #059669;
                color: white;
            }

            QPushButton#secondaryAction:hover {
                background-color: #047857;
            }
            
            QPushButton#clearAction {
                background-color: #dc2626;      /* red-600 */
                color: white;
                font-size: 13px;
                font-weight: 600;
                border-radius: 8px;
                padding: 10px 14px;
            }

            QPushButton#clearAction:hover {
                background-color: #b91c1c;      /* red-700 */
            }

            QPushButton#clearAction:pressed {
                background-color: #991b1b;      /* red-800 */
            }

            QPushButton#closeButton {
                background: transparent;
                color: #003c32;
                font-size: 18px;
                font-weight: 700;
                border: none;
                padding: 0px;
            }

            QPushButton#closeButton:hover {
                background: rgba(0,0,0,0.08);
                border-radius: 14px;
            }
        """)


        layout = QVBoxLayout(container)
        layout.setContentsMargins(16, 16, 16, 16)

        # ---------------- HEADER ----------------
        hrow = QHBoxLayout()
        title = QLabel("Data Extractor")
        title.setStyleSheet("font-size:18px; font-weight:700;")
        hrow.addWidget(title)
        hrow.addStretch()

        close_btn = QPushButton("×")
        close_btn.setObjectName("closeButton")
        close_btn.setFixedSize(28, 28)
        close_btn.clicked.connect(self.on_close_requested)
        hrow.addWidget(close_btn)
        layout.addLayout(hrow)

        # ---------------- DOCUMENT TYPE (Auto-detected label) ----------------
        doc_row = QHBoxLayout()
        doc_label = QLabel("Document detected:")
        doc_label.setStyleSheet("font-size: 12px; font-weight: 500; color: #374151;")
        self.document_type_label = QLabel("—")
        self.document_type_label.setStyleSheet("""
            font-size: 12px;
            font-weight: 600;
            color: #059669;
            background: #ecfdf5;
            padding: 4px 12px;
            border-radius: 4px;
        """)
        doc_row.addWidget(doc_label)
        doc_row.addWidget(self.document_type_label, 1)
        layout.addLayout(doc_row)

        # ---------------- AUTO-DETECT STATUS ----------------
        self.auto_detect_label = QLabel("")
        self.auto_detect_label.setWordWrap(True)
        self.auto_detect_label.setStyleSheet(
            "font-size: 11px; font-weight: 500; color: #065f46;"
        )
        layout.addWidget(self.auto_detect_label)


        # ---------------- STATUS LABEL (replaces old upload button) ----------------
        self.extract_btn = QLabel("")  # Used for status updates during extraction
        self.extract_btn.setStyleSheet("font-size: 12px; color: #6b7280; padding: 4px;")
        layout.addWidget(self.extract_btn)

        layout.addSpacing(12)

        # ---------------- CATEGORY FILTER ----------------
        cat_row = QHBoxLayout()
        cat_label = QLabel("History category:")
        self.category_dropdown = QComboBox()
        self.category_dropdown.clear()
        self.category_dropdown.addItem("All Categories")

        for key in LETTER_CATEGORY_ORDER:
            label = CANONICAL_TO_LETTER_LABEL.get(key)
            if label:
                self.category_dropdown.addItem(label)
                
        self.category_dropdown.currentIndexChanged.connect(
            self._refresh_preview_from_cache
        )
        cat_row.addWidget(cat_label)
        cat_row.addWidget(self.category_dropdown, 1)
        layout.addLayout(cat_row)

        # ---------------- PREVIEW (STEP 1 — QWidget based) ----------------
        self.preview_scroll = QScrollArea()
        self.preview_scroll.setWidgetResizable(True)
        self.preview_scroll.setFrameShape(QScrollArea.NoFrame)
        self.preview_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.preview_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.preview_scroll.setAttribute(Qt.WA_StyledBackground, True)
        self.preview_scroll.setAutoFillBackground(True)

        self.preview_container = QWidget()
        self.preview_container.setAttribute(Qt.WA_DontCreateNativeAncestors, True)
        self.preview_container.setAttribute(Qt.WA_StyledBackground, True)
        self.preview_container.setAutoFillBackground(True)

        self.preview_layout = QVBoxLayout(self.preview_container)
        self.preview_layout.setContentsMargins(0, 0, 0, 0)
        self.preview_layout.setSpacing(8)
        self.preview_layout.setAlignment(Qt.AlignTop)
        self.preview_scroll.setWidget(self.preview_container)

        layout.addWidget(self.preview_scroll, 1)

        # Cache for DateSectionWidget reuse
        self._date_widgets = {}



        # ---------------- SEND ----------------
        # ---------------- ACTIONS ----------------
        action_row = QHBoxLayout()

        self.clear_button = QPushButton("Clear extraction")
        self.clear_button.setObjectName("clearAction")
        self.clear_button.clicked.connect(self.clear_extraction)
        action_row.addWidget(self.clear_button)

        self.send_button = QPushButton("Send to letter")
        self.send_button.setObjectName("secondaryAction")
        self.send_button.clicked.connect(self.send_to_letter)
        action_row.addWidget(self.send_button)

        self._date_widgets = {}  # (category, report, file, date_label) -> DateSectionWidget

        self._collapsed_dates = set()      # e.g. "09 Aug 2023"

        layout.addLayout(action_row)
        self._scroll_anchor_text = None
        self._scroll_anchor_y = None
        QTimer.singleShot(40, self._raise_popup)

    def _on_document_type_changed(self, ui_text):
        # --------------------------------------------------
        # USER OVERRIDE — DISABLE AUTO-DETECT
        # --------------------------------------------------
        self._auto_report_type = None
        self._auto_report_confidence = None

        # Clear auto-detect UI hint
        self.auto_detect_label.setText("")

        dtype = DOC_TYPE_MAP.get(ui_text)

        # ---------------------------------------------
        # RESTORE PANEL FROM MEMORY (PER DOC TYPE)
        # ---------------------------------------------
        if dtype in self._panel_data_by_dtype:
            self._latest_panel_data = self._panel_data_by_dtype[dtype]
            print(f"[MEMORY] 🔁 Restored panel for {dtype}")
        else:
            self._latest_panel_data = None
            print(f"[MEMORY] ⚠️ No stored panel for {dtype}")

        # ---------------------------------------------
        # RESET UI STATE (VIEW-ONLY)
        # ---------------------------------------------
        self._collapsed_blocks = set()
        self._new_item_keys = set()
        self._last_rendered_block_key = None

        self._refresh_preview_from_cache()

    def on_close_requested(self):
        """
        User requested to close the extractor UI.
        Persist extracted data in parent (memory only),
        then hide the popup.
        """
        if self._latest_panel_data:
            parent = self.parent()
            if parent and hasattr(parent, "last_extracted_panel_data"):
                parent.last_extracted_panel_data = self._latest_panel_data

        self.hide()
    def closeEvent(self, event):
        """
        Prevent destruction. Treat close as hide.
        """
        event.ignore()
        self.hide()
        
    def _clear_layout(self, layout):
        while layout.count():
            item = layout.takeAt(0)
            w = item.widget()
            if w:
                w.setParent(None)

    def _raise_popup(self):
        # No longer auto-show — data extraction runs in background
        pass
        
    def clear_extraction(self):
        """
        Public reset entry point (menu / button / action).
        """
        self._clear_extraction_state()

    def _clear_extraction_state(self):
        """
        FULL reset of extractor state.
        Called ONLY when user explicitly clears (new patient).
        """

        # ------------------------------
        # Core data
        # ------------------------------
        self.notes = []
        self._latest_panel_data = None
        self._panel_data_by_dtype = {}
        self._new_item_keys.clear()

        # ------------------------------
        # UI state
        # ------------------------------
        self._collapsed_blocks.clear()
        self._collapsed_dates.clear()

        # ------------------------------
        # Cached widgets
        # ------------------------------
        for w in self._date_widgets.values():
            w.setParent(None)
        self._date_widgets.clear()

        # ------------------------------
        # Preview UI
        # ------------------------------
        while self.preview_layout.count():
            item = self.preview_layout.takeAt(0)
            widget = item.widget()
            if widget:
                widget.setParent(None)

        # ------------------------------
        # Controls
        # ------------------------------
        self.category_dropdown.setCurrentText("All Categories")


        
    def _normalise_note_categories(self, panel_data):
        """
        Convert CATEGORY_TERMS numeric IDs → category names.
        This is REQUIRED before preview / dropdown / letter writer.
        """
        from history_extractor_sections import CATEGORY_TERMS

        id_to_name = {
            meta["id"]: name
            for name, meta in CATEGORY_TERMS.items()
        }

        print(f"[NORMALISE DEBUG] id_to_name mapping: {id_to_name}")
        print(f"[NORMALISE DEBUG] Input categories: {list(panel_data.get('categories', {}).keys())}")

        new_categories = {}

        for key, cat in panel_data.get("categories", {}).items():
            if not isinstance(cat, dict):
                print(f"[NORMALISE DEBUG] Skipping key {key}: not a dict")
                continue

            if isinstance(key, int):
                name = id_to_name.get(key)
                print(f"[NORMALISE DEBUG] int key {key} -> name '{name}'")
            else:
                name = key
                print(f"[NORMALISE DEBUG] str key '{key}' -> name '{name}'")

            if not name:
                print(f"[NORMALISE DEBUG] Skipping key {key}: no name found")
                continue

            item_count = len(cat.get("items", []))
            new_categories.setdefault(name, {
                "name": name,
                "items": [],
            })

            new_categories[name]["items"].extend(
                cat.get("items", [])
            )
            print(f"[NORMALISE DEBUG] Added {item_count} items to '{name}'")

        print(f"[NORMALISE DEBUG] Output categories: {list(new_categories.keys())}")
        panel_data["categories"] = new_categories

    def _normalise_note_source(self, note):
        src = note.get("source")

        if not isinstance(src, dict):
            note["source"] = {}

        note["source"].setdefault("system", "Unknown")
        note["source"].setdefault("report", "Unknown")
        note["source"].setdefault("file", "Unknown")


    def _normalise_category(self, cat):
        if not cat:
            return None

        # 1. Exact RC / UI label match
        if cat in RC_UI_TO_CANONICAL:
            return RC_UI_TO_CANONICAL[cat]

        # 2. Already-canonical (fast path)
        if cat in CANONICAL_CATEGORIES:
            return cat

        # 3. Fallback normalisation
        canon = (
            cat.strip()
               .upper()
               .replace(" ", "_")
               .replace("&", "AND")
        )

        return canon if canon in CANONICAL_CATEGORIES else None


    # =====================================================
    # ONE NOTES LOADER FOR MULTIPLE FILES
    # =====================================================
    def _load_documents(self, files, dtype):
        """
        Load one or many documents and return a flat list of notes
        with consistent provenance.
        """
        loaded_notes = []

        for path in files:
            ext = os.path.splitext(path)[1].lower()

            # ---------------- NOTES (AUTO-DETECT) ----------------
            if dtype == "notes" and ext in (".xls", ".xlsx"):
                from importer_autodetect import import_files_autodetect
                docs = import_files_autodetect([path])
                report_label = "Clinical Notes"

            # ---------------- REPORTS / LETTERS ----------------
            else:
                docs = ingest_documents([path], debug=True)

                if dtype == "reports":
                    report_label = "Report"
                elif dtype == "letters":
                    report_label = "Letter"
                else:
                    report_label = "Free Text"

            # ---------------- PROVENANCE (UI LABEL) ----------------
            filename = os.path.basename(path)

            if dtype == "reports":
                source_label = f"Medical report – {filename}"
            elif dtype == "letters":
                source_label = f"Letter – {filename}"
            elif dtype == "notes":
                source_label = f"Clinical notes – {filename}"
            else:
                source_label = filename

            for n in docs:
                n.setdefault("source_meta", {})
                n["source_meta"]["report"] = report_label
                n["source_meta"]["file"] = path

                # 👇 NEW: single human-readable label for UI + letter
                n["source_meta"]["source_label"] = source_label

            loaded_notes.extend(docs)

        # --------------------------------------------------
        # 🔒 LOCK PIPELINE — NOTES ONLY (CRITICAL RULE)
        # --------------------------------------------------
        if dtype == "notes":
            systems = {
                n.get("source")
                for n in loaded_notes
                if isinstance(n.get("source"), str)
            }

            if systems == {"rio"}:
                self.pipeline = "rio"
            elif systems == {"carenotes"}:
                self.pipeline = "carenotes"
            elif systems == {"epjs"}:
                self.pipeline = "epjs"
            else:
                raise RuntimeError(
                    f"[PIPELINE] ❌ Mixed or unknown systems detected: {systems}"
                )

            print(f"[PIPELINE] 🔒 Locked → {self.pipeline.upper()}")

        # --------------------------------------------------
        # REPORTS / LETTERS MUST NEVER TOUCH PIPELINE
        # --------------------------------------------------
        return loaded_notes

    # =====================================================
    # NOTES INJECTION
    # =====================================================
    def set_notes(self, notes):
        """
        Inject notes EXACTLY as produced by the notes importer.
        Do NOT normalise, wrap, or alter fields.
        """
        self.notes = list(notes or [])

    # =====================================================
    # NOTES PROVENANCE
    # =====================================================
    def _apply_notes_provenance(self, panel_data, report_label):
        """
        Inject report provenance into ALL items in panel_data
        WITHOUT overwriting per-item file provenance.
        """
        for cat in panel_data.get("categories", {}).values():
            for item in cat.get("items", []):
                item.setdefault("source", {})
                item["source"]["report"] = report_label



    # =====================================================
    # LOAD + EXTRACT
    # =====================================================
    def load_file(self, file_path: str):
        """
        Load a file directly (without file dialog) and auto-detect type.
        Called by external pages like GeneralPsychReportPage.
        """
        if not file_path:
            return

        print(f"[EXTRACTOR] load_file called with: {file_path}")

        # Auto-detect file type
        ext = os.path.splitext(file_path)[1].lower()

        if ext in (".xls", ".xlsx"):
            dtype = "notes"
            print(f"[EXTRACTOR] Auto-detected: Excel -> Notes mode")
        elif ext in (".pdf", ".docx", ".doc"):
            dtype = "reports"
            print(f"[EXTRACTOR] Auto-detected: PDF/Word -> Reports mode")
        else:
            dtype = "letters"
            print(f"[EXTRACTOR] Auto-detected: Other -> Letters mode")

        # Update document type label
        ui_map = {"notes": "Notes", "reports": "Report", "letters": "Letter"}
        self._detected_document_type = dtype
        if hasattr(self, 'document_type_label'):
            self.document_type_label.setText(ui_map.get(dtype, "Report"))

        # Run extraction with this file
        self._extract_from_file(file_path, dtype)

    def _extract_from_file(self, file_path: str, dtype: str):
        """
        Core extraction logic - shared by load_file and upload_and_extract.
        """
        files = [file_path]
        is_excel_notes = dtype == "notes"

        # Show loading status
        self.extract_btn.setText("Loading document...")
        QApplication.processEvents()

        self.notes = []

        print(f"[DTYPE] Document type = '{dtype}' (is_excel={is_excel_notes})")
        self.notes = self._load_documents(files, dtype)

        # Update status
        self.extract_btn.setText(f"Processing {len(self.notes)} entries...")
        QApplication.processEvents()

        # --------------------------------------------------
        # AUTO-DETECT REPORT TYPE FROM NOTES (for PDF/Word)
        # --------------------------------------------------
        auto_report_type = None
        auto_report_confidence = None

        detected_types = {
            n.get("report_type")
            for n in self.notes
            if n.get("report_type")
        }

        if len(detected_types) == 1:
            auto_report_type = detected_types.pop()
            for n in self.notes:
                if n.get("report_type") == auto_report_type:
                    auto_report_confidence = n.get("report_confidence")
                    break
            print(f"[AUTO-DETECT] 📄 Detected report type: {auto_report_type}")
        elif detected_types:
            print(f"[AUTO-DETECT] ⚠️ Ambiguous report types: {detected_types}")

        # Confidence gate
        if (auto_report_type and auto_report_confidence is not None
                and auto_report_confidence < AUTO_DETECT_CONFIDENCE_MIN):
            print(f"[AUTO-DETECT] ⚠️ Low confidence ({auto_report_confidence}) — ignoring")
            auto_report_type = None

        # Cache
        self._auto_report_type = auto_report_type
        self._auto_report_confidence = auto_report_confidence

        # Load classifier terms
        if not hasattr(self, "_letter_search_terms"):
            self._letter_search_terms = load_letter_search_terms(
                resource_path("Letter_headings_search_v2.txt")
            )

        # =================================================
        # NOTES → STRUCTURED HISTORY (Excel files)
        # =================================================
        print(f"[ROUTING] dtype='{dtype}', is_excel_notes={is_excel_notes}")

        if dtype == "notes":
            print("[ROUTING] ✅ Taking NOTES path -> extract_patient_history")
            self._extract_notes_history()
        # =================================================
        # REPORTS (heading-based)
        # =================================================
        elif dtype == "reports":
            print("[ROUTING] Taking REPORTS path")
            self._extract_reports(auto_report_type, auto_report_confidence)
        # =================================================
        # LETTERS / FREE TEXT
        # =================================================
        else:
            print("[ROUTING] Taking LETTERS/FREE TEXT path")
            self._latest_panel_data = extract_from_free_text(self.notes)

        # Store and merge
        self._finalize_extraction(dtype, file_path)

    def _extract_patient_demographics(self):
        """
        Extract patient demographics (name, DOB, NHS number, gender) from notes.
        - Looks at TOP of notes for structured demographic data
        - Scans ALL notes for patterns and pronouns
        """
        import re
        from datetime import datetime

        demographics = {
            "name": None,
            "dob": None,
            "nhs_number": None,
            "gender": None,
            "age": None,
            "ethnicity": None,
            "mha_section": None,
            "hospital": None,
            "ward": None,
        }

        if not self.notes:
            return demographics

        # Get text from first note (usually has demographics at top)
        first_note_text = ""
        if self.notes:
            first_note = self.notes[0]
            first_note_text = first_note.get("text") or first_note.get("content") or ""

        # Get combined text from first 20 notes for demographic search
        top_notes_text = ""
        for note in self.notes[:20]:
            text = note.get("text") or note.get("content") or ""
            top_notes_text += text + "\n"

        # Get ALL notes text for pronoun counting
        all_notes_text = ""
        for note in self.notes:
            text = note.get("text") or note.get("content") or ""
            all_notes_text += text + "\n"

        all_notes_lower = all_notes_text.lower()

        # ============================================================
        # EXTRACT NAME - scan line by line in top notes
        # ============================================================
        name_candidates = []

        for line in top_notes_text.split('\n'):
            line = line.strip()
            if not line:
                continue

            # Pattern 1: "PATIENT NAME: Firstname Lastname" or "PATIENT NAME Firstname Lastname"
            match = re.match(r"(?:PATIENT\s*NAME|CLIENT\s*NAME|NAME)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z][A-Za-z\-\']+)?)\s*$", line, re.IGNORECASE)
            if match:
                candidate = match.group(1).strip()
                # Make sure it's not a field label
                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH|ADDRESS)", candidate, re.IGNORECASE):
                    name_candidates.append(candidate)
                    continue

            # Pattern 2: Line starts with "Name:" or "Patient:"
            match = re.match(r"(?:Name|Patient)\s*[:\-]\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z\-\']+)?)", line, re.IGNORECASE)
            if match:
                candidate = match.group(1).strip()
                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH)", candidate, re.IGNORECASE):
                    name_candidates.append(candidate)

        # Use the first valid name found (filter out false positives)
        invalid_name_patterns = [
            r"(?i)responsible\s*clinician",
            r"(?i)approved\s*clinician",
            r"(?i)social\s*worker",
            r"(?i)report\s*of",
            r"(?i)^of\s+",  # Names starting with "of"
            r"(?i)tribunal",
            r"(?i)mental\s*health",
            r"(?i)first\s*tier",
            r"(?i)care\s*coordinator",
            r"(?i)nurse",
            r"(?i)doctor",
        ]
        for candidate in name_candidates:
            is_valid = True
            for pattern in invalid_name_patterns:
                if re.search(pattern, candidate):
                    print(f"[DEMOGRAPHICS] Rejected name '{candidate}' - matches invalid pattern")
                    is_valid = False
                    break
            if is_valid:
                demographics["name"] = candidate
                print(f"[DEMOGRAPHICS] Found name: {demographics['name']}")
                break

        # ============================================================
        # EXTRACT DOB - search all top notes
        # ============================================================
        dob_patterns = [
            r"(?:DATE\s*OF\s*BIRTH|D\.?O\.?B\.?|DOB)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})",
            r"(?:BORN|BIRTH\s*DATE)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})",
        ]
        for pattern in dob_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                dob_str = match.group(1).strip()
                for fmt in ["%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d/%m/%y", "%d-%m-%y"]:
                    try:
                        demographics["dob"] = datetime.strptime(dob_str, fmt)
                        print(f"[DEMOGRAPHICS] Found DOB: {dob_str}")
                        break
                    except ValueError:
                        continue
                if demographics["dob"]:
                    break

        # Try text date format: "7 October 1979", "15 Jan 1985", etc.
        if not demographics["dob"]:
            text_dob_patterns = [
                r"(?:DATE\s*OF\s*BIRTH|D\.?O\.?B\.?|DOB)\s*[:\-]?\s*(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})",
                r"(?:BORN)\s*[:\-]?\s*(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})",
            ]
            for pattern in text_dob_patterns:
                match = re.search(pattern, top_notes_text, re.IGNORECASE)
                if match:
                    day = int(match.group(1))
                    month_str = match.group(2)
                    year = int(match.group(3))
                    month_map = {
                        'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
                        'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
                        'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
                        'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12
                    }
                    month = month_map.get(month_str.lower(), 1)
                    try:
                        demographics["dob"] = datetime(year, month, day)
                        print(f"[DEMOGRAPHICS] Found DOB (text format): {day} {month_str} {year}")
                        break
                    except ValueError:
                        pass

        # ============================================================
        # EXTRACT NHS NUMBER
        # ============================================================
        nhs_patterns = [
            r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{3}\s*\d{3}\s*\d{4})",
            r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{10})",
        ]
        for pattern in nhs_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                nhs = match.group(1).replace(" ", "")
                if len(nhs) == 10:
                    demographics["nhs_number"] = f"{nhs[:3]} {nhs[3:6]} {nhs[6:]}"
                else:
                    demographics["nhs_number"] = nhs
                print(f"[DEMOGRAPHICS] Found NHS: {demographics['nhs_number']}")
                break

        # ============================================================
        # EXTRACT GENDER - explicit patterns first, then pronouns
        # ============================================================
        # Try explicit gender fields
        gender_patterns = [
            r"(?:GENDER|SEX)\s*[:\-]\s*(MALE|FEMALE|M|F)\b",
            r"\b(MALE|FEMALE)\s+PATIENT\b",
            r"\bPATIENT\s+IS\s+(?:A\s+)?(MALE|FEMALE)\b",
        ]
        for pattern in gender_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                g = match.group(1).upper()
                if g in ("MALE", "M"):
                    demographics["gender"] = "Male"
                elif g in ("FEMALE", "F"):
                    demographics["gender"] = "Female"
                print(f"[DEMOGRAPHICS] Found gender from label: {demographics['gender']}")
                break

        # Fallback: count pronouns across ALL notes
        if not demographics["gender"]:
            male_pronouns = len(re.findall(r"\bhe\b|\bhim\b|\bhis\b", all_notes_lower))
            female_pronouns = len(re.findall(r"\bshe\b|\bher\b|\bhers\b", all_notes_lower))

            print(f"[DEMOGRAPHICS] Pronoun count - Male: {male_pronouns}, Female: {female_pronouns}")

            # Need a clear majority (at least 2x difference or 10+ more)
            if male_pronouns > female_pronouns * 2 or male_pronouns > female_pronouns + 10:
                demographics["gender"] = "Male"
                print(f"[DEMOGRAPHICS] Inferred gender from pronouns: Male")
            elif female_pronouns > male_pronouns * 2 or female_pronouns > male_pronouns + 10:
                demographics["gender"] = "Female"
                print(f"[DEMOGRAPHICS] Inferred gender from pronouns: Female")

        # ============================================================
        # EXTRACT AGE - explicit patterns or calculate from DOB
        # ============================================================
        age_patterns = [
            r"(?:AGE)\s*[:\-]?\s*(\d{1,3})\s*(?:years?|yrs?|y\.?o\.?)?\b",
            r"\b(\d{1,3})\s*(?:year|yr)\s*old\b",
            r"\b(\d{1,3})\s*y\.?o\.?\b",
            r"\baged?\s*(\d{1,3})\b",
        ]
        for pattern in age_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                age_val = int(match.group(1))
                if 0 < age_val < 120:  # Sanity check
                    demographics["age"] = age_val
                    print(f"[DEMOGRAPHICS] Found age from pattern: {age_val}")
                    break

        # Calculate age from DOB if not found explicitly
        if not demographics["age"] and demographics["dob"]:
            today = datetime.today()
            dob = demographics["dob"]
            age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
            if 0 < age < 120:
                demographics["age"] = age
                print(f"[DEMOGRAPHICS] Calculated age from DOB: {age}")

        # ============================================================
        # EXTRACT ETHNICITY - NHS ethnicity categories
        # ============================================================
        ethnicity_patterns = [
            r"(?:ETHNICITY|ETHNIC\s*(?:GROUP|ORIGIN|BACKGROUND)?)\s*[:\-]\s*([A-Za-z][A-Za-z\s\-\/]+?)(?:\n|$|,)",
            # NHS ethnicity categories
            r"\b(White\s*(?:British|Irish|European|Other)?)\b",
            r"\b(Black\s*(?:British|African|Caribbean|Other)?)\b",
            r"\b(Asian\s*(?:British|Indian|Pakistani|Bangladeshi|Chinese|Other)?)\b",
            r"\b(Mixed\s*(?:White\s*(?:and|&)\s*(?:Black\s*(?:Caribbean|African)|Asian))?)\b",
            r"\b(African)\b",
            r"\b(Caribbean)\b",
            r"\b(Indian)\b",
            r"\b(Pakistani)\b",
            r"\b(Bangladeshi)\b",
            r"\b(Chinese)\b",
            r"\b(Arab)\b",
        ]
        for pattern in ethnicity_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                ethnicity_val = match.group(1).strip()
                # Clean up and validate
                if len(ethnicity_val) > 2 and not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|NAME)", ethnicity_val, re.IGNORECASE):
                    demographics["ethnicity"] = ethnicity_val.title()
                    print(f"[DEMOGRAPHICS] Found ethnicity: {demographics['ethnicity']}")
                    break

        # ============================================================
        # EXTRACT MHA SECTION - Mental Health Act section
        # ============================================================
        mha_patterns = [
            r"(?:MHA\s*)?(?:SECTION|SEC\.?)\s*[:\-]?\s*((?:\d+(?:/\d+)?(?:\s*\(\d+\))?)|(?:2|3|37|37/41|47/49|48/49|35|36|38))\b",
            r"(?:DETAINED\s*UNDER|UNDER)\s*(?:MHA\s*)?(?:SECTION|SEC\.?)\s*[:\-]?\s*(\d+(?:/\d+)?)",
            r"(?:S\.?|SECTION)\s*(\d+(?:/\d+)?)\s*(?:MHA|PATIENT)",
            r"\b(Section\s*\d+(?:/\d+)?)\b",
        ]
        for pattern in mha_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                section = match.group(1).strip()
                # Normalize: "Section 3" or just "3"
                if not section.lower().startswith("section"):
                    section = f"Section {section}"
                demographics["mha_section"] = section
                print(f"[DEMOGRAPHICS] Found MHA Section: {demographics['mha_section']}")
                break

        # ============================================================
        # EXTRACT HOSPITAL
        # ============================================================
        hospital_patterns = [
            r"(?:HOSPITAL|HOSP\.?)\s*[:\-]\s*([A-Za-z][A-Za-z\s\'\-]+?)(?:\n|Ward|,|$)",
            r"(?:DETAINED\s*AT|ADMITTED\s*TO|AT)\s+([A-Za-z][A-Za-z\s\'\-]+?(?:Hospital|Centre|Unit|Clinic))",
            r"([A-Za-z][A-Za-z\s\'\-]+?(?:Hospital|Centre|Unit|Clinic))\b",
        ]
        for pattern in hospital_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                hospital = match.group(1).strip()
                # Filter out invalid matches
                if len(hospital) > 3 and not re.match(r"(?:Name|Patient|Date|NHS|The|A|An|This)\b", hospital, re.IGNORECASE):
                    demographics["hospital"] = hospital
                    print(f"[DEMOGRAPHICS] Found Hospital: {demographics['hospital']}")
                    break

        # ============================================================
        # EXTRACT WARD
        # ============================================================
        ward_patterns = [
            r"(?:WARD)\s*[:\-]\s*([A-Za-z][A-Za-z0-9\s\'\-]+?)(?:\n|,|$|Hospital)",
            r"(?:ON|IN)\s+([A-Za-z][A-Za-z0-9\s\'\-]+?)\s*(?:WARD)\b",
            r"([A-Za-z][A-Za-z0-9\s\'\-]+?)\s*(?:WARD)\b",
        ]
        for pattern in ward_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                ward = match.group(1).strip()
                # Filter out invalid matches
                if len(ward) > 1 and not re.match(r"(?:Name|Patient|Date|NHS|The|A|An|This)\b", ward, re.IGNORECASE):
                    # Add "Ward" suffix if not already there
                    if not ward.lower().endswith("ward"):
                        ward = f"{ward} Ward"
                    demographics["ward"] = ward
                    print(f"[DEMOGRAPHICS] Found Ward: {demographics['ward']}")
                    break

        # ============================================================
        # TRIBUNAL FORMAT: Extract patient name from "Patient's name" or table format
        # More flexible patterns to match various PDF formats
        # ============================================================
        if not demographics["name"]:
            tribunal_name_patterns = [
                # Flexible patterns matching tribunal's approach
                r"(?:Patient'?s?\s*name|Full\s*name)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
                r"(?:Name\s*of\s*patient)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
                r"(?:RE|Re|PATIENT)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
                # Simple "Name:" pattern like tribunal uses
                r"(?:Name|Patient)\s*[:\s]+([A-Za-z][A-Za-z\-\' ]+)",
            ]
            for pattern in tribunal_name_patterns:
                match = re.search(pattern, top_notes_text, re.IGNORECASE)
                if match:
                    candidate = match.group(1).strip()
                    # Remove trailing labels that got captured
                    candidate = re.sub(r"\s*(?:Date|DOB|NHS|Gender|Sex|Age|Birth|Address|Hospital|Ward|Section|MHA).*$", "", candidate, flags=re.IGNORECASE).strip()
                    # Must have at least 2 words for a valid name
                    if len(candidate.split()) >= 2:
                        # Check against invalid names
                        is_valid = True
                        for inv_pattern in invalid_name_patterns:
                            if re.search(inv_pattern, candidate):
                                is_valid = False
                                break
                        if is_valid:
                            demographics["name"] = candidate
                            print(f"[DEMOGRAPHICS] Found name (tribunal format): {demographics['name']}")
                            break

        print(f"[DEMOGRAPHICS] Final result: {demographics}")
        return demographics

    def _extract_notes_history(self):
        """Extract structured history from clinical notes (Excel)."""
        def _normalise_system(n):
            meta = n.get("source_meta")
            if isinstance(meta, dict):
                system = (meta.get("system") or "").strip().lower()
                if system in {"rio", "carenotes", "epjs"}:
                    return system
            src = n.get("source")
            if isinstance(src, str):
                src = src.strip().lower()
                if src in {"rio", "carenotes", "epjs"}:
                    return src
            return "carenotes"

        prepared = []
        for n in self.notes:
            prepared.append({
                "date": n.get("date"),
                "type": (n.get("type") or "").lower(),
                "originator": n.get("originator"),
                "content": n.get("content") or n.get("text", ""),
                "text": n.get("text") or n.get("content", ""),
                "source": self.pipeline,
                "source_meta": {
                    "system": self.pipeline,
                    "report": "Clinical Notes",
                    "file": (
                        n.get("source_meta", {}).get("file")
                        if isinstance(n.get("source_meta"), dict)
                        else (
                            n.get("source", {}).get("file")
                            if isinstance(n.get("source"), dict)
                            else "Unknown file"
                        )
                    ),
                },
            })

        episodes = build_timeline(prepared)

        history = extract_patient_history(
            prepared,
            episodes=episodes,
            pipeline=self.pipeline,
            debug=True,
        )

        self._latest_panel_data = convert_to_panel_format(history)

        # DEBUG
        print(f"[HISTORY DEBUG] Extracted history categories:")
        for cat_key, cat_data in self._latest_panel_data.get("categories", {}).items():
            item_count = len(cat_data.get("items", []))
            cat_name = cat_data.get("name", "?")
            print(f"  [{cat_key}] {cat_name}: {item_count} items")

        self._normalise_note_categories(self._latest_panel_data)

        # DEBUG after normalisation
        print(f"[HISTORY DEBUG] After _normalise_note_categories:")
        for cat_key, cat_data in self._latest_panel_data.get("categories", {}).items():
            item_count = len(cat_data.get("items", []))
            cat_name = cat_data.get("name", "?")
            print(f"  [{cat_key}] {cat_name}: {item_count} items")

        self._normalise_panel_sources(self._latest_panel_data)
        self._apply_notes_provenance(self._latest_panel_data, report_label="Clinical Notes")

        # DEBUG after all normalisations
        print(f"[HISTORY DEBUG] After all normalisations in _extract_notes_history:")
        for cat_key, cat_data in self._latest_panel_data.get("categories", {}).items():
            item_count = len(cat_data.get("items", []))
            print(f"  {cat_key}: {item_count} items")

    def _extract_reports(self, auto_report_type, auto_report_confidence):
        """Extract from reports/letters using content blocks or classifier."""
        if (auto_report_type in {"medical", "nursing", "social"}
                and auto_report_confidence is not None
                and auto_report_confidence >= AUTO_DETECT_CONFIDENCE_MIN):
            if auto_report_type == "medical":
                print("[EXTRACTOR] 🔒 Using RC numbered tribunal extractor")
                self._latest_panel_data = self.extract_from_rc_report(self.notes)
            else:
                print("[EXTRACTOR] Using heading-based tribunal extractor")
                self._latest_panel_data = extract_by_ranges(self.notes, auto_report_type)
        else:
            print("[REPORT] 🧠 Using content-first block extractor")
            self._latest_panel_data = extract_by_content_blocks(self.notes, LETTER_CONTENT_TERMS)

        self._normalise_panel_sources(self._latest_panel_data)

    def _finalize_extraction(self, dtype: str, file_path: str):
        """Finalize extraction - merge, dedupe, refresh UI."""

        # DEBUG: Show incoming data
        print(f"[FINALIZE DEBUG] _latest_panel_data entering finalize:")
        if self._latest_panel_data:
            for cat_key, cat_data in self._latest_panel_data.get("categories", {}).items():
                item_count = len(cat_data.get("items", []))
                print(f"  {cat_key}: {item_count} items")
        else:
            print("  None")

        # Safety fallback
        if self._latest_panel_data and not self._latest_panel_data.get("categories"):
            print("[FALLBACK] ⚠️ Empty result — using Summary fallback")
            self._latest_panel_data = extract_from_free_text(self.notes)

        # Store by dtype
        existing = self._panel_data_by_dtype.get(dtype)
        print(f"[FINALIZE DEBUG] existing panel for {dtype}: {bool(existing)}")

        if existing:
            print(f"[FINALIZE DEBUG] Existing panel categories:")
            for cat_key in existing.get("categories", {}).keys():
                print(f"  {cat_key}")
            merged = self._merge_panels([existing, self._latest_panel_data])
        else:
            merged = self._latest_panel_data

        merged = self._dedupe_panel_data(merged)
        self._panel_data_by_dtype[dtype] = merged

        # Rebuild combined panel
        self._latest_panel_data = self._merge_panels(list(self._panel_data_by_dtype.values()))

        # DEBUG: Show final data
        print(f"[FINALIZE DEBUG] _latest_panel_data after rebuild:")
        for cat_key, cat_data in self._latest_panel_data.get("categories", {}).items():
            item_count = len(cat_data.get("items", []))
            print(f"  {cat_key}: {item_count} items")

        # Reset UI state
        self._collapsed_blocks = set()
        self._new_item_keys = set()
        self._last_rendered_block_key = None

        # Refresh preview
        self.extract_btn.setText("Building preview...")
        QApplication.processEvents()

        self._refresh_preview_from_cache()

        # Clear status
        self.extract_btn.setText("")

        # Emit signal for parent pages
        if self._latest_panel_data:
            print(f"[EXTRACTOR] ✅ Extraction complete - emitting data_extracted signal")
            self.data_extracted.emit(self._latest_panel_data)

        # Global import - ALWAYS push notes AND extracted data to SharedDataStore for all sections
        print(f"[EXTRACTOR] 🌐 Starting global import - notes count: {len(self.notes)}, panel_data: {bool(self._latest_panel_data)}")
        shared_store = get_shared_store()

        # Extract and push patient demographics using central module
        try:
            from patient_demographics import extract_demographics
            patient_info = extract_demographics(self.notes)
        except ImportError:
            # Fallback to local extraction if central module not available
            patient_info = self._extract_patient_demographics()

        if any(patient_info.values()):
            shared_store.set_patient_info(patient_info, source="data_extractor")
            print(f"[EXTRACTOR] 🌐 Global import: pushed patient info to SharedDataStore: {list(k for k,v in patient_info.items() if v)}")

        # Push raw notes for Notes Panel
        if self.notes:
            normalized_notes = []
            for n in self.notes:
                normalized_notes.append({
                    "date": n.get("date"),
                    "type": str(n.get("type", "")).strip(),
                    "originator": str(n.get("originator", "")).strip(),
                    "content": n.get("content") or n.get("text", ""),
                    "preview": (n.get("content") or n.get("text", ""))[:200],
                    "source": str(n.get("source", "")).lower()
                })
            shared_store.set_notes(normalized_notes, source="data_extractor")
            print(f"[EXTRACTOR] 🌐 Global import: pushed {len(normalized_notes)} notes to SharedDataStore")
        else:
            print(f"[EXTRACTOR] ⚠️ No notes to push - self.notes is empty!")

        # Push extracted/categorized data for auto-populating reports and forms
        if self._latest_panel_data:
            categories = self._latest_panel_data.get("categories", {})
            print(f"[EXTRACTOR] 🌐 Global import: panel_data categories: {list(categories.keys())}")
            shared_store.set_extracted_data(self._latest_panel_data, source="data_extractor")
            print(f"[EXTRACTOR] 🌐 Global import: pushed extracted panel_data to SharedDataStore")
        else:
            print(f"[EXTRACTOR] ⚠️ No panel_data to push - _latest_panel_data is empty!")

        print(f"[EXTRACTOR] Done processing: {file_path}")

    def upload_and_extract(self, file_path=None):
        """Process an uploaded file - uses load_file for core logic."""
        if not file_path:
            return

        # Use the shared load_file method which handles auto-detection
        self.load_file(file_path)

    # =====================================================
    # Panel Dedupe Helper (DATA LEVEL, NOT UI)
    # =====================================================
    def _dedupe_panel_data(self, panel_data):
        if not panel_data:
            return panel_data

        seen = set()

        for cat in panel_data.get("categories", {}).values():
            unique_items = []

            for item in cat.get("items", []):
                text = (item.get("text") or "").strip()
                source = item.get("source", {}) or {}

                key = (
                    " ".join(text.split()).lower(),
                    source.get("report"),
                    source.get("file"),
                    item.get("date"),
                )

                if key in seen:
                    continue

                seen.add(key)
                unique_items.append(item)

            cat["items"] = unique_items

        return panel_data




    # =====================================================
    # Merge Helper
    # =====================================================
    def _merge_panels(self, panels):
        merged = {"categories": {}}

        for p in panels:
            for k, v in p.get("categories", {}).items():
                merged["categories"].setdefault(k, {
                    "name": v["name"],
                    "items": [],
                })
                merged["categories"][k]["items"].extend(v["items"])

        return merged


    # =====================================================
    # STRIPPER
    # =====================================================
    def _strip_rc_question_lines(self, text: str) -> str:
        patterns = [
            r"^is the patient now suffering from a mental disorder\??",
            r"^if yes, has a diagnosis been made.*",
            r"^give details of.*",
            r"^what are the.*",
        ]

        lines = []
        for line in text.splitlines():
            l = line.strip()
            if not l:
                continue

            skip = False
            for p in patterns:
                if re.match(p, l, re.IGNORECASE):
                    skip = True
                    break

            if not skip:
                lines.append(l)

        return "\n".join(lines).strip()
    # =====================================================
    # DEDUPE
    # =====================================================
    def _dedupe_items(self, items):
        """
        Deduplicate items by normalised text.
        Keeps first occurrence, preserves order.
        """
        seen = set()
        cleaned = []

        for item in items:
            text = item.get("text", "")
            norm = " ".join(text.split()).lower()

            if not norm:
                continue

            if norm in seen:
                continue

            seen.add(norm)
            cleaned.append(item)

        return cleaned

    # =====================================================
    # EXTRACT RC FROM REPORT
    # =====================================================
    def extract_from_rc_report(self, notes):
        """
        Extracts structured history from an RC Tribunal / Medical Report
        using authoritative RC question numbering.
        Returns MyPsychAdmin panel-format data.
        """

        import re
        from collections import defaultdict

        # =====================================================
        # RC QUESTION → CATEGORY MAP (AUTHORITATIVE)
        # =====================================================
        QUESTION_CATEGORY_MAP = {
            1: "patient_details",
            2: "author",
            3: "factors_hearing",
            4: "adjustments",
            5: "forensic",
            6: "previous_mh_dates",
            7: "previous_admission_reasons",
            8: "current_admission",
            9: "diagnosis",
            10: "learning_disability",
            11: "detention_required",
            12: "treatment",
            13: "strengths",
            14: "progress",
            15: "compliance",
            16: "mca_dol",
            17: "risk_harm",
            18: "risk_property",
            19: "s2_detention",
            20: "other_detention",
            21: "discharge_risk",
            22: "community",
            23: "recommendations",
            24: "signature",
        }

        # Questions that are simple yes/no — still extract them for completeness
        HARD_STOP_QUESTIONS = set()

        QUESTION_HEADER_RE = re.compile(r"^\s*(\d+)[\.\)]\s*(.*)")
        # Match lines that are just Yes/No tick boxes in any format
        CHECKBOX_RE = re.compile(
            r"^\s*("
            r"(Yes|No|N/A)"                           # bare Yes/No/N/A
            r"|[\s☐☒✓✗\[\]]*\s*(Yes|No)\s*[\s☐☒✓✗\[\]]*\s*(Yes|No)?[\s☐☒✓✗\[\]]*"  # ☐ No ☐ Yes, Yes [ ] No [ ], etc.
            r"|No\s*\[.*?\]\s*Yes\s*\[.*?\]"           # No [ ] Yes [x]
            r"|Yes\s*\[.*?\]\s*No\s*\[.*?\]"           # Yes [ ] No [x]
            r")\s*$", re.IGNORECASE)
        SEE_ABOVE_RE = re.compile(r"^see above$", re.IGNORECASE)

        # =====================================================
        # BUILD FULL TEXT
        # =====================================================
        full_text = "\n".join(
            n.get("text", "")
            for n in notes
            if n.get("text")
        )

        if not full_text.strip():
            return {"categories": {}}

        # =====================================================
        # SPLIT INTO NUMBERED QUESTIONS
        # =====================================================
        lines = full_text.splitlines()

        questions = []
        current_q = None
        current_text = []

        for line in lines:
            m = QUESTION_HEADER_RE.match(line)
            if m:
                if current_q is not None:
                    questions.append(
                        (current_q, "\n".join(current_text).strip())
                    )
                current_q = int(m.group(1))
                current_text = []  # Skip the question heading, only capture answer text
            else:
                if current_q is not None:
                    current_text.append(line)

        if current_q is not None:
            questions.append(
                (current_q, "\n".join(current_text).strip())
            )

        # DEBUG: Show detected questions
        detected_qnums = [q for q, _ in questions]
        print(f"[RC EXTRACTOR] Detected question numbers: {detected_qnums}")

        # =====================================================
        # EXTRACT BY QUESTION NUMBER
        # =====================================================
        category_items = defaultdict(list)

        for q_num, raw_text in questions:
            if q_num in HARD_STOP_QUESTIONS:
                print(f"[RC EXTRACTOR] Skipping Q{q_num} (HARD_STOP)")
                continue

            category = QUESTION_CATEGORY_MAP.get(q_num)
            if not category:
                print(f"[RC EXTRACTOR] Skipping Q{q_num} (no category mapping)")
                continue

            print(f"[RC EXTRACTOR] Q{q_num} -> {category}")

            cleaned_lines = []
            seen = set()

            for line in raw_text.splitlines():
                line = line.strip()
                if not line:
                    continue
                if CHECKBOX_RE.match(line):
                    continue
                if SEE_ABOVE_RE.match(line):
                    continue

                norm = line.lower()
                if norm in seen:
                    continue
                seen.add(norm)
                cleaned_lines.append(line)

            if not cleaned_lines:
                continue

            source_meta = notes[0].get("source_meta", {}) or {}

            category_items[category].append({
                "date": None,
                "text": "\n".join(cleaned_lines),
                "source": {
                    "report": source_meta.get("report", "Medical report"),
                    "file": source_meta.get("file", "Unknown file"),
                },
                "source_meta": {
                    "source_label": source_meta.get("source_label"),
                },
            })


        # =====================================================
        # BUILD PANEL FORMAT
        # =====================================================
        panel_data = {"categories": {}}

        for category, items in category_items.items():
            panel_data["categories"][category] = {
                "name": category,
                "items": items,
            }

        return panel_data
    
    def _normalise_category_key(self, label: str) -> str:
        return label.strip().lower().replace(" ", "_")

    def _normalise_panel_sources(self, panel_data):
        for cat in panel_data.get("categories", {}).values():
            for item in cat.get("items", []):
                if not isinstance(item.get("source"), dict):
                    item["source"] = {}

                src = item["source"]

                src.setdefault("system", "Unknown")
                src.setdefault("report", "Unknown")
                src.setdefault("file", "Unknown")

                # ---------------------------------
                # UI provenance label (authoritative)
                # ---------------------------------
                meta = item.get("source_meta")
                label = None

                if isinstance(meta, dict):
                    label = meta.get("source_label")

                if not label:
                    report = src.get("report")
                    file = src.get("file")

                    if file and file not in ("Unknown file", ""):
                        label = f"{report} – {os.path.basename(file)}"
                    elif report:
                        label = report

                if label:
                    src["label"] = label

                
    def _refresh_preview_from_cache(self):
        if not self._latest_panel_data:
            return

        for w in self._date_widgets.values():
            w.setParent(None)
        # -----------------------------------------
        # STEP 4A — HIDE ALL CACHED DATE WIDGETS
        # -----------------------------------------
        for w in self._date_widgets.values():
            w.setVisible(False)

        # CLEAR PREVIEW CONTAINER (REBUILD VIEW)
        while self.preview_layout.count():
            item = self.preview_layout.takeAt(0)
            widget = item.widget()
            if widget:
                widget.setParent(None)

        selected = self.category_dropdown.currentText()

        # -----------------------------------------
        # NORMALISE + MERGE CATEGORIES (UI FIREWALL)
        # -----------------------------------------
        merged_categories = {}

        # DEBUG: Show what categories we have
        raw_categories = list(self._latest_panel_data.get("categories", {}).keys())
        print(f"[PREVIEW DEBUG] Raw category keys: {raw_categories}")

        for cat in self._latest_panel_data.get("categories", {}).values():
            raw_name = cat.get("name")
            item_count = len(cat.get("items", []))
            canon = self._normalise_category(raw_name)

            print(f"[PREVIEW DEBUG] Category '{raw_name}' ({item_count} items) -> canon: {canon}")

            if not canon:
                print(f"[PREVIEW DEBUG] ⚠️ DROPPED category '{raw_name}' (no canonical mapping)")
                continue

            merged_categories.setdefault(canon, {
                "name": canon,
                "items": []
            })

            merged_categories[canon]["items"].extend(
                cat.get("items", [])
            )

        # DEBUG: Show final merged categories
        print(f"[PREVIEW DEBUG] Merged categories: {list(merged_categories.keys())}")
        for k, v in merged_categories.items():
            print(f"[PREVIEW DEBUG]   {k}: {len(v.get('items', []))} items")

        # -----------------------------------------
        # RENDER CATEGORIES (FILTERED)
        # -----------------------------------------
        for canon in LETTER_CATEGORY_ORDER:
            cat = merged_categories.get(canon)
            if not cat:
                continue

            category_name = canon
            items = self._dedupe_items(cat["items"])

            if not items:
                continue


            if selected != "All Categories":
                selected_canon = self._normalise_category(selected)

                if selected_canon != category_name:
                    continue



            # -----------------------------------------
            # CATEGORY HEADER (STATIC)
            # -----------------------------------------
            display_name = category_name.replace("_", " ").title()

            header = QLabel(
                f"{display_name.upper()} ({len(items)} items)",
                self.preview_container
            )

            header.setWordWrap(True)

            header.setWindowFlags(Qt.Widget)
            header.setAttribute(Qt.WA_NativeWindow, False)
            header.setAttribute(Qt.WA_DontCreateNativeAncestors, True)

            # 🔑 FIX 1 — remove top margin for first visible category
            if self.preview_layout.count() == 0:
                header.setStyleSheet("""
                    font-size: 16px;
                    font-weight: 700;
                    margin-top: 0px;
                    margin-bottom: 6px;
                """)
            else:
                header.setStyleSheet("""
                    font-size: 16px;
                    font-weight: 700;
                    margin-top: 12px;
                    margin-bottom: 6px;
                """)

            self.preview_layout.addWidget(header)

            # -----------------------------------------
            # GROUP BY PROVENANCE
            # -----------------------------------------
            grouped = {}
            for item in items:
                source = item.get("source", {})

                label = source.get("label")
                if not label:
                    label = "Imported document"

                grouped.setdefault(label, []).append(item)


            for label, block_items in grouped.items():
                # Limit preview items to prevent UI freeze
                MAX_PREVIEW_ITEMS = 100
                total_items = len(block_items)
                display_items = block_items[:MAX_PREVIEW_ITEMS]
                truncated = total_items > MAX_PREVIEW_ITEMS

                prov_key = (category_name, label)

                is_collapsed = prov_key in self._collapsed_blocks
                arrow = "▸" if is_collapsed else "▾"

                # Show truncation notice in header if needed
                count_text = f"{total_items} items" if not truncated else f"{total_items} items, showing first {MAX_PREVIEW_ITEMS}"
                header_btn = QPushButton(
                    f"{arrow} From {label} ({count_text})",
                    self.preview_container
                )
                header_btn.setCheckable(True)
                header_btn.setChecked(not is_collapsed)

                header_btn.setStyleSheet("""
                    QPushButton {
                        border: none;
                        background: transparent;
                        text-align: left;
                        font-size: 13px;
                        font-weight: 600;
                        padding: 4px 0;
                    }
                    QPushButton::text {
                        padding-left: 0px;
                    }
                    QPushButton:hover {
                        background: rgba(0,0,0,0.05);
                        border-radius: 6px;
                    }
                """)


                self.preview_layout.addWidget(header_btn)
                report_container = QWidget(self.preview_container)
                report_layout = QVBoxLayout(report_container)
                report_layout.setContentsMargins(12, 2, 0, 6)
                report_layout.setSpacing(4)

                self.preview_layout.addWidget(report_container)
                report_container.setVisible(not is_collapsed)
                def _toggle_report(
                    checked,
                    _prov_key=prov_key,
                    _container=report_container,
                    _btn=header_btn,
                    _label=label,
                    _count_text=count_text,
                ):
                    collapsed = not checked

                    if collapsed:
                        self._collapsed_blocks.add(_prov_key)
                        _container.setVisible(False)
                        _btn.setText(
                            f"▸▸  From {_label} ({_count_text})"
                        )
                    else:
                        self._collapsed_blocks.discard(_prov_key)
                        _container.setVisible(True)
                        _btn.setText(
                            f"▾▾  From {_label} ({_count_text})"
                        )

                header_btn.toggled.connect(_toggle_report)

                by_date = {}
                undated = []

                # Use display_items (limited) instead of block_items (all)
                for item in display_items:
                    dt = item.get("date")
                    if dt:
                        by_date.setdefault(dt, []).append(item)
                    else:
                        undated.append(item)

                # -----------------------------------------
                # UNDATED ITEMS
                # -----------------------------------------
                for item in undated:
                    raw = item.get("text", "")
                    if not raw:
                        continue

                    cleaned = self._strip_rc_question_lines(raw)
                    for line in cleaned.splitlines():
                        if line.strip():
                            lbl = QLabel(line, self.preview_container)

                            lbl.setWordWrap(True)
                            lbl.setWindowFlags(Qt.Widget)
                            lbl.setAttribute(Qt.WA_NativeWindow, False)
                            lbl.setAttribute(Qt.WA_DontCreateNativeAncestors, True)

                            lbl.setStyleSheet("font-size: 12px;")
                            report_layout.addWidget(lbl)

                # -----------------------------------------
                # DATED ITEMS (CACHED WIDGETS)
                # -----------------------------------------
                for dt in sorted(by_date.keys()):
                    date_label = (
                        dt.strftime("%d %b %Y")
                        if hasattr(dt, "strftime")
                        else str(dt)
                    )

                    lines = []
                    for item in by_date[dt]:
                        raw = item.get("text", "")
                        if not raw:
                            continue

                        cleaned = self._strip_rc_question_lines(raw)
                        for line in cleaned.splitlines():
                            line = line.strip()
                            if line:
                                lines.append(line)

                    if not lines:
                        continue

                    cache_key = (
                        selected,
                        category_name,
                        label,
                        date_label,
                    )


                    widget = self._date_widgets.get(cache_key)

                    if widget is None:
                        widget = DateSectionWidget(
                            date_label=date_label,
                            text_lines=lines,
                            parent=self.preview_container,
                        )
                        self._date_widgets[cache_key] = widget

                    # 🔑 CRITICAL FIX — ALWAYS re-parent + re-add
                    widget.setParent(self.preview_container)
                    report_layout.addWidget(widget)
                    widget.setVisible(True)

        # 🔑 ANCHOR CONTENT TO TOP — prevents jump on collapse
        self.preview_layout.addStretch(1)

    # =====================================================
    # SEND
    # =====================================================
    def send_to_letter(self):
            print("[EXTRACTOR] ✅ Send to letter clicked")

            if not self._latest_panel_data:
                print("[EXTRACTOR] ❌ No panel data to send")
                return

            print(
                "[EXTRACTOR] 📦 Categories:",
                list(self._latest_panel_data.get("categories", {}).keys())
            )

            self.data_extracted.emit(self._latest_panel_data)
            print("[EXTRACTOR] 🚀 data_extracted signal emitted")

            self.close()

    # =====================================================
    # move and drag
    # =====================================================
    def eventFilter(self, obj, event):
        return super().eventFilter(obj, event)

    def _drag_mouse_press(self, event):
        if event.button() == Qt.LeftButton:
            self._drag_offset = (
                event.globalPosition().toPoint()
                - self.frameGeometry().topLeft()
            )
            event.accept()

    def _drag_mouse_move(self, event):
        if self._drag_offset and event.buttons() & Qt.LeftButton:
            self.move(
                event.globalPosition().toPoint()
                - self._drag_offset
            )
            event.accept()

    def _drag_mouse_release(self, event):
        self._drag_offset = None
        event.accept()




    

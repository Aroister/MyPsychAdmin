from __future__ import annotations

import os
import re
from collections import defaultdict

from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QComboBox, QFileDialog
)

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
    "MENTAL STATE",
    "SUMMARY",
    "PLAN",
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
    "substance misuse": "DRUGS&ALC",
    "drug history": "DRUGS&ALC",
    "alcohol history": "DRUGS&ALC",

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
            (["any other relevant information that the tribunal should know"], "Summary"),
            (["recommendations to the tribunal"], "Summary"),
        ],
    }

    # Questions we should ignore (checkbox / admin / not useful). Taken from your tribunal breakdown.
    IGNORE_NUMBERS = {
        "medical": {10, 13, 16, 19, 20, 11},
        "nursing": {5, 8, 15},
        "social": {13, 14, 15, 19, 21, 22, 24, 25},
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
    os.path.join(
        os.path.dirname(__file__),
        "Letter_headings_search_v2.txt"
    )
)
print(
    f"[CLASSIFIER] Loaded {len(LETTER_SEARCH_TERMS)} structural search terms"
)
# =====================================================
# LOAD CONTENT SEARCH TERMS (v1 — LINE BY LINE)
# =====================================================
LETTER_CONTENT_TERMS = load_letter_search_terms(
    os.path.join(
        os.path.dirname(__file__),
        "Letter headings search.txt"
    )
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
    DEBUG_CONTENT = True

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

        # 🚫 Nothing resolved — skip safely
        if not final_cat:
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

    return panel_data


def extract_by_scored_classifier(notes, search_terms):
    """
    Fallback extractor for NON-UK-Govt reports.
    Uses scored keyword matching to assign paragraphs
    to letter categories.
    """
    DEBUG_CLASSIFIER = True

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
           # In fallback mode, we DO NOT invent categories
            # Unclassified paragraphs are dropped
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

        # ---------------- DOCUMENT TYPE ----------------
        doc_row = QHBoxLayout()
        doc_label = QLabel("Document type:")
        self.document_type_dropdown = QComboBox()
        self.document_type_dropdown.addItems([
                "Reports",
                "Letters",
                "Notes",
        ])

        self.document_type_dropdown.currentTextChanged.connect(
            self._on_document_type_changed
        )


        doc_row.addWidget(doc_label)
        doc_row.addWidget(self.document_type_dropdown, 1)
        layout.addLayout(doc_row)

        # ---------------- AUTO-DETECT STATUS ----------------
        self.auto_detect_label = QLabel("")
        self.auto_detect_label.setWordWrap(True)
        self.auto_detect_label.setStyleSheet(
            "font-size: 11px; font-weight: 500; color: #065f46;"
        )
        layout.addWidget(self.auto_detect_label)


        # ---------------- PRIMARY BUTTON ----------------
        self.extract_btn = QPushButton("Upload document and extract")
        self.extract_btn.setObjectName("primaryAction")
        self.extract_btn.clicked.connect(self.upload_and_extract)
        layout.addWidget(self.extract_btn)

        layout.addSpacing(12)

        # ---------------- CATEGORY FILTER ----------------
        cat_row = QHBoxLayout()
        cat_label = QLabel("History category:")
        self.category_dropdown = QComboBox()
        self.category_dropdown.addItems([
            "All Categories",
            "Forensic History",
            "Past Psychiatric History",
            "Background History",
            "Circumstances of Admission",
            "Diagnosis",
            "Medication History",
            "Function – Relationships",
            "History of Presenting Complaint",
            "Risk",
            "Plan",
            "Impression",
            "Summary",
        ])
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

        self.preview_scroll.setWidget(self.preview_container)

        layout.addWidget(self.preview_scroll, 1)

        # Cache for DateSectionWidget reuse
        self._date_widgets = {}



        # ---------------- SEND ----------------
        # ---------------- ACTIONS ----------------
        action_row = QHBoxLayout()

        self.clear_button = QPushButton("Clear extraction")
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
        print("EXTRACTOR isWindow:", self.isWindow())
        self.show()
        self.raise_()
        self.activateWindow()
    def clear_extraction(self):
        """
        Clear all extracted data and reset the extractor state.
        """
        self.notes = []
        self._latest_panel_data = None

        # Clear widget preview safely
        for i in reversed(range(self.preview_layout.count())):
            w = self.preview_layout.itemAt(i).widget()
            if w:
                w.setParent(None)

        self._collapsed_dates.clear()
        self._date_widgets.clear()

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

        new_categories = {}

        for key, cat in panel_data.get("categories", {}).items():
            if not isinstance(cat, dict):
                continue

            if isinstance(key, int):
                name = id_to_name.get(key)
            else:
                name = key

            if not name:
                continue

            new_categories.setdefault(name, {
                "name": name,
                "items": [],
            })

            new_categories[name]["items"].extend(
                cat.get("items", [])
            )


        panel_data["categories"] = new_categories

    def _normalise_note_source(self, note):
        src = note.get("source")

        if not isinstance(src, dict):
            note["source"] = {}

        note["source"].setdefault("system", "Unknown")
        note["source"].setdefault("report", "Unknown")
        note["source"].setdefault("file", "Unknown")


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
    def upload_and_extract(self):
        ui_text = self.document_type_dropdown.currentText()
        dtype = DOC_TYPE_MAP.get(ui_text, "letter / free text")

        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Select document",
            "",
            "Documents (*.pdf *.docx *.xlsx *.xls *.txt)"
        )

        if not file_path:
            return

        files = [file_path]

        if not files:
            return

        self.notes = []
        self.notes = self._load_documents(files, dtype)

        # --------------------------------------------------
        # STEP 4 — AUTO-DETECT REPORT TYPE FROM NOTES
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
        # --------------------------------------------------
        # CONFIDENCE GATE — INVALIDATE LOW-CONFIDENCE DETECT
        # --------------------------------------------------
        if (
                auto_report_type
                and auto_report_confidence is not None
                and auto_report_confidence < AUTO_DETECT_CONFIDENCE_MIN
        ):
                print(
                        f"[AUTO-DETECT] ⚠️ Low confidence "
                        f"({auto_report_confidence}) — ignoring detection"
                )
                auto_report_type = None

        else:
            print(f"[AUTO-DETECT] ⚠️ Ambiguous report types: {detected_types}")
        # --------------------------------------------------
        # Load fallback classifier terms (once)
        # --------------------------------------------------
        if not hasattr(self, "_letter_search_terms"):
            self._letter_search_terms = load_letter_search_terms(
                os.path.join(
                    os.path.dirname(__file__),
                    "Letter_headings_search_v2.txt"
                )
            )

        # --------------------------------------------------
        # STEP 5A — CACHE AUTO-DETECTION (UI + OVERRIDE)
        # --------------------------------------------------
        self._auto_report_type = auto_report_type
        self._auto_report_confidence = auto_report_confidence
        # ---------------------------------------------
        # 🔑 FINALISE REPORT PROVENANCE LABEL (AFTER AUTO-DETECT)
        # ---------------------------------------------
        if dtype == "reports" and auto_report_type:
            report_prefix_map = {
                "medical": "Medical report",
                "nursing": "Nursing report",
                "social": "Social work report",
            }

            prefix = report_prefix_map.get(auto_report_type)

            if prefix:
                prefix_lower = prefix.lower()

                for n in self.notes:
                    meta = n.get("source_meta")
                    if not isinstance(meta, dict):
                        continue

                    file = meta.get("file")
                    if not file:
                        continue

                    filename = os.path.basename(file)

                    # 🔑 Avoid repeating report type already in filename
                    if prefix_lower in filename.lower():
                        meta["source_label"] = filename
                    else:
                        meta["source_label"] = f"{prefix} – {filename}"
        # --------------------------------------------------
        # STEP 5.3 — UPDATE AUTO-DETECT LABEL
        # --------------------------------------------------
        if self._auto_report_type and self._auto_report_confidence is not None:
            self.auto_detect_label.setText(
                f"Detected: {self._auto_report_type.title()} report "
                f"(confidence {self._auto_report_confidence})"
            )
        else:
            self.auto_detect_label.setText("")

        # --------------------------------------------------
        # STEP 5.2 — AUTO-SYNC UI (NO OVERRIDE)
        # --------------------------------------------------
        if self._auto_report_type:
            ui_map = {
                "medical": "Reports",
                "nursing": "Reports",
                "social": "Reports",
            }

            ui_label = ui_map.get(self._auto_report_type)

            if ui_label:
                try:
                    self.document_type_dropdown.blockSignals(True)
                    self.document_type_dropdown.setCurrentText(ui_label)
                finally:
                    self.document_type_dropdown.blockSignals(False)

        # =================================================
        # NOTES → STRUCTURED HISTORY (AUTODETECT)
        # =================================================
        if dtype == "notes":
            pipeline = "autodetect"

            def _normalise_system(n):
                """
                Return the TRUE originating clinical notes system.
                This value drives timeline + clerking logic.
                NEVER guess CareNotes.
                """

                # 1️⃣ Explicit system from source_meta (authoritative)
                meta = n.get("source_meta")
                if isinstance(meta, dict):
                    system = (meta.get("system") or "").strip().lower()
                    if system in {"rio", "carenotes", "epjs"}:
                        return system

                # 2️⃣ Explicit string source (legacy / cleaned notes)
                src = n.get("source")
                if isinstance(src, str):
                    src = src.strip().lower()
                    if src in {"rio", "carenotes", "epjs"}:
                        return src

                # 3️⃣ Filename heuristics (directional fallback only)
                file = ""
                if isinstance(n.get("source"), dict):
                    file = (n["source"].get("file") or "").lower()
                elif isinstance(n.get("source_meta"), dict):
                    file = (n["source_meta"].get("file") or "").lower()

                if "epjs" in file:
                    return "epjs"
                if "care" in file or "cnts" in file:
                    return "carenotes"
                if "rio" in file:
                    return "rio"

                # 4️⃣ FINAL FAILSAFE — DEFAULT TO RIO (NEVER CareNotes)
                return "carenotes"

            
            prepared = []

            for n in self.notes:
                prepared.append({
                    "date": n.get("date"),
                    "type": (n.get("type") or "").lower(),
                    "originator": n.get("originator"),
                    "content": n.get("content") or n.get("text", ""),
                    "text": n.get("text") or n.get("content", ""),

                    # 🔒 PIPELINE AUTHORITY — STRING ONLY
                    "source": self.pipeline,

                    # 🧠 UI / AUDIT ONLY
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


            bad = [n for n in prepared if not isinstance(n.get("source"), str)]
            if bad:
                raise RuntimeError(
                    f"[HIST] ❌ Invalid note source types: "
                    f"{set(type(n['source']) for n in bad)}"
                )

                
            episodes = build_timeline(prepared)

            history = extract_patient_history(
                prepared,
                episodes=episodes,
                pipeline=self.pipeline,
                debug=True,
            )

            self._latest_panel_data = convert_to_panel_format(history)
            self._normalise_note_categories(self._latest_panel_data)
            self._normalise_panel_sources(self._latest_panel_data)
            self._apply_notes_provenance(
                self._latest_panel_data,
                report_label="Clinical Notes",
            )
            # --------------------------------------------------
            # 🔑 PROPAGATE NOTES BACK TO LETTER WRITER
            # --------------------------------------------------
            letter = self.parent()
            while letter and not hasattr(letter, "set_notes"):
                letter = letter.parent()

            if letter and hasattr(letter, "set_notes"):
                letter.set_notes(self.notes)
                print(
                    f"[EXTRACTOR → LETTER] ✅ Propagated {len(self.notes)} notes "
                    f"to LetterWriterPage id={id(letter)}"
                )
            else:
                print("[EXTRACTOR → LETTER] ⚠️ No LetterWriterPage found to receive notes")


        # =================================================
        # REPORTS (heading-based, per type)
        # =================================================
        elif (
                auto_report_type in {"medical", "nursing", "social"}
                and auto_report_confidence is not None
                and auto_report_confidence >= AUTO_DETECT_CONFIDENCE_MIN
        ):
                # 🔒 STEP 1 — AUTHORITATIVE RC / TRIBUNAL NUMBERED EXTRACTOR
                if auto_report_type == "medical":
                        print("[EXTRACTOR] 🔒 Using RC numbered tribunal extractor")
                        self._latest_panel_data = self.extract_from_rc_report(
                                self.notes
                        )

                # 🔁 STEP 2 — HEADING-BASED TRIBUNAL FALLBACK (NON-RC)
                else:
                        print("[EXTRACTOR] Using heading-based tribunal extractor")
                        self._latest_panel_data = extract_by_ranges(
                                self.notes,
                                auto_report_type
                        )

                
        # 🔒 HARD GUARD — tribunal / medical extraction is authoritative
        if (
            auto_report_type in {"medical", "nursing", "social"}
            and auto_report_confidence is not None
            and auto_report_confidence >= AUTO_DETECT_CONFIDENCE_MIN
        ):
            self._normalise_panel_sources(self._latest_panel_data)
            goto_merge = True
        else:
            goto_merge = False

        # =================================================
        # FALLBACK REPORT CLASSIFIER (NON-UK GOVT REPORTS)
        # =================================================
        if dtype == "reports" and not goto_merge:
            print("[REPORT] 🧠 Using content-first block extractor")

            self._latest_panel_data = extract_by_content_blocks(
                self.notes,
                LETTER_CONTENT_TERMS
            )

        # --------------------------------------------------
        # SAFETY FALLBACK — NEVER RETURN EMPTY PANEL
        # --------------------------------------------------
        if (
            self._latest_panel_data
            and not self._latest_panel_data.get("categories")
        ):
            print("[REPORT FALLBACK] ⚠️ Empty result — using Summary fallback")

            self._latest_panel_data = extract_from_free_text(self.notes)

        elif dtype == "reports":

                # 🚨 CONTENT WINS GUARDRAIL
                if self._latest_panel_data and self._latest_panel_data.get("categories"):
                        print("[ROUTER] ✅ Content blocks succeeded — classifier blocked")

                # ---------------------------------------------
                # UK GOVT / TRIBUNAL REPORT (authoritative)
                # ---------------------------------------------
                elif (
                        auto_report_type in {"medical", "nursing", "social"}
                        and auto_report_confidence is not None
                        and auto_report_confidence >= AUTO_DETECT_CONFIDENCE_MIN
                ):
                        self._latest_panel_data = extract_by_ranges(
                                self.notes,
                                auto_report_type
                        )

                # ---------------------------------------------
                # TRUE FALLBACK — scored classifier
                # ---------------------------------------------
                else:
                        print(
                                "[REPORT FALLBACK] 🧠 Using scored classifier "
                                f"(detected={auto_report_type}, confidence={auto_report_confidence})"
                        )

                        self._latest_panel_data = extract_by_scored_classifier(
                                self.notes,
                                self._letter_search_terms
                        )

                self._normalise_panel_sources(self._latest_panel_data)


        elif dtype == "medical report":
            self._latest_panel_data = extract_by_ranges(
                self.notes, "medical"
            )

        elif dtype == "nursing report":
            self._latest_panel_data = extract_by_ranges(
                self.notes, "nursing"
            )

        elif dtype == "social work report":
            self._latest_panel_data = extract_by_ranges(
                self.notes, "social"
            )

        # =================================================
        # FREE TEXT FALLBACK
        # =================================================
        else:
            self._latest_panel_data = extract_from_free_text(self.notes)

        # ---------- PATCH 11 : STEP 2 ----------
        previous_keys = set()

        if self._latest_panel_data:
            for cat in self._latest_panel_data.get("categories", {}).values():
                for item in cat.get("items", []):
                    norm = " ".join((item.get("text") or "").split()).lower()
                    if norm:
                        previous_keys.add(norm)

        # =================================================
        # STORE PANEL BY DOCUMENT TYPE (SEQUENTIAL LOAD)
        # + DATA-LEVEL DEDUPE
        # =================================================
        existing = self._panel_data_by_dtype.get(dtype)

        if existing:
            merged = self._merge_panels(
                [existing, self._latest_panel_data]
            )
        else:
            merged = self._latest_panel_data

        # 🔒 DATA-LEVEL DEDUPE (prevents double export)
        merged = self._dedupe_panel_data(merged)

        self._panel_data_by_dtype[dtype] = merged



        # =================================================
        # REBUILD COMBINED PANEL (DERIVED VIEW)
        # =================================================
        self._latest_panel_data = self._merge_panels(
            list(self._panel_data_by_dtype.values())
        )

        # Reset UI-only state
        self._collapsed_blocks = set()
        self._new_item_keys = set()
        self._last_rendered_block_key = None

        self._refresh_preview_from_cache()

        if self._latest_panel_data:
            print(
                "[PROVENANCE CHECK]",
                {
                    (item["source"].get("report"), item["source"].get("file"))
                    for cat in self._latest_panel_data["categories"].values()
                    for item in cat["items"]
                }
            )

            # --------------------------------------------------
            # 🔁 IF EXTRACTOR OPENED EMPTY, REFRESH AFTER NOTES
            # --------------------------------------------------
            if self.isVisible():
                print(
                    f"[EXTRACTOR] 🔁 Refreshed extractor notes "
                    f"({len(self.notes)}) after late injection"
                )

            # ---------------------------------------------
            # STEP 4 — AUTO-SWITCH UI TO LOADED DOCUMENT TYPE
            # ---------------------------------------------
            if dtype in DOC_TYPE_MAP.values():
                try:
                    self.document_type_dropdown.blockSignals(True)
                    self.document_type_dropdown.setCurrentText(ui_text)
                finally:
                    self.document_type_dropdown.blockSignals(False)

                print(f"[MEMORY] 🎯 Switched UI to {dtype}")

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
        Returns MyPsy panel-format data.
        """

        import re
        from collections import defaultdict

        # =====================================================
        # RC QUESTION → CATEGORY MAP (AUTHORITATIVE)
        # =====================================================
        QUESTION_CATEGORY_MAP = {
            5: "Forensic History",

            6: "Past Psychiatric History",
            7: "Past Psychiatric History",

            8: "Circumstances of Admission",

            9: "Diagnosis",

            12: "Medication History",

            14: "History of Presenting Complaint",
            15: "History of Presenting Complaint",

            17: "Risk",
            18: "Risk",
            21: "Risk",
            22: "Risk",

            23: "Summary",
        }

        # Questions that END a section and must NOT be included
        HARD_STOP_QUESTIONS = {10, 11, 13, 16, 19, 20}

        QUESTION_HEADER_RE = re.compile(r"^\s*(\d+)[\.\)]\s*(.*)")
        CHECKBOX_RE = re.compile(r"^\s*(Yes|No|\[.*?\]|N/A)\s*$", re.IGNORECASE)
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
                current_text = [m.group(2)]
            else:
                if current_q is not None:
                    current_text.append(line)

        if current_q is not None:
            questions.append(
                (current_q, "\n".join(current_text).strip())
            )

        # =====================================================
        # EXTRACT BY QUESTION NUMBER
        # =====================================================
        category_items = defaultdict(list)

        for q_num, raw_text in questions:
            if q_num in HARD_STOP_QUESTIONS:
                continue

            category = QUESTION_CATEGORY_MAP.get(q_num)
            if not category:
                continue

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

        for cat in self._latest_panel_data.get("categories", {}).values():
            category_name = cat.get("name")
            items = self._dedupe_items(cat.get("items", []))

            if not items:
                continue

            if selected != "All Categories":
                if self._normalise_category_key(category_name) != self._normalise_category_key(selected):
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

                prov_key = (category_name, label)

                header_btn = QPushButton(
                    f"▾ From {label} ({len(block_items)} items)",
                    self.preview_container
                )
                header_btn.setCheckable(True)
                header_btn.setChecked(False)
                def _set_header_text(expanded: bool):
                    arrow = "▾" if expanded else "▸"
                    header_btn.setText(
                        f"{arrow} From {label} ({len(block_items)} items)"
                    )
                self._collapsed_blocks.add(prov_key)
                header_btn.setStyleSheet("""
                    QPushButton {
                        border: none;
                        background: transparent;
                        text-align: left;
                        font-size: 13px;
                        font-weight: 600;
                        padding: 6px 0;
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
                report_container.setVisible(False)
                def _toggle_report(
                    checked,
                    _prov_key=prov_key,
                    _container=report_container,
                    _btn=header_btn,
                    _label=label,
                    _count=len(block_items),
                ):
                    collapsed = not checked

                    if collapsed:
                        self._collapsed_blocks.add(_prov_key)
                        _container.setVisible(False)
                        _btn.setText(
                            f"▸▸  From {_label} ({_count} items)"
                        )
                    else:
                        self._collapsed_blocks.discard(_prov_key)
                        _container.setVisible(True)
                        _btn.setText(
                            f"▾▾  From {_label} ({_count} items)"
                        )

                header_btn.toggled.connect(_toggle_report)

                by_date = {}
                undated = []


                for item in block_items:
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
                        selected,          # 👈 CATEGORY FILTER CONTEXT
                        category_name,
                        source.get("label", "Imported document"),
                        source.get("file", "Unknown file"),
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




    

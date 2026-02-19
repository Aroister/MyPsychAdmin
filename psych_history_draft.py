# ============================================================
# Psychiatric History — Draft Extractor (PSYCH-ONLY, SAFE)
# ============================================================

from __future__ import annotations
import re
from datetime import timedelta

# ------------------------------------------------------------
# Function to extract psychiatric history from past notes
# ------------------------------------------------------------
def extract_past_psych_from_notes(notes: list[dict]) -> str:
    """
    Extracts psychiatric history from notes
    that predate the most recent admission.
    """
    if not notes:
        return ""

    # Sort by date
    notes = sorted(
        [n for n in notes if n.get("date")],
        key=lambda n: n["date"]
    )

    # Heuristic: last 30–45 days = current episode
    cutoff = notes[-1]["date"] - timedelta(days=45)

    historical_notes = [
        n for n in notes
        if n["date"] < cutoff
    ]

    text = "\n".join(n.get("text", "") for n in historical_notes)
    return extract_psych_history_from_text(text)

# ------------------------------------------------------------
# Your existing code continues here...

# ------------------------------------------------------------
# HARD EXCLUSION — physical / medical noise
# ------------------------------------------------------------
PHYSICAL_EXCLUSIONS = [
    "hypertension", "diabetes", "asthma", "copd", "ckd",
    "heart", "cardiac", "stroke", "tia",
    "epilepsy", "seizure",
    "infection", "uti", "pneumonia",
    "surgery", "fracture", "injury",
    "cancer", "tumour", "chemotherapy",
    "renal", "hepatic", "liver",
    "thyroid", "endocrine",
    "blood pressure", "bp ",
    "cholesterol",
    "ecg", "echo",
    "ct ", "mri ",
]


# ------------------------------------------------------------
# PSYCHIATRIC SIGNALS
# ------------------------------------------------------------
PSYCH_CORE = [
    "psychiatric",
    "mental health",
    "psychosis",
    "psychotic",
    "hallucination",
    "delusion",
    "mania",
    "manic",
    "hypomania",
    "bipolar",
    "depression",
    "depressive",
    "anxiety",
    "ptsd",
    "post traumatic",
    "personality disorder",
    "emotionally unstable",
    "eupd",
    "adhd",
    "autism",
    "asd",
]


PSYCH_EVENTS = [
    "admission",
    "admitted",
    "inpatient",
    "section",
    "sectioned",
    "detained",
    "mental health act",
    "mha",
    "self harm",
    "self-harm",
    "overdose",
    "suicide",
    "suicidal",
    "attempt",
    "relapse",
]


PSYCH_TREATMENTS = [
    "antidepressant",
    "antipsychotic",
    "mood stabiliser",
    "lithium",
    "valproate",
    "olanzapine",
    "risperidone",
    "quetiapine",
    "aripiprazole",
    "clozapine",
    "ssri",
    "snri",
    "cbt",
    "psychological therapy",
    "psychotherapy",
    "counselling",
]


# ============================================================
# INTERNAL FILTER
# ============================================================
def _is_psychiatric_line(line: str) -> bool:
    l = line.lower()

    if any(x in l for x in PHYSICAL_EXCLUSIONS):
        return False

    return (
        any(k in l for k in PSYCH_CORE)
        or any(k in l for k in PSYCH_EVENTS)
        or any(k in l for k in PSYCH_TREATMENTS)
    )


# ============================================================
# PUBLIC API — RAW EXTRACTION
# ============================================================
def extract_psych_history_from_text(text: str) -> str:
    """
    Extract psychiatric history ONLY.
    Physical health aggressively excluded.
    """
    if not text or not text.strip():
        return ""

    kept: list[str] = []

    for line in text.splitlines():
        line = line.strip()
        if len(line) < 6:
            continue

        if _is_psychiatric_line(line):
            kept.append(line)

    # Deduplicate (preserve order)
    seen = set()
    unique = []
    for l in kept:
        k = l.lower()
        if k not in seen:
            seen.add(k)
            unique.append(l)

    return "\n".join(unique[:14])  # hard cap


# ============================================================
# DRAFT GENERATOR (LETTER-SAFE)
# ============================================================
def generate_psych_history_draft(text: str) -> str:
    if not text or not text.strip():
        return ""

    t = text.lower()
    lines: list[str] = []

    DIAGNOSES = {
        "psychotic illness": ["psychosis", "psychotic", "hallucination", "delusion"],
        "depressive illness": ["depression", "depressive"],
        "bipolar affective disorder": ["bipolar", "mania", "manic", "hypomania"],
        "anxiety disorders": ["anxiety", "panic", "phobia"],
        "post-traumatic stress disorder": ["ptsd", "post traumatic"],
        "personality disorder": ["personality disorder", "eupd"],
        "neurodevelopmental disorder": ["adhd", "autism", "asd"],
    }

    found = [
        name for name, kws in DIAGNOSES.items()
        if any(k in t for k in kws)
    ]

    if found:
        lines.append(
            "There is a history of psychiatric illness, including "
            + ", ".join(found) + "."
        )

    if any(k in t for k in ["section", "detained", "psychiatric admission", "inpatient"]):
        lines.append("There have been previous psychiatric admissions.")

    if any(k in t for k in PSYCH_TREATMENTS):
        lines.append(
            "Previous psychiatric treatment has included pharmacological and psychological interventions."
        )

    if any(k in t for k in ["self-harm", "overdose", "suicide", "suicidal"]):
        lines.append(
            "There is a past history of risk behaviours, including self-harm or suicidal behaviour."
        )

    if not lines:
        return ""

    return (
        "_Draft (auto-generated from imported psychiatric records — please review and edit):_\n\n"
        + " ".join(lines)
    )

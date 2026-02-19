from __future__ import annotations


# ============================================================
#  PSYCHOSIS → LETTER WRITER TEXT ENGINE
# ============================================================
# • Phenomenology-based
# • No diagnostic labels
# • Severity + insight aware
# • Safe NHS-style phrasing
# ============================================================


# ------------------------------------------------------------
# Severity → language map
# ------------------------------------------------------------
SEVERITY_MAP = {
    1: "intermittent",
    2: "frequent",
    3: "persistent"
}


IMPACT_MAP = {
    1: "with minimal impact on functioning",
    2: "which are distressing",
    3: "which significantly impair functioning"
}


# ------------------------------------------------------------
# Insight → language map
# ------------------------------------------------------------
INSIGHT_MAP = {
    "Good": "with good insight",
    "Partial": "with partial insight",
    "Limited": "with limited insight",
    "Absent": "with absent insight"
}


# ------------------------------------------------------------
# Symptom label → readable stem
# ------------------------------------------------------------
LABEL_STEMS = {
    # Hallucinations
    "Auditory hallucinations": "auditory hallucinations",
    "Visual hallucinations": "visual hallucinations",
    "Tactile hallucinations": "tactile hallucinations",
    "Olfactory / gustatory hallucinations": "olfactory or gustatory hallucinations",

    # Delusions
    "Persecutory beliefs": "persecutory beliefs",
    "Referential ideas": "ideas of reference",
    "Grandiose beliefs": "grandiose beliefs",
    "Somatic beliefs": "somatic beliefs",
    "Religious / spiritual beliefs": "religious or spiritual beliefs",

    # Thought disorder
    "Disorganised speech": "disorganised speech",
    "Tangentiality": "tangential thought processes",
    "Flight of ideas": "flight of ideas",
    "Thought blocking": "thought blocking",
    "Neologisms": "neologisms",

    # Behaviour
    "Marked withdrawal": "marked social withdrawal",
    "Poor self-care": "poor self-care",
    "Agitation": "psychomotor agitation",
    "Bizarre behaviour": "bizarre behaviour"
}


# ============================================================
#  CORE GENERATOR
# ============================================================

def generate_psychosis_text(psychosis_payload: dict) -> str:
    """
    Returns letter-ready psychosis section text.

    psychosis_payload = {
        "symptoms": {
            label: {"severity": int, "details": str}
        },
        "insight": "Good|Partial|Limited|Absent"
    }
    """

    if not psychosis_payload:
        return ""

    symptoms = psychosis_payload.get("symptoms", {})
    insight = psychosis_payload.get("insight", "Partial")

    sentences = []

    for label, entry in symptoms.items():
        severity = int(entry.get("severity", 0))
        details = (entry.get("details") or "").strip()

        if severity <= 0:
            continue

        stem = LABEL_STEMS.get(label)
        if not stem:
            continue

        freq = SEVERITY_MAP.get(severity, "frequent")
        impact = IMPACT_MAP.get(severity, "")
        insight_phrase = INSIGHT_MAP.get(insight, "with partial insight")

        # Core sentence
        sentence = (
            f"The patient describes {freq} {stem} "
            f"{impact}, {insight_phrase}."
        )

        # Optional elaboration
        if details:
            sentence += f" These include {details}."

        sentences.append(sentence)

    if not sentences:
        return ""

    # --------------------------------------------------------
    # Final assembly
    # --------------------------------------------------------
    if len(sentences) == 1:
        body = sentences[0]
    else:
        body = " ".join(sentences)

    return f"Psychotic symptoms:\n{body}"


# ============================================================
#  SHORT VERSION (optional use)
# ============================================================

def generate_psychosis_summary(psychosis_payload: dict) -> str:
    """
    Short summary for timeline / snapshot views.
    """
    symptoms = psychosis_payload.get("symptoms", {})
    insight = psychosis_payload.get("insight", "Partial")

    labels = [
        LABEL_STEMS.get(label)
        for label, entry in symptoms.items()
        if int(entry.get("severity", 0)) >= 2
    ]

    labels = [l for l in labels if l]

    if not labels:
        return ""

    joined = ", ".join(labels)
    insight_phrase = INSIGHT_MAP.get(insight, "with partial insight")

    return f"Psychotic features including {joined}, {insight_phrase}."

# utils/report_detector.py

# Fingerprints for BLANK TEMPLATES that should be EXCLUDED from searches
# These must be VERY SPECIFIC placeholder/instruction text, NOT topic mentions
BLANK_TEMPLATE_FINGERPRINTS = [
    # Explicit placeholder text
    "insert date here",
    "insert name here",
    "[insert ",
    "[insert]",
    "[date]",
    "[name]",
    "[delete as appropriate]",
    "[tick as appropriate]",
    "delete as applicable",
    "tick as appropriate",
    "tick one",
    "please delete",
    "please tick",

    # Form instruction text
    "please complete all sections",
    "guidance notes for completion",
    "instructions for completion",
    "how to complete this form",
    "this form should be completed by",
    "complete this form before",

    # Explicit template markers
    "template for tribunal",
    "report template",
    "blank form",
    "proforma for",
    "pro forma for",

    # Leave form specific blank markers
    "leave application form template",
    "s17 leave request template",

]

# Form question headings that should be STRIPPED from extracted content
# These are prompts/questions in tribunal forms - not actual clinical content
FORM_HEADINGS_TO_STRIP = [
    # Tribunal report question headings
    "give reasons for any previous admission or recall to hospital",
    "give details of the original offence or alleged offence",
    "give details of any other relevant forensic history",
    "describe the patient's response to treatment",
    "describe the nature of the mental disorder",
    "is the patient now suffering from a mental disorder",
    "what treatment is being provided",
    "what is the current medication",
    "describe the risk the patient poses",
    "give details of any incidents",
    "give details of the proposed care plan",
    "what arrangements are being made",
    "describe the patient's attitude to",
    "what is the patient's view",
    "give details of leave arrangements",
    "describe the current level of",
    "what is the prognosis",
    "circumstances leading up to",
    "past psychiatric history",
    "relevant family history",
    "relevant personal history",
    "relevant forensic history",
    "relevant social history",
    "relevant medical history",

    # ASR form headings
    "progress since last review",
    "current mental state",
    "current risk assessment",
    "current care plan",
    "future plans",

    # Leave form headings
    "purpose of leave",
    "proposed destination",
    "proposed duration",
    "escort arrangements",
    "risk management",

    # Section headings with colons
    "mental health act status:",
    "legal status:",
    "index offence:",
    "diagnosis:",
    "current presentation:",
    "risk factors:",
    "protective factors:",
]


def strip_form_headings(text: str) -> str:
    """Remove form question headings from extracted text.

    These headings are prompts in tribunal/ASR forms, not clinical content.
    """
    import re

    result = text
    text_l = text.lower()

    for heading in FORM_HEADINGS_TO_STRIP:
        # Find and remove the heading (case-insensitive)
        # Match the heading possibly followed by colon and whitespace
        pattern = re.compile(re.escape(heading) + r':?\s*', re.IGNORECASE)
        result = pattern.sub('', result)

    # Clean up multiple newlines/spaces left behind
    result = re.sub(r'\n\s*\n\s*\n', '\n\n', result)
    result = re.sub(r'  +', ' ', result)

    return result.strip()


def is_blank_template(text: str) -> bool:
    """Check if text appears to be a blank template rather than actual clinical data.

    Must be conservative - only exclude obvious blank templates, not filled reports.
    """
    text_l = text.lower()

    # Count how many STRONG template indicators are found
    template_matches = 0
    for phrase in BLANK_TEMPLATE_FINGERPRINTS:
        if phrase in text_l:
            template_matches += 1

    # Need 3+ strong indicators to be considered a blank template
    if template_matches >= 3:
        return True

    # Check for high ratio of placeholder brackets like [____] or [insert...]
    # This is very specific to blank forms
    bracket_placeholders = text_l.count("[insert") + text_l.count("[date]") + text_l.count("[name]")
    bracket_placeholders += text_l.count("[delete") + text_l.count("[tick")
    if bracket_placeholders >= 5:
        return True

    return False


REPORT_FINGERPRINTS = {
    "medical": {
        "strong": [
            "is the patient now suffering from a mental disorder",
            "medical treatment has been prescribed",
            "learning disability",
            "mental capacity act",
            "mental health tribunal",
            "responsible clinician",
        ],
        "medium": [
            "diagnosis",
            "past psychiatric history",
            "circumstances leading up to the patient's current admission",
            "detention",
        ],
    },
    "nursing": {
        "strong": [
            "level of observation",
            "engagement with nursing staff",
            "absent without leave",
            "secluded or restrained",
        ],
        "medium": [
            "nature of nursing care",
            "self-care",
            "ward",
        ],
    },
    "social": {
        "strong": [
            "housing or accommodation",
            "financial position",
            "section 117 after-care",
            "care pathway",
            "nearest relative",
            "mappa",
        ],
        "medium": [
            "home and family circumstances",
            "employment",
            "care plan",
        ],
    },
    "letter": {
        "strong": [
            "dear dr",
            "dear colleague",
            "yours sincerely",
            "yours faithfully",
            "thank you for referring",
            "thank you for your referral",
            "i reviewed",
            "i saw",
            "i assessed",
            "clinic appointment",
            "outpatient",
            "follow up appointment",
            "follow-up appointment",
        ],
        "medium": [
            "kind regards",
            "best wishes",
            "re:",
            "regarding:",
            "consultant psychiatrist",
            "community mental health",
            "cmht",
        ],
    },
}


def detect_report_type(text: str) -> dict:
    text_l = text.lower()
    scores = {}

    for report, signals in REPORT_FINGERPRINTS.items():
        score = 0

        for phrase in signals["strong"]:
            if phrase in text_l:
                score += 3

        for phrase in signals["medium"]:
            if phrase in text_l:
                score += 1

        scores[report] = score

    best = max(scores, key=scores.get)

    return {
        "report_type": best,
        "confidence": scores[best],
        "scores": scores,
    }

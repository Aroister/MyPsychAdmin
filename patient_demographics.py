"""
Central Patient Demographics Extraction Module

This module provides a single source of truth for extracting patient demographics
from clinical notes. All forms, letters, reports, and the narrative generator
should use these functions instead of duplicate extraction logic.

Usage:
    from patient_demographics import extract_demographics, calculate_age, get_pronouns

    demographics = extract_demographics(notes)
    # Returns: {name, dob, age, gender, nhs_number, ethnicity, mha_section, hospital, ward}

    pronouns = get_pronouns(gender)
    # Returns: {subject, object, possessive}
"""

from __future__ import annotations
import re
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple


# ============================================================
# CONSTANTS
# ============================================================

INVALID_NAME_PATTERNS = [
    r"(?i)responsible\s*clinician",
    r"(?i)approved\s*clinician",
    r"(?i)social\s*worker",
    r"(?i)report\s*of",
    r"(?i)^of\s+",
    r"(?i)tribunal",
    r"(?i)mental\s*health",
    r"(?i)first\s*tier",
    r"(?i)care\s*coordinator",
    r"(?i)nurse",
    r"(?i)doctor",
    r"(?i)consultant",
    r"(?i)psychiatrist",
    r"(?i)psychologist",
]

# Words that should NEVER appear in a patient name
INVALID_NAME_WORDS = {
    'participation', 'action', 'other', 'regarding', 'garding',
    'no', 'not', 'none', 'nil', 'unknown', 'patient', 'client',
    'assessment', 'review', 'report', 'notes', 'entry', 'entries',
    'required', 'needed', 'completed', 'pending', 'outcome',
    'contact', 'follow', 'discharge', 'admission', 'transfer',
    'medication', 'treatment', 'therapy', 'intervention', 'session', 'sessions',
    'appointment', 'meeting', 'tribunal', 'hearing',
    'progress', 'update', 'summary', 'section', 'status',
    'clinical', 'medical', 'nursing', 'psychology', 'psychiatry',
    'date', 'time', 'day', 'night', 'shift', 'today', 'yesterday',
    'morning', 'afternoon', 'evening', 'weekly', 'daily', 'monthly',
    # Common false positives from note templates
    'group', 'activities', 'activity',
    'leave', 'escorted', 'unescorted', 'ground', 'community',
    'risk', 'level', 'observation', 'observations', 'obs',
    'to', 'from', 'for', 'with', 'and', 'the', 'a', 'an', 'of', 'in', 'on', 'at', 'by',
}

MONTH_MAP = {
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
    'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
    'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9,
    'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12
}


# ============================================================
# MAIN EXTRACTION FUNCTION
# ============================================================

def extract_demographics(notes: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Extract all patient demographics from notes.

    Args:
        notes: List of note dictionaries with 'text' or 'content' fields

    Returns:
        Dictionary with keys: name, dob, age, gender, nhs_number, ethnicity,
                             mha_section, hospital, ward
    """
    demographics = {
        "name": None,
        "dob": None,
        "age": None,
        "gender": None,
        "nhs_number": None,
        "ethnicity": None,
        "mha_section": None,
        "hospital": None,
        "ward": None,
    }

    if not notes:
        return demographics

    # Get text from different sources
    top_notes_text = _get_top_notes_text(notes, limit=20)
    all_notes_text = _get_all_notes_text(notes)

    # Extract each field
    demographics["name"] = extract_name(notes, top_notes_text)
    demographics["dob"] = extract_dob(top_notes_text)
    demographics["gender"] = extract_gender(top_notes_text, all_notes_text)
    demographics["nhs_number"] = extract_nhs_number(top_notes_text)
    demographics["ethnicity"] = extract_ethnicity(top_notes_text)
    demographics["mha_section"] = extract_mha_section(top_notes_text)
    demographics["hospital"] = extract_hospital(top_notes_text)
    demographics["ward"] = extract_ward(top_notes_text)

    # Calculate age from DOB if not explicitly found
    if demographics["dob"]:
        demographics["age"] = calculate_age(demographics["dob"])
    else:
        demographics["age"] = extract_age_explicit(top_notes_text)

    return demographics


# ============================================================
# INDIVIDUAL EXTRACTION FUNCTIONS
# ============================================================

def extract_name(notes: List[Dict], top_notes_text: str = None) -> Optional[str]:
    """
    Extract patient name from notes.

    Searches for patterns like:
    - "PATIENT NAME: John Smith"
    - "Name: John Smith"
    - "Patient's name: John Smith"
    """
    if top_notes_text is None:
        top_notes_text = _get_top_notes_text(notes, limit=20)

    name_candidates = []

    for line in top_notes_text.split('\n'):
        line = line.strip()
        if not line:
            continue

        # Pattern 1: "PATIENT NAME: Firstname Lastname"
        match = re.match(
            r"(?:PATIENT\s*NAME|CLIENT\s*NAME|NAME)\s*[:\-]?\s*"
            r"([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z][A-Za-z\-\']+)?)\s*$",
            line, re.IGNORECASE
        )
        if match:
            candidate = match.group(1).strip()
            if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH|ADDRESS)", candidate, re.IGNORECASE):
                name_candidates.append(candidate)
                continue

        # Pattern 2: "Name:" or "Patient:"
        match = re.match(
            r"(?:Name|Patient)\s*[:\-]\s*"
            r"([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z\-\']+)?)",
            line, re.IGNORECASE
        )
        if match:
            candidate = match.group(1).strip()
            if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH)", candidate, re.IGNORECASE):
                name_candidates.append(candidate)

    # Validate candidates
    for candidate in name_candidates:
        if _is_valid_name(candidate):
            return candidate

    # Try tribunal-style patterns if no name found
    tribunal_patterns = [
        r"(?:Patient'?s?\s*name|Full\s*name)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
        r"(?:Name\s*of\s*patient)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
        r"(?:RE|Re|PATIENT)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\' ]+)",
    ]
    for pattern in tribunal_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            candidate = match.group(1).strip()
            # Remove trailing labels
            candidate = re.sub(
                r"\s*(?:Date|DOB|NHS|Gender|Sex|Age|Birth|Address|Hospital|Ward|Section|MHA).*$",
                "", candidate, flags=re.IGNORECASE
            ).strip()
            if len(candidate.split()) >= 2 and _is_valid_name(candidate):
                return candidate

    return None


def extract_dob(top_notes_text: str) -> Optional[datetime]:
    """
    Extract date of birth from notes text.

    Handles formats:
    - Numeric: dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy
    - Text: "7 October 1979", "15 Jan 1985"
    """
    # Numeric date patterns
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
                    return datetime.strptime(dob_str, fmt)
                except ValueError:
                    continue

    # Text date patterns: "7 October 1979"
    text_patterns = [
        r"(?:DATE\s*OF\s*BIRTH|D\.?O\.?B\.?|DOB)\s*[:\-]?\s*(\d{1,2})\s+"
        r"(January|February|March|April|May|June|July|August|September|October|November|December|"
        r"Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})",
        r"(?:BORN)\s*[:\-]?\s*(\d{1,2})\s+"
        r"(January|February|March|April|May|June|July|August|September|October|November|December|"
        r"Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})",
    ]

    for pattern in text_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            day = int(match.group(1))
            month_str = match.group(2).lower()
            year = int(match.group(3))
            month = MONTH_MAP.get(month_str, 1)
            try:
                return datetime(year, month, day)
            except ValueError:
                pass

    return None


def calculate_age(dob: datetime) -> Optional[int]:
    """Calculate age from date of birth."""
    if not dob:
        return None

    if isinstance(dob, str):
        for fmt in ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y']:
            try:
                dob = datetime.strptime(dob, fmt)
                break
            except ValueError:
                continue
        else:
            return None

    if not hasattr(dob, 'year'):
        return None

    today = datetime.now()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    if 0 < age < 120:
        return age
    return None


def extract_age_explicit(top_notes_text: str) -> Optional[int]:
    """Extract explicitly stated age from notes."""
    age_patterns = [
        r"(?:AGE)\s*[:\-]?\s*(\d{1,3})\s*(?:years?|yrs?|y\.?o\.?)?\b",
        r"\b(\d{1,3})\s*(?:year|yr)\s*old\b",
        r"\b(\d{1,3})\s*y\.?o\.?\b",
        r"\baged?\s*(\d{1,3})\b",
    ]

    for pattern in age_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            age = int(match.group(1))
            if 0 < age < 120:
                return age

    return None


def extract_gender(top_notes_text: str, all_notes_text: str = None) -> Optional[str]:
    """
    Extract gender from notes.

    First tries explicit labels, then falls back to pronoun counting.
    """
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
                return "Male"
            elif g in ("FEMALE", "F"):
                return "Female"

    # Fallback: count pronouns
    if all_notes_text:
        all_lower = all_notes_text.lower()
        male_pronouns = len(re.findall(r"\bhe\b|\bhim\b|\bhis\b", all_lower))
        female_pronouns = len(re.findall(r"\bshe\b|\bher\b|\bhers\b", all_lower))

        # Need clear majority
        if male_pronouns > female_pronouns * 2 or male_pronouns > female_pronouns + 10:
            return "Male"
        elif female_pronouns > male_pronouns * 2 or female_pronouns > male_pronouns + 10:
            return "Female"

    return None


def extract_nhs_number(top_notes_text: str) -> Optional[str]:
    """Extract and format NHS number."""
    nhs_patterns = [
        r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{3}\s*\d{3}\s*\d{4})",
        r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{10})",
    ]

    for pattern in nhs_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            nhs = match.group(1).replace(" ", "")
            if len(nhs) == 10:
                return f"{nhs[:3]} {nhs[3:6]} {nhs[6:]}"
            return nhs

    return None


def extract_ethnicity(top_notes_text: str) -> Optional[str]:
    """
    Extract ethnicity from explicitly labeled fields only.

    Only extracts ethnicity when it appears in a clearly labeled context like:
    - "Ethnicity: White British"
    - "Ethnic group: Black African"
    - "Ethnic background: Asian British"

    Does NOT match ethnicity words appearing in general text to avoid false positives.
    """
    # Only match ethnicity when it follows a clear label
    ethnicity_patterns = [
        # Standard field labels with colon or dash
        r"(?:ETHNICITY|ETHNIC\s*(?:GROUP|ORIGIN|BACKGROUND|CATEGORY))\s*[:\-]\s*([A-Za-z][A-Za-z\s\-\/]+?)(?:\n|$|,|\t)",
        # NHS demographic form style
        r"(?:ETHNIC\s*CODE)\s*[:\-]\s*([A-Za-z][A-Za-z0-9\s\-\/]+?)(?:\n|$|,|\t)",
        # Structured data with ethnicity field
        r"^\s*(?:ETHNICITY|ETHNIC\s*GROUP)\s*[:\-]?\s*([A-Za-z][A-Za-z\s\-\/]+?)$",
    ]

    for pattern in ethnicity_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE | re.MULTILINE)
        if match:
            ethnicity = match.group(1).strip()
            # Validate it's not another field label
            if len(ethnicity) > 2 and not re.match(
                r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|NAME|WARD|HOSPITAL|ADDRESS|SECTION|NOT|UNKNOWN|N/?A)",
                ethnicity, re.IGNORECASE
            ):
                # Clean up common trailing words that aren't part of ethnicity
                ethnicity = re.sub(r"\s+(?:DATE|DOB|NHS|GENDER|SEX|WARD|HOSPITAL).*$", "", ethnicity, flags=re.IGNORECASE)
                return ethnicity.strip().title()

    return None


def extract_mha_section(top_notes_text: str) -> Optional[str]:
    """Extract Mental Health Act section."""
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
            if not section.lower().startswith("section"):
                section = f"Section {section}"
            return section

    return None


def extract_hospital(top_notes_text: str) -> Optional[str]:
    """Extract hospital name."""
    hospital_patterns = [
        r"(?:HOSPITAL|HOSP\.?)\s*[:\-]\s*([A-Za-z][A-Za-z\s\'\-]+?)(?:\n|Ward|,|$)",
        r"(?:DETAINED\s*AT|ADMITTED\s*TO|AT)\s+([A-Za-z][A-Za-z\s\'\-]+?(?:Hospital|Centre|Unit|Clinic))",
        r"([A-Za-z][A-Za-z\s\'\-]+?(?:Hospital|Centre|Unit|Clinic))\b",
    ]

    for pattern in hospital_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            hospital = match.group(1).strip()
            if len(hospital) > 3 and not re.match(
                r"(?:Name|Patient|Date|NHS|The|A|An|This)\b", hospital, re.IGNORECASE
            ):
                return hospital

    return None


def extract_ward(top_notes_text: str) -> Optional[str]:
    """Extract ward name."""
    ward_patterns = [
        r"(?:WARD)\s*[:\-]\s*([A-Za-z][A-Za-z0-9\s\'\-]+?)(?:\n|,|$|Hospital)",
        r"(?:ON|IN)\s+([A-Za-z][A-Za-z0-9\s\'\-]+?)\s*(?:WARD)\b",
        r"([A-Za-z][A-Za-z0-9\s\'\-]+?)\s*(?:WARD)\b",
    ]

    for pattern in ward_patterns:
        match = re.search(pattern, top_notes_text, re.IGNORECASE)
        if match:
            ward = match.group(1).strip()
            if len(ward) > 1 and not re.match(
                r"(?:Name|Patient|Date|NHS|The|A|An|This)\b", ward, re.IGNORECASE
            ):
                if not ward.lower().endswith("ward"):
                    ward = f"{ward} Ward"
                return ward

    return None


# ============================================================
# UTILITY FUNCTIONS
# ============================================================

def get_pronouns(gender: str) -> Dict[str, str]:
    """
    Get pronoun set based on gender.

    Returns:
        Dictionary with keys: subject, object, possessive
        e.g., {'subject': 'he', 'object': 'him', 'possessive': 'his'}
    """
    g = (gender or "").lower().strip()

    if g in ("male", "m"):
        return {'subject': 'he', 'object': 'him', 'possessive': 'his'}
    elif g in ("female", "f"):
        return {'subject': 'she', 'object': 'her', 'possessive': 'her'}
    else:
        return {'subject': 'they', 'object': 'them', 'possessive': 'their'}


def get_gender_descriptor(gender: str) -> str:
    """
    Get gender descriptor word.

    Returns: 'man', 'woman', or 'person'
    """
    g = (gender or "").lower().strip()

    if g in ("male", "m"):
        return "man"
    elif g in ("female", "f"):
        return "woman"
    else:
        return "person"


def format_name_parts(full_name: str) -> Tuple[str, str, str]:
    """
    Split full name into parts.

    Returns:
        Tuple of (first_name, middle_names, surname)
    """
    if not full_name:
        return ("", "", "")

    parts = full_name.strip().split()
    if len(parts) == 0:
        return ("", "", "")
    elif len(parts) == 1:
        return (parts[0], "", "")
    elif len(parts) == 2:
        return (parts[0], "", parts[1])
    else:
        return (parts[0], " ".join(parts[1:-1]), parts[-1])


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def _get_top_notes_text(notes: List[Dict], limit: int = 20) -> str:
    """Get combined text from first N notes."""
    text_parts = []
    for note in notes[:limit]:
        text = note.get("text") or note.get("content") or ""
        text_parts.append(text)
    return "\n".join(text_parts)


def _get_all_notes_text(notes: List[Dict]) -> str:
    """Get combined text from all notes."""
    text_parts = []
    for note in notes:
        text = note.get("text") or note.get("content") or ""
        text_parts.append(text)
    return "\n".join(text_parts)


def _is_valid_name(candidate: str) -> bool:
    """Check if a candidate string is a valid patient name."""
    # Check against regex patterns
    for pattern in INVALID_NAME_PATTERNS:
        if re.search(pattern, candidate):
            return False

    # Check individual words against invalid word list
    words = candidate.lower().split()
    for word in words:
        if word in INVALID_NAME_WORDS:
            return False

    # Name should have 2-4 words typically
    if len(words) < 2 or len(words) > 5:
        return False

    # Each word should be reasonable length (2-20 chars)
    for word in words:
        if len(word) < 2 or len(word) > 20:
            return False

    return True

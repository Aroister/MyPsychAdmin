from __future__ import annotations
from typing import Dict, Any
PersonalHistoryState = Dict[str, Any]
def empty_personal_history_state() -> PersonalHistoryState:
    return {
        "BIRTH": None,

        "MILESTONES": None,

        "FAMILY_HISTORY": None,

        "ABUSE": {
            "severity": None,
            "types": [],
        },

        "SCHOOLING": {
            "severity": None,
            "issues": [],
        },

        "QUALIFICATIONS": None,

        "WORK_HISTORY": {
            "pattern": None,
            "last_worked_years": None,
        },

        "SEXUAL_ORIENTATION": None,

        "RELATIONSHIPS": {
            "status": None,
            "duration_years": None,
        },

        "CHILDREN": {
            "count": None,
            "age_band": None,
            "composition": None,
        },
    }

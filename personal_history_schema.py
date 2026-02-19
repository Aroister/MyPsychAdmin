from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional, Literal, Dict


SelectionType = Literal[
    "single",
    "multi",
    "structured",
]


@dataclass
class DomainSchema:
    key: str
    label: str
    selection_type: SelectionType
    allow_none: bool = False
    exclusive_values: Optional[List[str]] = None


PERSONAL_HISTORY_DOMAINS: Dict[str, DomainSchema] = {

    "BIRTH": DomainSchema(
        key="BIRTH",
        label="Birth history",
        selection_type="single",
    ),

    "MILESTONES": DomainSchema(
        key="MILESTONES",
        label="Developmental milestones",
        selection_type="single",
    ),

    "FAMILY_HISTORY": DomainSchema(
        key="FAMILY_HISTORY",
        label="Family psychiatric history",
        selection_type="single",
    ),

    "ABUSE": DomainSchema(
        key="ABUSE",
        label="Childhood abuse",
        selection_type="structured",
        allow_none=True,
    ),

    "SCHOOLING": DomainSchema(
        key="SCHOOLING",
        label="Schooling",
        selection_type="structured",
    ),

    "QUALIFICATIONS": DomainSchema(
        key="QUALIFICATIONS",
        label="Educational qualifications",
        selection_type="single",
    ),

    "WORK_HISTORY": DomainSchema(
        key="WORK_HISTORY",
        label="Employment history",
        selection_type="structured",
    ),

    "SEXUAL_ORIENTATION": DomainSchema(
        key="SEXUAL_ORIENTATION",
        label="Sexual orientation",
        selection_type="single",
    ),

    "RELATIONSHIPS": DomainSchema(
        key="RELATIONSHIPS",
        label="Relationships",
        selection_type="structured",
    ),

    "CHILDREN": DomainSchema(
        key="CHILDREN",
        label="Children",
        selection_type="structured",
        allow_none=True,
    ),
}

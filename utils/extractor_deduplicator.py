import re
from collections import defaultdict
from datetime import datetime


def normalise_text(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def date_bucket(date):
    if not date:
        return "undated"

    if isinstance(date, datetime):
        return date.strftime("%Y-%m-%d")

    date = str(date)

    # Try YYYY-MM-DD
    if len(date) >= 10:
        return date[:10]

    # Try YYYY-MM
    if len(date) >= 7:
        return date[:7]

    return date


def deduplicate_items(items: list[dict]) -> list[dict]:
    """
    Deduplicate extracted history items while preserving provenance.
    """

    buckets = defaultdict(list)

    for item in items:
        key = (
            item.get("category"),
            normalise_text(item.get("text", "")),
            date_bucket(item.get("date")),
        )
        buckets[key].append(item)

    merged = []

    for (_, _, _), group in buckets.items():
        if len(group) == 1:
            merged.append(group[0])
            continue

        # Merge duplicates
        base = group[0]

        sources = set()
        for g in group:
            src = g.get("source")
            if src:
                sources.add(src)

        base["sources"] = sorted(sources)
        merged.append(base)

    return merged

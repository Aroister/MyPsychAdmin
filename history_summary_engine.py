# ======================================================================
# history_summary_engine.py (V15)
# Premium Clinical Summary Renderer
# ======================================================================

import re


# ----------------------------------------------------------------------
# CATEGORY ICONS
# ----------------------------------------------------------------------
CATEGORY_ICONS = {
    "Legal": "⚖️",
    "Diagnosis": "🧬",
    "Past Psychiatric History": "🧠",
    "Medication History": "💊",
    "Drug and Alcohol History": "🍺",
    "Past Medical History": "🏥",
    "Forensic History": "⚔️",
    "Personal History": "👤",
    "Mental State Examination": "🧩",
    "Risk": "⚠️",
    "Physical Examination": "🩺",
    "ECG": "🫀",
    "Impression": "📝",
    "Capacity Assessment": "🧠✔",
    "Summary": "📌"
}

# Soft Gold date colour (Theme 2)
DATE_COLOR = "#e5c890"
CATEGORY_COLOR = "#CFE9FF"
DIVIDER_COLOR = "#444"

# Excluded categories
EXCLUDED = {
    "Circumstances of Admission",
    "History of Presenting Complaint",
    "Plan",
}


# ----------------------------------------------------------------------
# Clean text
# ----------------------------------------------------------------------
def _clean(s: str) -> str:
    if not s:
        return ""
    s = s.replace("\r", "").replace("\t", " ").strip()
    s = re.sub(r"\s{2,}", " ", s)
    s = "\n".join([ln.strip() for ln in s.splitlines() if ln.strip()])
    return s


# ----------------------------------------------------------------------
# D2: Medium Aggressive Sentence Splitting
# ----------------------------------------------------------------------
def _split_sentences(text: str):
    if not text:
        return []

    text = text.strip()
    text = re.sub(r"\s{2,}", " ", text)

    # Medium-aggressive splits:
    parts = re.split(r"(?<=[.!?])\s+|;+\s+|:\s+(?=[A-Z])", text)

    out = []
    for p in parts:
        p = p.strip().rstrip(".")
        if len(p) > 3:
            out.append(p)

    return out


# ----------------------------------------------------------------------
# Build bullet summary with date grouping + nested subpoints
# ----------------------------------------------------------------------
def _build_bullet_summary(entries):
    if not entries:
        return "No information found."

    # Sort and group by DATE (not datetime)
    entries = sorted(entries, key=lambda x: x["date"])
    grouped = {}
    for e in entries:
        key = e["date"].date()
        grouped.setdefault(key, []).append(e)

    lines = []

    for key in sorted(grouped.keys()):
        group_items = grouped[key]

        # Build date label
        d = group_items[0]["date"].strftime("%d %b %Y")
        date_html = f"<b><span style='color:{DATE_COLOR};'>{d}</span></b>"

        # Combine all text for this date
        combined = "\n".join(_clean(e["text"]) for e in group_items)
        subs = _split_sentences(combined)

        # Bullet line
        lines.append(f"• {date_html}<br>")

        # Nested lines
        for s in subs:
            lines.append(f"&nbsp;&nbsp;&nbsp;&nbsp;— {s}.<br>")

        lines.append("<br>")   # spacing after each date

    return "".join(lines)


# ----------------------------------------------------------------------
# MAIN ENGINE
# ----------------------------------------------------------------------
def generate_history_summaries(history_dict):
    summaries = {}
    categories = history_dict.get("categories", {})

    for cat_id in sorted(categories.keys()):
        cat = categories[cat_id]
        name = cat.get("name")
        items = cat.get("items", [])

        if name in EXCLUDED:
            continue

        # Prepare entries
        prepared = []
        for it in items:
            dt = it.get("date")
            txt = it.get("text")
            entry_id = it.get("anchor_id") or it.get("entry_id") or ""
            if dt is None:
                continue
            prepared.append({"date": dt, "text": txt, "entry_id": entry_id})

        # Build summary bullets
        summary_text = _build_bullet_summary(prepared)

        # First entry anchor
        first_id = prepared[0]["entry_id"] if prepared else ""

        # Get icon
        icon = CATEGORY_ICONS.get(name, "•")

        # Wrap with category header + divider
        header_html = (
            f"<div style='font-size:16px; font-weight:bold; color:{CATEGORY_COLOR};'>"
            f"<span style='color:{CATEGORY_COLOR};'>{icon}</span> {name}"
            f"</div>"
            f"<hr style='border:1px solid {DIVIDER_COLOR};'>"
        )

        full_html = header_html + summary_text

        summaries[name] = {
            "summary": full_html,
            "first_entry_id": first_id
        }

    return summaries

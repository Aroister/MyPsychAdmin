from __future__ import annotations
from datetime import datetime, timedelta
from typing import List, Dict, Any

print(">>> [TIMELINE] Loaded:", __file__)


# ============================================================
# 0. SOURCE DECISION (explicit only)
# ============================================================

def decide_pipeline(notes):
    sources = {(n.get("source") or "").strip().lower() for n in notes}

    if sources == {"carenotes"}:
        print(">>> [TIMELINE] Pipeline = CARENOTES")
        return "carenotes"

    if sources == {"rio"}:
        print(">>> [TIMELINE] Pipeline = RIO")
        return "rio"

    print(">>> [TIMELINE] Mixed sources → default = RIO")
    return "rio"



# ============================================================
# 1. CARENOTES (15-day density)
# ============================================================

def build_carenotes_timeline(notes: List[Dict[str, Any]]):
    if not notes:
        return []

    all_dates = [
        n["date"].date()
        for n in notes
        if isinstance(n.get("date"), datetime)
    ]
    if not all_dates:
        return []

    all_dates.sort()
    unique_dates = sorted(set(all_dates))
    first = unique_dates[0]
    last = unique_dates[-1]

    window = timedelta(days=15)
    counts = []

    for d in unique_dates:
        w_end = d + window
        count = sum(1 for dt in all_dates if d <= dt <= w_end)
        counts.append(count)

    segments = []
    inside = False
    seg_start = None

    for i, d in enumerate(unique_dates):
        count = counts[i]

        if not inside and count >= 40:
            inside = True
            seg_start = d

        elif inside and count < 10:
            inside = False
            segments.append({"start": seg_start, "end": unique_dates[i - 1]})
            seg_start = None

    if inside and seg_start:
        segments.append({"start": seg_start, "end": last})

    if not segments:
        return [{"type": "community", "start": first, "end": last}]

    episodes = []

    if first < segments[0]["start"]:
        episodes.append({
            "type": "community",
            "start": first,
            "end": segments[0]["start"] - timedelta(days=1)
        })

    for i, seg in enumerate(segments):
        episodes.append({
            "type": "inpatient",
            "start": seg["start"],
            "end": seg["end"],
            "label": f"Admission {i+1}"
        })

        if i < len(segments) - 1:
            nxt = segments[i+1]
            episodes.append({
                "type": "community",
                "start": seg["end"] + timedelta(days=1),
                "end": nxt["start"] - timedelta(days=1)
            })

    last_seg = segments[-1]
    if last_seg["end"] < last:
        episodes.append({
            "type": "community",
            "start": last_seg["end"] + timedelta(days=1),
            "end": last
        })

    return episodes



# ============================================================
# 2. RIO (5-day density + keyword refinement)
# ============================================================

def note_indicates_admission(text: str) -> bool:
    if not text:
        return False

    t = text.lower()

    PRIMARY = [
        "sec 136", "section 136", "136 suite", "aac",
        "brought to the aac", "brought to aac", "brought in by police",
        "brought by police", "taken to the 136",
        "detained under sec", "detained under section",
        "detained under sec 2", "detained under section 2",
        "detained under sec 3", "detained under section 3",
        "sectioned",
        "brought to the ward", "brought back on the ward",
        "escorted to ward", "escorted to the ward",
        "transferred to ward",
        "accepted papers", "bed manager accepted", "bed identified",
    ]

    SECONDARY = [
        "handcuffed", "searched",
        "mha assessment", "mental health act assessment",
        "mha", "s136"
    ]

    if any(p in t for p in PRIMARY):
        return True

    if any(s in t for s in SECONDARY) and "police" in t:
        return True

    return False


def build_rio_timeline(notes: List[Dict[str, Any]]):
    if not notes:
        return []

    all_dates = sorted(n["date"].date() for n in notes)
    unique_dates = sorted(set(all_dates))
    first = unique_dates[0]
    last = unique_dates[-1]

    # --- 5-day density ---
    counts = []
    for d in unique_dates:
        w_end = d + timedelta(days=5)
        count = sum(1 for dt in all_dates if d <= dt <= w_end)
        counts.append(count)

    # --- threshold segmentation ---
    segments = []
    in_adm = False
    seg_start = None

    for i, d in enumerate(unique_dates):
        count = counts[i]

        if not in_adm and count > 40:
            in_adm = True
            seg_start = d

        elif in_adm and count < 10:
            in_adm = False
            segments.append({"start": seg_start, "end": d})
            seg_start = None

    if in_adm and seg_start:
        segments.append({"start": seg_start, "end": last})

    if not segments:
        return [{"type": "community", "start": first, "end": last}]

    # --- merge ---
    segments.sort(key=lambda s: s["start"])
    merged = [segments[0]]

    for s in segments[1:]:
        last_seg = merged[-1]
        if s["start"] <= last_seg["end"]:
            last_seg["end"] = max(last_seg["end"], s["end"])
        else:
            merged.append(s)

    # --- refine start date using keyword scanning ---
    refined = []
    for seg in merged:
        est = seg["start"]
        search_from = est - timedelta(days=10)
        search_to = est + timedelta(days=10)
        corrected = est

        for n in notes:
            nd = n["date"].date()
            if search_from <= nd <= search_to:
                if note_indicates_admission(n.get("content", n.get("text", ""))):
                    if nd < corrected:
                        corrected = nd

        refined.append({"start": corrected, "end": seg["end"]})

    # --- build episodes ---
    episodes = []

    if first < refined[0]["start"]:
        episodes.append({
            "type": "community",
            "start": first,
            "end": refined[0]["start"] - timedelta(days=1)
        })

    for i, seg in enumerate(refined):
        episodes.append({
            "type": "inpatient",
            "start": seg["start"],
            "end": seg["end"],
            "label": f"Admission {i+1}"
        })

        if i < len(refined) - 1:
            nxt = refined[i+1]
            episodes.append({
                "type": "community",
                "start": seg["end"] + timedelta(days=1),
                "end": nxt["start"] - timedelta(days=1)
            })

    last_seg = refined[-1]
    if last_seg["end"] < last:
        episodes.append({
            "type": "community",
            "start": last_seg["end"] + timedelta(days=1),
            "end": last
        })

    return episodes



# ============================================================
# 3. MASTER WRAPPER
# ============================================================

def build_timeline(notes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    pipeline = decide_pipeline(notes)

    if pipeline == "carenotes":
        return build_carenotes_timeline(notes)

    return build_rio_timeline(notes)

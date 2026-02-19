from __future__ import annotations
from datetime import datetime, timedelta
from typing import List, Dict, Any
import re

print(">>> [TIMELINE] Loaded:", __file__)


def is_valid_timeline_date(note: Dict[str, Any]) -> bool:
    dt = note.get("date")
    if not isinstance(dt, datetime):
        return False

    t = (note.get("type") or "").lower()
    p = (note.get("preview") or "").lower()

    # Exclude demographics / DOB
    if "born" in p or "date of birth" in p:
        return False
    if t in {"demographics", "patient details"}:
        return False

    return True

# ============================================================
# 0. SOURCE DECISION (explicit only)
# ============================================================

def decide_pipeline(notes):
    sources = {
        (n.get("source") or "").strip().lower()
        for n in notes
        if isinstance(n.get("source"), str)
    }

    if not sources:
        print(">>> [TIMELINE] No sources → default = autodetect")
        return "autodetect"

    if sources == {"rio"}:
        return "rio"

    if sources == {"carenotes"}:
        return "carenotes"

    if sources == {"epjs"}:
        return "epjs"

    # Mixed but known note systems → autodetect
    if sources.issubset({"rio", "carenotes", "epjs"}):
        print(f">>> [TIMELINE] Mixed known sources {sources} → autodetect")
        return "autodetect"

    # Fallback (should rarely happen)
    print(f">>> [TIMELINE] Unknown sources {sources} → autodetect")
    return "autodetect"


# ============================================================
# 1. CARENOTES (15-day density)
# ============================================================

def build_carenotes_timeline(notes: List[Dict[str, Any]], debug: bool = True):
    if not notes:
        if debug:
            print(">>> [TIMELINE DEBUG] No notes provided")
        return []

    ordered_dates = [
        n["date"].date()
        for n in notes
        if isinstance(n.get("date"), datetime)
    ]

    if not ordered_dates:
        if debug:
            print(">>> [TIMELINE DEBUG] No valid dates in notes")
        return []

    first = min(ordered_dates)            # ← EARLIEST DATE
    last = max(ordered_dates)

    all_dates = sorted(ordered_dates)
    unique_dates = sorted(set(all_dates))

    if debug:
        print(f">>> [TIMELINE DEBUG] ==========================================")
        print(f">>> [TIMELINE DEBUG] CARENOTES pipeline (15-day window)")
        print(f">>> [TIMELINE DEBUG] Total notes: {len(notes)}, dated: {len(all_dates)}, unique dates: {len(unique_dates)}")
        print(f">>> [TIMELINE DEBUG] Range: {first} to {last}")
        print(f">>> [TIMELINE DEBUG] ==========================================")

    from collections import Counter
    date_counts = Counter(all_dates)

    window = timedelta(days=15)
    counts = []

    for d in unique_dates:
        w_end = d + window
        count = sum(1 for dt in all_dates if d <= dt <= w_end)
        counts.append(count)

    if debug:
        print(f">>> [TIMELINE DEBUG] 15-day DENSITY SCORING (>=40 = admission start, <10 = admission end)")
        print(f">>> [TIMELINE DEBUG] Date        | daily | 15-day | status")
        print(f">>> [TIMELINE DEBUG] ------------|-------|--------|-------")
        in_seg = False
        for i, d in enumerate(unique_dates):
            daily = date_counts[d]
            density = counts[i]
            bar = "#" * min(density, 50)
            if not in_seg and density >= 40:
                status = ">>> ADMISSION START"
                in_seg = True
            elif in_seg and density < 10:
                status = "<<< ADMISSION END"
                in_seg = False
            elif in_seg:
                status = "    (inpatient)"
            else:
                status = ""
            print(f">>>   {d.strftime('%d/%m/%Y')}  | {daily:5d} | {density:6d} | {bar} {status}")

    segments = []
    inside = False
    seg_start = None

    if debug:
        print(f">>> [TIMELINE DEBUG] ------------------------------------------")
        print(f">>> [TIMELINE DEBUG] Segmentation process:")

    for i, d in enumerate(unique_dates):
        count = counts[i]

        if not inside and count >= 40:
            inside = True
            seg_start = d
            if debug:
                print(f">>>   {d.strftime('%d/%m/%Y')}: ADMISSION STARTED (count={count} >= 40)")

        elif inside and count < 10:
            inside = False
            segments.append({"start": seg_start, "end": unique_dates[i - 1]})
            if debug:
                print(f">>>   {d.strftime('%d/%m/%Y')}: ADMISSION ENDED (count={count} < 10)")
                print(f">>>   -> Segment: {seg_start} to {unique_dates[i - 1]}")
            seg_start = None

    if inside and seg_start:
        segments.append({"start": seg_start, "end": last})
        if debug:
            print(f">>>   ADMISSION STILL ACTIVE at end -> Segment: {seg_start} to {last}")

    if debug:
        print(f">>> [TIMELINE DEBUG] ------------------------------------------")
        print(f">>> [TIMELINE DEBUG] Raw segments found: {len(segments)}")
        for i, seg in enumerate(segments):
            print(f">>>   Segment {i+1}: {seg['start']} to {seg['end']}")

    if not segments:
        if debug:
            print(f">>> [TIMELINE DEBUG] NO ADMISSIONS DETECTED - returning community only")
            print(f">>> [TIMELINE DEBUG] Max density was: {max(counts) if counts else 0} (need >=40)")
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
        trailing_start = last_seg["end"] + timedelta(days=1)
        gap_days = (last - last_seg["end"]).days

        # Only check trailing inpatient markers if the last segment ends
        # near the end of notes (within 30 days). If there are months/years
        # of notes after discharge, the patient was clearly discharged.
        if gap_days <= 30:
            trailing_notes = [
                n for n in notes
                if isinstance(n.get("date"), datetime)
                and n["date"].date() >= trailing_start
            ]

            if debug:
                print(f">>> [TIMELINE DEBUG] Trailing notes check: {len(trailing_notes)} notes, {gap_days} days after last segment")

            inpatient_indicators = [
                r'\bward\b', r'\bnursing\s+(day|night|observation)', r'\blevel\s+\d',
                r'\bhourly\s+check', r'\bsection\s+\d', r'\bmha\s+status', r'\b37/41\b',
                r'\bon\s+the\s+ward\b', r'\bward\s+round\b', r'\brisk\s+status',
                r'\bintermittent\b', r'\bobservation\b', r'\bmedication\s+round',
            ]

            has_inpatient_markers = False
            for n in trailing_notes:
                content = (n.get('content', '') or n.get('text', '')).lower()
                if any(re.search(p, content, re.IGNORECASE) for p in inpatient_indicators):
                    has_inpatient_markers = True
                    if debug:
                        nd = n["date"].date() if isinstance(n.get("date"), datetime) else "?"
                        print(f">>>   Inpatient marker found on {nd}: {content[:80]}...")
                    break

            if has_inpatient_markers:
                episodes[-1]["end"] = last
                if debug:
                    print(f">>>   -> Extended last admission to {last}")
            else:
                episodes.append({
                    "type": "community",
                    "start": trailing_start,
                    "end": last
                })
                if debug:
                    print(f">>>   -> Added trailing community: {trailing_start} to {last}")
        else:
            # Large gap — clearly discharged, add community period
            episodes.append({
                "type": "community",
                "start": trailing_start,
                "end": last
            })
            if debug:
                print(f">>> [TIMELINE DEBUG] Trailing gap {gap_days} days — clearly discharged, adding community")

    if debug:
        print(f">>> [TIMELINE DEBUG] ==========================================")
        print(f">>> [TIMELINE DEBUG] FINAL EPISODES:")
        for ep in episodes:
            print(f">>>   {ep['type'].upper()}: {ep['start']} to {ep['end']}" +
                  (f" ({ep.get('label', '')})" if ep.get('label') else ""))
        print(f">>> [TIMELINE DEBUG] ==========================================")

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


def build_rio_timeline(notes: List[Dict[str, Any]], debug: bool = True):
    if not notes:
        if debug:
            print(">>> [TIMELINE DEBUG] No notes provided")
        return []

    # --------------------------------------------------
    # Preserve note order for timeline bounds
    # --------------------------------------------------
    ordered_dates = [
        n["date"].date()
        for n in notes
        if isinstance(n.get("date"), datetime)
    ]

    if not ordered_dates:
        if debug:
            print(">>> [TIMELINE DEBUG] No valid dates in notes")
        return []

    first = min(ordered_dates)        # ← EARLIEST DATE
    last = max(ordered_dates)

    all_dates = sorted(ordered_dates)
    unique_dates = sorted(set(all_dates))

    if debug:
        print(f">>> [TIMELINE DEBUG] ==========================================")
        print(f">>> [TIMELINE DEBUG] Total notes: {len(notes)}, dated: {len(all_dates)}, unique dates: {len(unique_dates)}")
        print(f">>> [TIMELINE DEBUG] Range: {first} to {last}")
        print(f">>> [TIMELINE DEBUG] ==========================================")

    # --- 5-day density ---
    from collections import Counter
    date_counts = Counter(all_dates)

    counts = []
    for d in unique_dates:
        w_end = d + timedelta(days=5)
        count = sum(1 for dt in all_dates if d <= dt <= w_end)
        counts.append(count)

    if debug:
        print(f">>> [TIMELINE DEBUG] 5-day DENSITY SCORING (>30 = admission start, <10 = admission end)")
        print(f">>> [TIMELINE DEBUG] Date        | daily | 5-day | status")
        print(f">>> [TIMELINE DEBUG] ------------|-------|-------|-------")
        in_seg = False
        for i, d in enumerate(unique_dates):
            daily = date_counts[d]
            density = counts[i]
            bar = "#" * min(density, 50)
            if not in_seg and density > 30:
                status = ">>> ADMISSION START"
                in_seg = True
            elif in_seg and density < 10:
                status = "<<< ADMISSION END"
                in_seg = False
            elif in_seg:
                status = "    (inpatient)"
            else:
                status = ""
            print(f">>>   {d.strftime('%d/%m/%Y')}  | {daily:5d} | {density:5d} | {bar} {status}")

    # --- threshold segmentation ---
    segments = []
    in_adm = False
    seg_start = None

    if debug:
        print(f">>> [TIMELINE DEBUG] ------------------------------------------")
        print(f">>> [TIMELINE DEBUG] Segmentation process:")

    for i, d in enumerate(unique_dates):
        count = counts[i]

        if not in_adm and count > 30:
            in_adm = True
            seg_start = d
            if debug:
                print(f">>>   {d.strftime('%d/%m/%Y')}: ADMISSION STARTED (count={count} > 30)")

        elif in_adm and count < 10:
            in_adm = False
            segments.append({"start": seg_start, "end": d})
            if debug:
                print(f">>>   {d.strftime('%d/%m/%Y')}: ADMISSION ENDED (count={count} < 10)")
                print(f">>>   -> Segment: {seg_start} to {d}")
            seg_start = None

    if in_adm and seg_start:
        segments.append({"start": seg_start, "end": last})
        if debug:
            print(f">>>   ADMISSION STILL ACTIVE at end -> Segment: {seg_start} to {last}")

    if debug:
        print(f">>> [TIMELINE DEBUG] ------------------------------------------")
        print(f">>> [TIMELINE DEBUG] Raw segments found: {len(segments)}")
        for i, seg in enumerate(segments):
            print(f">>>   Segment {i+1}: {seg['start']} to {seg['end']}")

    if not segments:
        if debug:
            print(f">>> [TIMELINE DEBUG] NO ADMISSIONS DETECTED - returning community only")
            print(f">>> [TIMELINE DEBUG] Max density was: {max(counts) if counts else 0} (need >30)")
        return [{"type": "community", "start": first, "end": last}]

    # --- merge overlapping segments ---
    segments.sort(key=lambda s: s["start"])
    merged = [segments[0]]

    for s in segments[1:]:
        last_seg = merged[-1]
        if s["start"] <= last_seg["end"]:
            last_seg["end"] = max(last_seg["end"], s["end"])
        else:
            merged.append(s)

    if debug:
        print(f">>> [TIMELINE DEBUG] After merging: {len(merged)} segments")

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
                        if debug:
                            print(f">>>   Keyword refinement: moved start from {est} to {corrected}")

        refined.append({"start": corrected, "end": seg["end"]})

    if debug:
        print(f">>> [TIMELINE DEBUG] ------------------------------------------")
        print(f">>> [TIMELINE DEBUG] Final refined segments:")
        for i, seg in enumerate(refined):
            print(f">>>   Admission {i+1}: {seg['start']} to {seg['end']}")

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

    if debug:
        print(f">>> [TIMELINE DEBUG] ==========================================")
        print(f">>> [TIMELINE DEBUG] FINAL EPISODES:")
        for ep in episodes:
            print(f">>>   {ep['type'].upper()}: {ep['start']} to {ep['end']}" +
                  (f" ({ep.get('label', '')})" if ep.get('label') else ""))
        print(f">>> [TIMELINE DEBUG] ==========================================")

    return episodes




# ============================================================
# 3. MASTER WRAPPER
# ============================================================

def build_timeline(notes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    pipeline = decide_pipeline(notes)
    print(f">>> [TIMELINE] Pipeline selected: {pipeline} (from {len(notes)} notes)")

    if pipeline == "carenotes":
        return build_carenotes_timeline(notes)

    return build_rio_timeline(notes)


# ============================================================
# 4. EXTERNAL PROVIDER DETECTION (Post-processing layer)
# ============================================================
# This runs ON TOP of the core timeline - does not replace it.
# HIGH THRESHOLD: Only detects clear admissions to external providers.

EXTERNAL_PROVIDERS = [
    # Major private psychiatric hospital groups
    "cygnet", "priory", "elysium", "huntercombe", "st andrews", "st andrew's",
    "partnerships in care", "cambian", "nightingale",
    # Specific hospitals
    "bethlem", "maudsley", "broadmoor", "rampton", "ashworth",
]

# These indicate ACTUAL admission - not just planning/referrals
STRONG_ADMISSION_INDICATORS = [
    "admitted to", "admission to", "transferred to",
    "on the ward at", "on ward at", "ward round at",
    "remains at", "remains in", "currently at",
    "detained at", "sectioned at",
    "nursing entry", "1:1 observation",
]

# These are PLANNING - do not count as admission evidence
PLANNING_EXCLUSIONS = [
    "referred for", "referral to", "bed request",
    "considering", "looking at", "option",
    "discharge to", "discharge planning", "will be discharged",
    "ready for discharge", "preparing for discharge",
    "visited", "i visited", "we visited",
]


def detect_external_provider(text: str) -> str | None:
    """Check if text mentions an external provider. Returns provider name or None."""
    if not text:
        return None
    t = text.lower()
    for provider in EXTERNAL_PROVIDERS:
        if provider in t:
            return provider.title()
    return None


def has_strong_admission_evidence(text: str, provider: str) -> bool:
    """
    Check if text has STRONG evidence of admission to the provider.
    Must have admission indicator AND provider name in same context.
    Excludes planning/referral language.
    """
    if not text or not provider:
        return False

    t = text.lower()
    provider_lower = provider.lower()

    # First check for planning exclusions - if present, this is NOT admission evidence
    if any(excl in t for excl in PLANNING_EXCLUSIONS):
        return False

    # Must have provider mentioned
    if provider_lower not in t:
        return False

    # Must have strong admission indicator
    if any(ind in t for ind in STRONG_ADMISSION_INDICATORS):
        return True

    return False


def check_community_for_external_stays(
    episodes: List[Dict[str, Any]],
    notes: List[Dict[str, Any]],
    min_notes_threshold: int = 3,
    debug: bool = False
) -> List[Dict[str, Any]]:
    """
    Post-process timeline episodes to detect external provider admissions.

    HIGH THRESHOLD REQUIREMENTS:
    1. Provider must be mentioned in multiple notes (min_notes_threshold)
    2. At least one note must have STRONG admission evidence
    3. Planning/referral language is excluded

    This preserves the core timeline and only splits community periods
    when there is clear evidence of external admission.
    """
    if not episodes or not notes:
        return episodes

    if debug:
        print(f">>> [EXTERNAL CHECK] Scanning community periods for external stays...")
        print(f">>> [EXTERNAL CHECK] Threshold: {min_notes_threshold} notes minimum")

    result = []

    for ep in episodes:
        # Only check community periods
        if ep["type"] != "community":
            result.append(ep)
            continue

        # Get notes within this community period
        period_notes = []
        for n in notes:
            nd = n.get("date")
            if not isinstance(nd, datetime):
                continue
            nd = nd.date()
            if ep["start"] <= nd <= ep["end"]:
                period_notes.append(n)

        if not period_notes:
            result.append(ep)
            continue

        # Check for external provider mentions
        provider_evidence = {}  # provider -> list of notes with strong evidence

        for n in period_notes:
            content = n.get("content", n.get("text", n.get("preview", "")))
            provider = detect_external_provider(content)

            if provider:
                if provider not in provider_evidence:
                    provider_evidence[provider] = {"mentions": 0, "strong_evidence": []}

                provider_evidence[provider]["mentions"] += 1

                if has_strong_admission_evidence(content, provider):
                    provider_evidence[provider]["strong_evidence"].append(n)

        # Check if any provider meets the HIGH THRESHOLD
        external_stay_detected = None
        for provider, evidence in provider_evidence.items():
            mentions = evidence["mentions"]
            strong_count = len(evidence["strong_evidence"])

            if debug and mentions > 0:
                print(f">>> [EXTERNAL CHECK] Provider '{provider}': {mentions} mentions, {strong_count} with strong evidence")

            # HIGH THRESHOLD: Multiple mentions AND at least one strong evidence
            if mentions >= min_notes_threshold and strong_count >= 1:
                external_stay_detected = provider
                if debug:
                    print(f">>> [EXTERNAL CHECK] *** EXTERNAL ADMISSION DETECTED: {provider}")
                break

        if external_stay_detected:
            # Mark this community period as external inpatient
            result.append({
                "type": "inpatient",
                "start": ep["start"],
                "end": ep["end"],
                "label": f"External Admission ({external_stay_detected})",
                "provider": external_stay_detected,
                "external": True
            })
        else:
            result.append(ep)

    return result


def build_timeline_with_external_check(
    notes: List[Dict[str, Any]],
    check_external: bool = True,
    debug: bool = False
) -> List[Dict[str, Any]]:
    """
    Build timeline with optional external provider detection.

    1. First builds core timeline using density detection
    2. Then optionally checks community periods for external stays
    """
    # Core timeline (density-based)
    episodes = build_timeline(notes)

    # Optional: Check for external provider stays
    if check_external and episodes:
        episodes = check_community_for_external_stays(episodes, notes, debug=debug)

    return episodes

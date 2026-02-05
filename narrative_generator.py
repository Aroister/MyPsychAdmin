"""
Reusable narrative generator module.

Provides date-filtered narrative generation for use across different report sections:
- Notes Progress Panel (full date range)
- ASR Section 8 (1 year before latest entry)
- Psych Tribunal Report (1 year before latest entry)
- Nursing Tribunal Section 9 (1 year before latest entry)
- Social Circumstances Tribunal Section 16 (1 year before latest entry)
- General Psychiatric Report Section 3 (last admission only)
"""

from datetime import datetime, timedelta
from typing import List, Dict, Tuple, Optional


def filter_entries_by_period(entries: List[Dict], period: str = 'all',
                              admission_start: Optional[datetime] = None,
                              admission_end: Optional[datetime] = None) -> List[Dict]:
    """
    Filter entries by time period.

    Args:
        entries: List of entry dictionaries with 'date' key
        period: One of:
            - 'all': No filtering
            - '1_year': Last 1 year from most recent entry
            - '6_months': Last 6 months from most recent entry
            - 'last_admission': Only entries from the last admission period
        admission_start: Start date for 'last_admission' period
        admission_end: End date for 'last_admission' period

    Returns:
        Filtered list of entries
    """
    if not entries:
        return []

    if period == 'all':
        return entries

    # Find the most recent entry date
    dates = [e['date'] for e in entries if e.get('date')]
    if not dates:
        return entries

    most_recent = max(dates)

    if period == '1_year':
        cutoff = most_recent - timedelta(days=365)
        return [e for e in entries if e.get('date') and e['date'] >= cutoff]

    elif period == '6_months':
        cutoff = most_recent - timedelta(days=180)
        return [e for e in entries if e.get('date') and e['date'] >= cutoff]

    elif period == 'last_admission':
        if admission_start and admission_end:
            return [e for e in entries if e.get('date') and
                    admission_start <= e['date'] <= admission_end]
        else:
            # Need to detect last admission from entries
            from timeline_builder import build_timeline_with_external_check
            notes_for_timeline = [{'date': e['date'], 'datetime': e['date'],
                                   'content': e.get('content', e.get('text', '')),
                                   'text': e.get('content', e.get('text', ''))}
                                  for e in entries if e.get('date')]

            try:
                episodes = build_timeline_with_external_check(notes_for_timeline,
                                                               check_external=False, debug=False)
                # Find the last inpatient episode
                inpatient_episodes = [ep for ep in episodes if ep.get('type') == 'inpatient']
                if inpatient_episodes:
                    last_admission = inpatient_episodes[-1]
                    start = last_admission['start']
                    end = last_admission['end']
                    return [e for e in entries if e.get('date') and start <= e['date'] <= end]
            except Exception as ex:
                print(f"[NarrativeGenerator] Timeline detection failed: {ex}")

            return entries

    return entries


def generate_narrative(entries: List[Dict], period: str = 'all',
                       admission_start: Optional[datetime] = None,
                       admission_end: Optional[datetime] = None) -> Tuple[str, str]:
    """
    Generate narrative summary from clinical entries.

    Args:
        entries: List of entry dictionaries with 'date', 'content'/'text' keys
        period: Time period filter ('all', '1_year', '6_months', 'last_admission')
        admission_start: Optional start date for 'last_admission' period
        admission_end: Optional end date for 'last_admission' period

    Returns:
        Tuple of (plain_text, html_text) narrative
    """
    # Filter entries by period
    filtered_entries = filter_entries_by_period(entries, period, admission_start, admission_end)

    if not filtered_entries:
        return "", ""

    # Prepare entries for narrative generation
    # The tribunal_popups._generate_narrative_summary expects entries with:
    # - date: datetime
    # - content: str
    # - content_lower: str (lowercase content)
    # - score: int (risk score)
    # - drivers: list of (term, score) tuples

    from progress_panel import score_entry

    prepared_entries = []
    for entry in filtered_entries:
        content = entry.get('content', entry.get('text', ''))
        if not content:
            continue

        date = entry.get('date')
        if not date:
            continue

        # Score the entry
        score, drivers = score_entry(content)

        prepared_entries.append({
            'date': date,
            'datetime': date,
            'content': content,
            'content_lower': content.lower(),
            'score': score,
            'drivers': drivers,
            'type': entry.get('type', ''),
            'originator': entry.get('originator', ''),
        })

    if not prepared_entries:
        return "", ""

    # Use the narrative generation from tribunal_popups
    from tribunal_popups import TribunalProgressPopup

    # Create a temporary instance to call the method
    temp_popup = TribunalProgressPopup.__new__(TribunalProgressPopup)
    plain_text, html_text = temp_popup._generate_narrative_summary(prepared_entries)

    return plain_text, html_text


def get_last_admission_dates(entries: List[Dict]) -> Tuple[Optional[datetime], Optional[datetime]]:
    """
    Detect the last admission period from entries using timeline builder.

    Returns:
        Tuple of (admission_start, admission_end) or (None, None) if not found
    """
    if not entries:
        return None, None

    from timeline_builder import build_timeline_with_external_check

    notes_for_timeline = [{'date': e['date'], 'datetime': e['date'],
                           'content': e.get('content', e.get('text', '')),
                           'text': e.get('content', e.get('text', ''))}
                          for e in entries if e.get('date')]

    try:
        episodes = build_timeline_with_external_check(notes_for_timeline,
                                                       check_external=False, debug=False)
        # Find the last inpatient episode
        inpatient_episodes = [ep for ep in episodes if ep.get('type') == 'inpatient']
        if inpatient_episodes:
            last_admission = inpatient_episodes[-1]
            return last_admission['start'], last_admission['end']
    except Exception as ex:
        print(f"[NarrativeGenerator] Timeline detection failed: {ex}")

    return None, None


def get_date_range_info(entries: List[Dict], period: str = 'all',
                        admission_start: Optional[datetime] = None,
                        admission_end: Optional[datetime] = None) -> str:
    """
    Get a human-readable description of the date range being used.

    Returns:
        String like "01/01/2024 - 01/01/2025 (1 year)" or "Full notes (01/01/2020 - 01/01/2025)"
    """
    filtered = filter_entries_by_period(entries, period, admission_start, admission_end)
    if not filtered:
        return "No entries"

    dates = [e['date'] for e in filtered if e.get('date')]
    if not dates:
        return "No dated entries"

    earliest = min(dates)
    latest = max(dates)

    earliest_str = earliest.strftime('%d/%m/%Y') if hasattr(earliest, 'strftime') else str(earliest)[:10]
    latest_str = latest.strftime('%d/%m/%Y') if hasattr(latest, 'strftime') else str(latest)[:10]

    if period == 'all':
        return f"Full notes ({earliest_str} - {latest_str})"
    elif period == '1_year':
        return f"{earliest_str} - {latest_str} (1 year)"
    elif period == '6_months':
        return f"{earliest_str} - {latest_str} (6 months)"
    elif period == 'last_admission':
        return f"{earliest_str} - {latest_str} (last admission)"
    else:
        return f"{earliest_str} - {latest_str}"


# ============================================================
# Convenience functions for each report section
# ============================================================

def generate_narrative_full(entries: List[Dict]) -> Tuple[str, str]:
    """Generate narrative for full notes (no date filtering).
    Used by: Notes Progress Panel
    """
    return generate_narrative(entries, period='all')


def generate_narrative_1_year(entries: List[Dict]) -> Tuple[str, str]:
    """Generate narrative for last 1 year from most recent entry.
    Used by: ASR Section 8, MOJ Leave 4d, Psych Tribunal 14, Nursing 9, Social 16
    """
    return generate_narrative(entries, period='1_year')


def generate_narrative_last_admission(entries: List[Dict]) -> Tuple[str, str]:
    """Generate narrative for last admission period only.
    Used by: General Psychiatric Report Section 3
    """
    return generate_narrative(entries, period='last_admission')


def generate_narrative_for_report(entries: List[Dict], report_type: str) -> Tuple[str, str]:
    """
    Generate narrative based on report type.

    Args:
        entries: List of entry dictionaries
        report_type: One of:
            - 'notes_panel': Full notes
            - 'progress_panel': 1 year (default) or full
            - 'asr_8': ASR Section 8 (1 year)
            - 'leave_4d': MOJ Leave Section 4d (1 year)
            - 'tribunal_14': Psych Tribunal Section 14 (1 year)
            - 'nursing_9': Nursing Tribunal Section 9 (1 year)
            - 'social_16': Social Circumstances Section 16 (1 year)
            - 'gpr_3': General Psychiatric Report Section 3 (last admission)

    Returns:
        Tuple of (plain_text, html_text) narrative
    """
    report_periods = {
        'notes_panel': 'all',
        'progress_panel': '1_year',
        'asr_8': '1_year',
        'leave_4d': '1_year',
        'tribunal_14': '1_year',
        'nursing_9': '1_year',
        'social_16': '1_year',
        'gpr_3': 'last_admission',
    }

    period = report_periods.get(report_type, '1_year')
    return generate_narrative(entries, period=period)

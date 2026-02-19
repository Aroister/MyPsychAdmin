# ============================================================
# DOCX LETTER IMPORTER — Parse DOCX back into letter sections
# ============================================================

from docx import Document
import re

# ============================================================
# SYMPTOM KEYWORDS FOR POPUP MATCHING
# ============================================================

# Presenting Complaint symptoms (must match presenting_complaint_popup.py)
PC_SYMPTOMS = {
    "Depressive Symptoms": [
        "low mood", "can't sleep", "tired", "can't eat",
        "memory issues", "angry", "suicidal", "cutting",
        "can't concentrate"
    ],
    "Anxiety Symptoms": [
        "being stressed", "restless", "panic",
        "compulsions", "obsessions", "nightmares", "flashbacks"
    ],
    "Manic Features": [
        "high mood", "increased activity", "overspending", "disinhibition"
    ],
    "Psychosis Features": [
        "paranoia", "voices", "control or interference"
    ]
}

# Alternative phrasings that map to the same symptoms
SYMPTOM_ALIASES = {
    "low mood": ["depressed", "depression", "feeling low", "feeling down", "sad", "unhappy"],
    "can't sleep": ["insomnia", "sleep problems", "poor sleep", "difficulty sleeping", "not sleeping", "inability to sleep", "unable to sleep"],
    "tired": ["fatigue", "exhausted", "no energy", "low energy", "tiredness", "lethargy"],
    "can't eat": ["appetite", "not eating", "poor appetite", "loss of appetite", "weight loss"],
    "memory issues": ["poor memory", "forgetful", "concentration", "memory problems"],
    "angry": ["irritable", "irritability", "anger", "agitated", "aggressive"],
    "suicidal": ["suicidal thoughts", "suicidal ideation", "wanting to die", "thoughts of suicide", "self-harm thoughts"],
    "cutting": ["self-harm", "self harm", "self-injury", "harming himself", "harming herself"],
    "can't concentrate": ["poor concentration", "difficulty concentrating", "unable to focus", "difficulties in maintaining concentration", "concentration difficulties"],
    "being stressed": ["stressed", "stress", "anxiety", "anxious", "worried", "worry"],
    "restless": ["agitation", "can't sit still", "restlessness"],
    "panic": ["panic attacks", "panic attack", "panicking"],
    "compulsions": ["compulsive", "rituals", "checking"],
    "obsessions": ["obsessive", "intrusive thoughts", "obsessional"],
    "nightmares": ["bad dreams", "night terrors"],
    "flashbacks": ["reliving", "traumatic memories", "ptsd"],
    "high mood": ["elevated mood", "elated", "euphoric", "manic"],
    "increased activity": ["hyperactive", "more active", "doing more"],
    "overspending": ["spending sprees", "excessive spending"],
    "disinhibition": ["disinhibited", "impulsive", "reckless"],
    "paranoia": ["paranoid", "suspicious", "persecutory"],
    "voices": ["hearing voices", "auditory hallucinations", "hears voices"],
    "control or interference": ["thought insertion", "thought broadcast", "controlled", "control/interference", "thoughts of control", "thoughts of interference"],
}

# Section title to card key mapping
TITLE_TO_KEY = {
    "front page": "front",
    "presenting complaint": "pc",
    "history of presenting complaint": "hpc",
    "affect": "affect",
    "anxiety & related disorders": "anxiety",
    "anxiety and related disorders": "anxiety",
    "thoughts": "thoughts",
    "perceptions": "percepts",
    "psychosis": "psychosis",
    "psychotic symptoms": "psychosis",
    "psychiatric history": "psychhx",
    "past psychiatric history": "psychhx",
    "background history": "background",
    "personal history": "background",
    "drug and alcohol history": "drugalc",
    "drugs and alcohol": "drugalc",
    "social history": "social",
    "forensic history": "forensic",
    "physical health": "physical",
    "past medical history": "physical",
    "function": "function",
    "mental state examination": "mse",
    "mse": "mse",
    "summary": "summary",
    "impression": "summary",
    "plan": "plan",
}

# Sub-headings that should NOT be treated as new section headers
# These are bold headings within sections that should be kept as content
IGNORE_AS_HEADERS = [
    "ocd symptoms",
    "ptsd symptoms",
    "physical health: please",  # Plan sub-heading, not the section header
    "i recommend",
]

# All known section titles for detection
SECTION_TITLES = [
    "Front Page",
    "Presenting Complaint",
    "History of Presenting Complaint",
    "Affect",
    "Anxiety & Related Disorders",
    "Thoughts",
    "Perceptions",
    "Psychosis",
    "Psychotic Symptoms",
    "Psychiatric History",
    "Past Psychiatric History",
    "Background History",
    "Personal History",
    "Drug and Alcohol History",
    "Social History",
    "Forensic History",
    "Physical Health",
    "Past Medical History",
    "Function",
    "Mental State Examination",
    "MSE",
    "Summary",
    "Impression",
    "Plan",
]


def normalize_title(title: str) -> str:
    """Normalize a section title for matching."""
    return title.lower().strip().rstrip(":")


def is_section_header(text: str) -> str | None:
    """Check if text is a section header, return the key if so."""
    normalized = normalize_title(text)

    # Direct match
    if normalized in TITLE_TO_KEY:
        return TITLE_TO_KEY[normalized]

    # Check if it starts with a known title
    for title in SECTION_TITLES:
        if normalized.startswith(normalize_title(title)):
            return TITLE_TO_KEY.get(normalize_title(title))

    return None


def parse_docx_letter(file_path: str) -> dict:
    """
    Parse a DOCX letter file and extract sections.

    Returns:
        dict: {card_key: content_text, ...}
    """
    doc = Document(file_path)

    sections = {}
    current_key = None
    current_content = []
    front_content = []  # Capture content before first section header

    # Sign-off markers that should terminate section collection
    SIGNOFF_MARKERS = [
        "letter signed by",
        "signed by",
        "yours sincerely",
        "yours faithfully",
        "kind regards",
        "best regards",
        "consultant psychiatrist",
        "specialty doctor",
        "registrar",
    ]

    for para in doc.paragraphs:
        text = para.text.strip()

        if not text:
            # Preserve paragraph breaks within sections
            if current_key and current_content:
                current_content.append("")
            elif current_key is None and front_content:
                front_content.append("")
            continue

        # Check if this is a sign-off marker (end of letter content)
        # BUT only terminate if we're NOT in the plan section (plan keeps sign-off info)
        text_lower = text.lower()
        is_signoff = any(marker in text_lower for marker in SIGNOFF_MARKERS)
        if is_signoff and current_key != "plan":
            # Save current section and stop processing further content
            if current_key and current_content:
                while current_content and not current_content[-1]:
                    current_content.pop()
                sections[current_key] = "\n".join(current_content)
                current_key = None
                current_content = []
            continue  # Skip adding sign-off text to non-plan sections

        # Check if this is a section header (bold text or matches known titles)
        is_bold = False
        if para.runs:
            is_bold = all(run.bold for run in para.runs if run.text.strip())

        # Check if this is a sub-heading that should be ignored as a section header
        is_ignored_subheading = any(ignore in text_lower for ignore in IGNORE_AS_HEADERS)

        # Check for section header
        header_key = is_section_header(text)

        if (header_key or (is_bold and len(text) < 50)) and not is_ignored_subheading:
            # Save previous section
            if current_key and current_content:
                # Clean up trailing empty lines
                while current_content and not current_content[-1]:
                    current_content.pop()
                sections[current_key] = "\n".join(current_content)
            elif current_key is None and front_content:
                # Save front page content (before first header)
                while front_content and not front_content[-1]:
                    front_content.pop()
                sections["front"] = "\n".join(front_content)

            # Start new section
            if header_key:
                current_key = header_key
            else:
                # Try to match bold text as a header
                possible_key = is_section_header(text)
                current_key = possible_key if possible_key else None

            current_content = []
        else:
            # Add to current section content
            if current_key:
                current_content.append(text)
            else:
                # Before first header - this is front page content
                front_content.append(text)

    # Save last section
    if current_key and current_content:
        while current_content and not current_content[-1]:
            current_content.pop()
        sections[current_key] = "\n".join(current_content)

    # If no sections found but we have front content, save it
    if not sections and front_content:
        sections["front"] = "\n".join(front_content)

    return sections


def find_symptoms_in_text(text: str) -> dict:
    """
    Find symptoms mentioned in text and return them grouped by category.

    Returns:
        dict: {category_name: [symptom1, symptom2, ...], ...}
    """
    text_lower = text.lower()
    found = {cat: [] for cat in PC_SYMPTOMS}

    for category, symptoms in PC_SYMPTOMS.items():
        for symptom in symptoms:
            # Check exact match
            if symptom in text_lower:
                if symptom not in found[category]:
                    found[category].append(symptom)
                continue

            # Check aliases
            aliases = SYMPTOM_ALIASES.get(symptom, [])
            for alias in aliases:
                if alias in text_lower:
                    if symptom not in found[category]:
                        found[category].append(symptom)
                    break

    # Remove empty categories
    return {k: v for k, v in found.items() if v}


def populate_presenting_complaint_popup(popup, text: str):
    """
    Parse text and check matching symptoms in the presenting complaint popup.
    Also extracts duration and severity.
    """
    found_symptoms = find_symptoms_in_text(text)

    if found_symptoms:
        print(f"[IMPORT] Found symptoms: {found_symptoms}")

        # Find and check the matching checkboxes
        for cluster in popup.clusters:
            # Get category name (remove the arrow prefix)
            category_name = cluster.lbl.text().replace("▶ ", "").replace("▼ ", "")

            if category_name in found_symptoms:
                symptoms_to_check = found_symptoms[category_name]

                for checkbox in cluster.checks:
                    checkbox_text = checkbox.text().lower()
                    if checkbox_text in [s.lower() for s in symptoms_to_check]:
                        checkbox.setChecked(True)
                        print(f"[IMPORT] Checked: {checkbox.text()}")

                # Expand the cluster if it has checked items
                if symptoms_to_check and not cluster.expanded:
                    cluster.toggle(None)

    # Extract and set duration
    # Pattern: "Symptoms have been present for X" or "for X weeks/months"
    duration_match = re.search(
        r"(?:present\s+for|for)\s+(\d+\s+(?:day|week|month|year)s?|one\s+day|a\s+few\s+days|a\s+week|more\s+than\s+a\s+year|6\s+months\s+to\s+1\s+year)",
        text, re.IGNORECASE
    )
    if duration_match and hasattr(popup, 'duration_box'):
        duration_text = duration_match.group(1).strip().lower()
        print(f"[IMPORT] Found duration text: '{duration_text}'")
        # Try exact match first
        for i in range(popup.duration_box.count()):
            item = popup.duration_box.itemText(i).lower()
            if duration_text == item:
                popup.duration_box.setCurrentIndex(i)
                print(f"[IMPORT] Set duration (exact): {popup.duration_box.itemText(i)}")
                break
        else:
            # Try partial match
            for i in range(popup.duration_box.count()):
                item = popup.duration_box.itemText(i).lower()
                if duration_text in item or item in duration_text:
                    popup.duration_box.setCurrentIndex(i)
                    print(f"[IMPORT] Set duration (partial): {popup.duration_box.itemText(i)}")
                    break

    # Extract and set severity
    # Pattern: "Severity is rated X out of 10" or "severity X/10"
    severity_match = re.search(
        r"severity\s+(?:is\s+)?(?:rated\s+)?(\d+)\s*(?:out\s+of\s+10|/10)",
        text, re.IGNORECASE
    )
    if severity_match and hasattr(popup, 'severity_slider'):
        severity = int(severity_match.group(1))
        if 0 <= severity <= 10:
            popup.severity_slider.setValue(severity)
            print(f"[IMPORT] Set severity: {severity}")

    # Extract and set impact
    # Pattern: "These symptoms impact her/his X and Y" or "symptoms impact X" or "impact on X"
    impact_match = re.search(
        r"(?:these\s+)?(?:symptoms?\s+)?impact\s+(?:her|his|their|on)?\s*([^.]+)",
        text, re.IGNORECASE
    )
    if impact_match and hasattr(popup, 'impact_widget'):
        impact_text = impact_match.group(1).lower()
        print(f"[IMPORT] Found impact text: '{impact_text}'")

        # Map text to chip options
        impact_mapping = {
            "work": "Work",
            "job": "Work",
            "employment": "Work",
            "relationships": "Rltps",
            "relationship": "Rltps",
            "family": "Rltps",
            "self-care": "Self-care",
            "self care": "Self-care",
            "hygiene": "Self-care",
            "social": "Social",
            "social functioning": "Social",
            "socializing": "Social",
            "sleep": "Sleep",
            "sleeping": "Sleep",
            "routine": "Routine",
            "daily routine": "Routine",
            "daily activities": "Routine",
        }

        selected_impacts = []
        for keyword, chip in impact_mapping.items():
            if keyword in impact_text and chip not in selected_impacts:
                selected_impacts.append(chip)

        if selected_impacts:
            popup.impact_widget.set_selected(selected_impacts)
            print(f"[IMPORT] Set impacts: {selected_impacts}")

    # Update the preview
    if hasattr(popup, 'update_preview'):
        popup.update_preview()


def populate_hpc_popup(popup, text: str):
    """
    Populate History of Presenting Complaint popup from imported text.
    """
    from datetime import datetime
    text_lower = text.lower()

    # ========================================
    # ONSET COMBO
    # ========================================
    onset_patterns = {
        "gradual": "Gradual",
        "slow": "Slow",
        "over months": "Over months",
        "over several months": "Over months",
        "sudden": "Sudden",
        "unclear": "Unclear",
        "insidious": "Gradual",
        "acute": "Sudden",
    }

    if hasattr(popup, 'onset_combo'):
        for pattern, value in onset_patterns.items():
            if pattern in text_lower:
                for i in range(popup.onset_combo.count()):
                    if popup.onset_combo.itemText(i) == value:
                        popup.onset_combo.setCurrentIndex(i)
                        print(f"[IMPORT] Set HPC onset: {value}")
                        break
                break

    # ========================================
    # TRIGGERS - chips are: Stress, Work, Relationship, Health, Medication, Substance
    # ========================================
    trigger_match = re.search(
        r"(?:triggers?\s+(?:appear\s+to\s+)?include|triggered\s+by|precipitated\s+by)\s+([^.]+)",
        text, re.IGNORECASE
    )
    if trigger_match and hasattr(popup, 'trigger_group'):
        trigger_text = trigger_match.group(1).lower()
        print(f"[IMPORT] Found trigger text: '{trigger_text}'")

        # Map text to actual chip labels
        trigger_mapping = {
            "stress": "Stress",
            "work": "Work",
            "job": "Work",
            "employment": "Work",
            "relationship": "Relationship",
            "relationships": "Relationship",
            "family": "Relationship",
            "marriage": "Relationship",
            "partner": "Relationship",
            "health": "Health",
            "physical": "Health",
            "illness": "Health",
            "medical": "Health",
            "medication": "Medication",
            "drug": "Medication",
            "substance": "Substance",
            "alcohol": "Substance",
            "cannabis": "Substance",
        }

        selected_triggers = []
        for keyword, chip in trigger_mapping.items():
            if keyword in trigger_text and chip not in selected_triggers:
                selected_triggers.append(chip)

        if selected_triggers:
            popup.trigger_group.set_selected(selected_triggers)
            print(f"[IMPORT] Set HPC triggers: {selected_triggers}")

    # ========================================
    # DATES - First noticed and Became severe
    # Pattern: "first noticed around DD Mon YYYY" or "Symptoms were first noticed around"
    # ========================================
    date_patterns = [
        r"first\s+noticed\s+(?:around\s+)?(\d{1,2}\s+\w+\s+\d{4})",
        r"symptoms\s+(?:were\s+)?first\s+noticed\s+(?:around\s+)?(\d{1,2}\s+\w+\s+\d{4})",
        r"started\s+(?:around\s+)?(\d{1,2}\s+\w+\s+\d{4})",
    ]
    for pattern in date_patterns:
        date_match = re.search(pattern, text, re.IGNORECASE)
        if date_match and hasattr(popup, 'date_first_noticed'):
            try:
                date_str = date_match.group(1)
                dt = datetime.strptime(date_str, "%d %b %Y")
                popup.date_first_noticed.set_date(dt.date())
                print(f"[IMPORT] Set HPC first noticed date: {date_str}")
                break
            except ValueError:
                pass

    severe_patterns = [
        r"became\s+(?:more\s+)?severe\s+(?:around\s+)?(\d{1,2}\s+\w+\s+\d{4})",
        r"worsened\s+(?:around\s+)?(\d{1,2}\s+\w+\s+\d{4})",
    ]
    for pattern in severe_patterns:
        date_match = re.search(pattern, text, re.IGNORECASE)
        if date_match and hasattr(popup, 'date_became_severe'):
            try:
                date_str = date_match.group(1)
                dt = datetime.strptime(date_str, "%d %b %Y")
                popup.date_became_severe.set_date(dt.date())
                print(f"[IMPORT] Set HPC became severe date: {date_str}")
                break
            except ValueError:
                pass

    # ========================================
    # COURSE - radio options: "Getting worse", "Improving", "Fluctuating",
    #          "Relapsing–remitting", "Chronic / unchanged"
    # ========================================
    course_match = re.search(
        r"course\s+(?:has\s+been|is|was)\s+([^.]+)",
        text, re.IGNORECASE
    )
    if course_match and hasattr(popup, 'course_group'):
        course_text = course_match.group(1).lower()
        print(f"[IMPORT] Found course text: '{course_text}'")

        course_mapping = {
            "getting worse": "Getting worse",
            "deteriorating": "Getting worse",
            "worsening": "Getting worse",
            "improving": "Improving",
            "better": "Improving",
            "fluctuating": "Fluctuating",
            "variable": "Fluctuating",
            "relapsing": "Relapsing–remitting",
            "remitting": "Relapsing–remitting",
            "chronic": "Chronic / unchanged",
            "unchanged": "Chronic / unchanged",
            "stable": "Chronic / unchanged",
        }

        for keyword, value in course_mapping.items():
            if keyword in course_text:
                popup.course_group.set_selected([value])
                print(f"[IMPORT] Set HPC course: {value}")
                break

    # ========================================
    # EPISODE NUMBER
    # ========================================
    episode_match = re.search(
        r"episode\s+(?:number\s+)?(\d+)|(\d+)(?:st|nd|rd|th)\s+episode|this\s+is\s+(?:the\s+)?(\d+)(?:st|nd|rd|th)",
        text, re.IGNORECASE
    )
    if episode_match and hasattr(popup, 'episode_number'):
        ep_num = episode_match.group(1) or episode_match.group(2) or episode_match.group(3)
        if ep_num:
            popup.episode_number.edit.setText(ep_num)
            print(f"[IMPORT] Set HPC episode number: {ep_num}")

    # ========================================
    # RISKS - checkboxes: "Suicidal thoughts", "Self-harm", "Harm to others",
    #         "Neglect", "Vulnerability", "None reported"
    # ========================================
    if hasattr(popup, 'risk_categories'):
        risk_mapping = {
            "suicidal": "Suicidal thoughts",
            "suicide": "Suicidal thoughts",
            "self-harm": "Self-harm",
            "self harm": "Self-harm",
            "cutting": "Self-harm",
            "overdose": "Self-harm",
            "harm to others": "Harm to others",
            "violence": "Harm to others",
            "aggression": "Harm to others",
            "neglect": "Neglect",
            "self-neglect": "Neglect",
            "vulnerable": "Vulnerability",
            "vulnerability": "Vulnerability",
            "no risk": "None reported",
            "no current risk": "None reported",
            "denies risk": "None reported",
            "reports no": "None reported",
        }

        selected_risks = []
        for keyword, value in risk_mapping.items():
            if keyword in text_lower and value not in selected_risks:
                selected_risks.append(value)

        # If "None reported" is selected, don't select others
        if "None reported" in selected_risks:
            selected_risks = ["None reported"]

        if selected_risks:
            popup.risk_categories.set_selected(selected_risks)
            print(f"[IMPORT] Set HPC risks: {selected_risks}")

    # Risk frequency
    freq_match = re.search(r"frequency[:\s]+([^.]+)", text, re.IGNORECASE)
    if freq_match and hasattr(popup, 'risk_frequency'):
        popup.risk_frequency.edit.setText(freq_match.group(1).strip())
        print(f"[IMPORT] Set HPC risk frequency")

    # Risk intensity
    intensity_match = re.search(r"intensity[:\s]+([^.]+)", text, re.IGNORECASE)
    if intensity_match and hasattr(popup, 'risk_intensity'):
        popup.risk_intensity.edit.setText(intensity_match.group(1).strip())
        print(f"[IMPORT] Set HPC risk intensity")

    # Risk intent
    intent_match = re.search(r"intent[:\s]+([^.]+)", text, re.IGNORECASE)
    if intent_match and hasattr(popup, 'risk_intent'):
        popup.risk_intent.edit.setText(intent_match.group(1).strip())
        print(f"[IMPORT] Set HPC risk intent")

    # Risk protective factors
    protective_match = re.search(r"protective\s+factors?[:\s]+([^.]+)", text, re.IGNORECASE)
    if protective_match and hasattr(popup, 'risk_protective'):
        popup.risk_protective.edit.setPlainText(protective_match.group(1).strip())
        print(f"[IMPORT] Set HPC protective factors")

    # ========================================
    # PAST EPISODES - checkboxes: "Previous similar episodes", "Previous admissions",
    #         "Crisis team involvement", "Past self-harm/suicide attempts", "Past violence/aggression"
    # ========================================
    if hasattr(popup, 'past_flags'):
        past_mapping = {
            "previous similar episode": "Previous similar episodes",
            "previous episode": "Previous similar episodes",
            "similar episodes": "Previous similar episodes",
            "previous admission": "Previous admissions",
            "past admission": "Previous admissions",
            "hospital admission": "Previous admissions",
            "psychiatric admission": "Previous admissions",
            "crisis team": "Crisis team involvement",
            "crisis intervention": "Crisis team involvement",
            "home treatment": "Crisis team involvement",
            "past self-harm": "Past self-harm/suicide attempts",
            "previous self-harm": "Past self-harm/suicide attempts",
            "past suicide attempt": "Past self-harm/suicide attempts",
            "previous suicide attempt": "Past self-harm/suicide attempts",
            "history of self-harm": "Past self-harm/suicide attempts",
            "past violence": "Past violence/aggression",
            "previous violence": "Past violence/aggression",
            "history of aggression": "Past violence/aggression",
            "past aggression": "Past violence/aggression",
        }

        selected_past = []
        for keyword, value in past_mapping.items():
            if keyword in text_lower and value not in selected_past:
                selected_past.append(value)

        if selected_past:
            popup.past_flags.set_selected(selected_past)
            print(f"[IMPORT] Set HPC past flags: {selected_past}")

    # Past treatment
    treatment_match = re.search(
        r"(?:previous\s+treatment|previously\s+treated|past\s+treatment)[:\s]+([^.]+)",
        text, re.IGNORECASE
    )
    if treatment_match and hasattr(popup, 'past_treatment'):
        treatment_text = treatment_match.group(1).strip()
        popup.past_treatment.edit.setPlainText(treatment_text)
        print(f"[IMPORT] Set HPC past treatment: {treatment_text}")

    # ========================================
    # EXPLANATORY MODEL - chips: "Stress", "Chemical", "Trauma",
    #                     "Physical", "Social", "Uncertain"
    # Pattern: "understands the symptoms as stress-related, chemical imbalance"
    # ========================================
    model_match = re.search(
        r"(?:understand[s]?\s+(?:the\s+)?symptoms?\s+as|attribute[s]?\s+(?:the\s+)?symptoms?\s+to|explain[s]?\s+(?:the\s+)?symptoms?\s+as)\s+([^.]+)",
        text, re.IGNORECASE
    )
    if model_match and hasattr(popup, 'model_chips'):
        model_text = model_match.group(1).lower()
        print(f"[IMPORT] Found explanatory model text: '{model_text}'")

        model_mapping = {
            "stress-related": "Stress",
            "stress related": "Stress",
            "stress": "Stress",
            "chemical imbalance": "Chemical",
            "chemical": "Chemical",
            "imbalance": "Chemical",
            "biological": "Chemical",
            "trauma-related": "Trauma",
            "trauma related": "Trauma",
            "trauma": "Trauma",
            "traumatic": "Trauma",
            "physical health": "Physical",
            "physical": "Physical",
            "medical": "Physical",
            "social or situational": "Social",
            "social": "Social",
            "situational": "Social",
            "life events": "Social",
            "uncertain": "Uncertain",
            "unsure": "Uncertain",
            "unclear": "Uncertain",
        }

        selected_models = []
        for keyword, value in model_mapping.items():
            if keyword in model_text and value not in selected_models:
                selected_models.append(value)

        if selected_models:
            popup.model_chips.set_selected(selected_models)
            print(f"[IMPORT] Set HPC explanatory model: {selected_models}")

    # ========================================
    # COLLATERAL - radio: "Present", "Telephone", "None obtained"
    # Pattern: "Collateral: collateral present, telephone collateral"
    # ========================================
    collateral_match = re.search(
        r"collateral[:\s]+([^.]+)",
        text, re.IGNORECASE
    )
    if collateral_match and hasattr(popup, 'collateral_type'):
        collateral_text = collateral_match.group(1).lower()
        print(f"[IMPORT] Found collateral text: '{collateral_text}'")

        # These are radio buttons so only one can be selected
        if "no collateral" in collateral_text or "none obtained" in collateral_text:
            popup.collateral_type.set_selected(["None obtained"])
            print(f"[IMPORT] Set HPC collateral: None obtained")
        elif "telephone" in collateral_text:
            popup.collateral_type.set_selected(["Telephone"])
            print(f"[IMPORT] Set HPC collateral: Telephone")
        elif "present" in collateral_text or "collateral present" in collateral_text:
            popup.collateral_type.set_selected(["Present"])
            print(f"[IMPORT] Set HPC collateral: Present")

    # Carer concerns
    carer_match = re.search(
        r"carer\s+concerns?[:\s]+([^.]+)",
        text, re.IGNORECASE
    )
    if carer_match and hasattr(popup, 'collateral_concerns'):
        popup.collateral_concerns.edit.setPlainText(carer_match.group(1).strip())
        print(f"[IMPORT] Set HPC carer concerns")

    # Update preview if available
    if hasattr(popup, 'update_preview'):
        popup.update_preview()


def populate_affect_popup(popup, text: str):
    """
    Populate Affect popup from imported text.

    The popup stores values as: self.values[label] = (slider_value, details)
    - Depression sliders: 0-100 where 50=normal, <50=low, >50=high
    - Mania sliders: 0-100 where 0-33=mild, 34-66=moderate, 67-100=severe
    """
    text_lower = text.lower()

    # ========================================
    # DEPRESSION FEATURES
    # ========================================

    # Mood patterns
    if "very low in mood" in text_lower or "significantly low" in text_lower:
        popup.values["Mood"] = (10, "")
    elif "low in mood" in text_lower:
        popup.values["Mood"] = (25, "")
    elif "mildly low in mood" in text_lower:
        popup.values["Mood"] = (40, "")
    elif "mood was normal" in text_lower:
        popup.values["Mood"] = (50, "")
    elif "slightly elevated" in text_lower:
        popup.values["Mood"] = (60, "")
    elif "mood was elevated" in text_lower or "elevated mood" in text_lower:
        popup.values["Mood"] = (75, "")
    elif "significantly elevated" in text_lower:
        popup.values["Mood"] = (90, "")

    # Energy patterns
    if "very low energy" in text_lower:
        popup.values["Energy"] = (10, "")
    elif "low energy" in text_lower:
        popup.values["Energy"] = (25, "")
    elif "mildly reduced energy" in text_lower:
        popup.values["Energy"] = (40, "")
    elif "energy was normal" in text_lower:
        popup.values["Energy"] = (50, "")
    elif "slightly increased energy" in text_lower:
        popup.values["Energy"] = (60, "")
    elif "increased energy" in text_lower:
        popup.values["Energy"] = (75, "")
    elif "significantly increased energy" in text_lower:
        popup.values["Energy"] = (90, "")

    # Anhedonia patterns
    if "significant anhedonia" in text_lower:
        popup.values["Anhedonia"] = (90, "")
    elif "moderate anhedonia" in text_lower:
        popup.values["Anhedonia"] = (75, "")
    elif "mild anhedonia" in text_lower:
        popup.values["Anhedonia"] = (60, "")
    elif "no anhedonia" in text_lower:
        popup.values["Anhedonia"] = (50, "")

    # Sleep patterns
    if "sleep was very poor" in text_lower:
        popup.values["Sleep"] = (10, "")
    elif "sleep was poor" in text_lower:
        popup.values["Sleep"] = (25, "")
    elif "mildly disrupted" in text_lower:
        popup.values["Sleep"] = (40, "")
    elif "sleep was normal" in text_lower:
        popup.values["Sleep"] = (50, "")
    elif "sleeping slightly more" in text_lower:
        popup.values["Sleep"] = (60, "")
    elif "sleeping significantly more" in text_lower or "oversleeping" in text_lower:
        popup.values["Sleep"] = (85, "")

    # Appetite patterns
    if "appetite was very poor" in text_lower:
        popup.values["Appetite"] = (10, "")
    elif "appetite was poor" in text_lower:
        popup.values["Appetite"] = (25, "")
    elif "eating less than normal" in text_lower:
        popup.values["Appetite"] = (40, "")
    elif "appetite was normal" in text_lower:
        popup.values["Appetite"] = (50, "")
    elif "eating more than normal" in text_lower:
        popup.values["Appetite"] = (60, "")
    elif "overeating" in text_lower:
        popup.values["Appetite"] = (80, "")

    # Libido patterns
    if "sex drive was absent" in text_lower:
        popup.values["Libido"] = (5, "")
    elif "sex drive was significantly reduced" in text_lower:
        popup.values["Libido"] = (20, "")
    elif "sex drive was mildly reduced" in text_lower:
        popup.values["Libido"] = (40, "")
    elif "sex drive was normal" in text_lower:
        popup.values["Libido"] = (50, "")
    elif "sex drive was mildly increased" in text_lower:
        popup.values["Libido"] = (60, "")
    elif "sex drive was significantly increased" in text_lower or "excessively increased sex drive" in text_lower:
        popup.values["Libido"] = (85, "")

    # Self-esteem patterns
    if "self-esteem was very low" in text_lower:
        popup.values["Self-esteem"] = (10, "")
    elif "self-esteem was low" in text_lower:
        popup.values["Self-esteem"] = (25, "")
    elif "self-esteem was mildly reduced" in text_lower:
        popup.values["Self-esteem"] = (40, "")
    elif "self-esteem was normal" in text_lower:
        popup.values["Self-esteem"] = (50, "")
    elif "self-esteem was slightly increased" in text_lower:
        popup.values["Self-esteem"] = (60, "")
    elif "self-esteem was increased" in text_lower:
        popup.values["Self-esteem"] = (75, "")
    elif "self-esteem was significantly increased" in text_lower:
        popup.values["Self-esteem"] = (90, "")

    # Concentration patterns
    if "complete inability to concentrate" in text_lower:
        popup.values["Concentration"] = (5, "")
    elif "significant difficulty concentrating" in text_lower:
        popup.values["Concentration"] = (20, "")
    elif "concentration was mildly disturbed" in text_lower:
        popup.values["Concentration"] = (40, "")
    elif "concentration was normal" in text_lower:
        popup.values["Concentration"] = (50, "")
    elif "concentration was above normal" in text_lower:
        popup.values["Concentration"] = (60, "")
    elif "increased concentration" in text_lower:
        popup.values["Concentration"] = (75, "")

    # Guilt patterns
    if "overwhelming feelings of guilt" in text_lower:
        popup.values["Guilt"] = (90, "")
    elif "moderate feelings of guilt" in text_lower:
        popup.values["Guilt"] = (75, "")
    elif "some feelings of guilt" in text_lower:
        popup.values["Guilt"] = (60, "")
    elif "no feelings of guilt" in text_lower:
        popup.values["Guilt"] = (50, "")

    # Hopelessness patterns
    if "overwhelming feelings of hopelessness" in text_lower:
        popup.values["Hopelessness / Helplessness"] = (90, "")
    elif "moderate feelings of hopelessness" in text_lower:
        popup.values["Hopelessness / Helplessness"] = (75, "")
    elif "some feelings of hopelessness" in text_lower:
        popup.values["Hopelessness / Helplessness"] = (60, "")
    elif "no feelings of hopelessness" in text_lower or "no hopelessness" in text_lower:
        popup.values["Hopelessness / Helplessness"] = (50, "")

    # Suicidal thoughts patterns
    if "overwhelming suicidal thoughts" in text_lower:
        popup.values["Suicidal thoughts"] = (90, "")
    elif "moderate suicidal thoughts" in text_lower:
        popup.values["Suicidal thoughts"] = (75, "")
    elif "fleeting suicidal thoughts" in text_lower:
        popup.values["Suicidal thoughts"] = (60, "")
    elif "no suicidal thoughts" in text_lower:
        popup.values["Suicidal thoughts"] = (50, "")

    # ========================================
    # MANIC FEATURES
    # Mania sliders: 0-33=mild, 34-66=moderate, 67-100=severe
    # ========================================

    # Helper to extract mania symptoms with severity
    mania_symptoms = {
        "heightened perception": "Heightened perception",
        "psychomotor activity": "Psychomotor activity",
        "increased psychomotor activity": "Psychomotor activity",
        "pressure of speech": "Pressure of speech",
        "disinhibition": "Disinhibition",
        "distractibility": "Distractibility",
        "irritability": "Irritability",
        "overspending": "Overspending",
    }

    # Look for patterns like "pressure of speech (severe)" or "severe pressure of speech"
    for symptom_text, symptom_label in mania_symptoms.items():
        # Pattern: "symptom (severity)"
        pattern1 = re.search(rf"{symptom_text}\s*\((\w+)\)", text_lower)
        # Pattern: "severity symptom"
        pattern2 = re.search(rf"(mild|moderate|severe)\s+{symptom_text}", text_lower)
        # Pattern: "there was mild/moderate/severe symptom"
        pattern3 = re.search(rf"there was\s+(mild|moderate|severe)\s+(?:increase in\s+)?{symptom_text}", text_lower)

        severity = None
        if pattern1:
            severity = pattern1.group(1)
        elif pattern2:
            severity = pattern2.group(1)
        elif pattern3:
            severity = pattern3.group(1)

        if severity:
            if severity == "mild":
                popup.values[symptom_label] = (20, "")
            elif severity == "moderate":
                popup.values[symptom_label] = (50, "")
            elif severity == "severe":
                popup.values[symptom_label] = (85, "")
            print(f"[IMPORT] Set Affect {symptom_label}: {severity}")

    # Count how many values were set
    count = len(popup.values)
    if count > 0:
        print(f"[IMPORT] Populated Affect popup with {count} values")

    # Refresh UI
    if hasattr(popup, '_update_all'):
        popup._update_all()
    if hasattr(popup, '_refresh_row_highlights'):
        popup._refresh_row_highlights()


def populate_anxiety_popup(popup, text: str):
    """
    Populate Anxiety popup from imported text.

    Handles three modes:
    - Anxiety/Panic/Phobia: symptoms with severity, panic attacks, phobias
    - OCD: thoughts, compulsions, associated features
    - PTSD: precipitating events, recurrent symptoms, associated features
    """
    # Strip markdown bold markers before processing
    text = re.sub(r'\*\*', '', text)
    text_lower = text.lower()

    # ========================================
    # ANXIETY/PANIC/PHOBIA SYMPTOMS
    # ========================================
    anxiety_symptoms = [
        "palpitations", "breathing difficulty", "dry mouth", "sweating",
        "shaking", "chest pain", "chest discomfort", "hot flashes", "cold chills",
        "concentration issues", "being irritable", "irritable", "numbness", "tingling",
        "restlessness", "dizzy", "faint", "nausea", "abdo distress",
        "swallowing difficulties", "choking", "on edge", "increased startle",
        "muscle tension", "muscle aches", "initial insomnia", "fear of dying",
        "fear of losing control", "depersonalisation", "derealisation"
    ]

    # Map text patterns to actual symptom labels
    symptom_mapping = {
        "palpitations": "palpitations",
        "breathing difficulty": "breathing difficulty",
        "dry mouth": "dry mouth",
        "having a dry mouth": "dry mouth",
        "sweating": "sweating",
        "shaking": "shaking",
        "chest pain": "chest pain/discomfort",
        "chest discomfort": "chest pain/discomfort",
        "hot flashes": "hot flashes/cold chills",
        "cold chills": "hot flashes/cold chills",
        "concentration issues": "concentration issues",
        "being irritable": "being irritable",
        "irritable": "being irritable",
        "numbness": "numbness/tingling",
        "tingling": "numbness/tingling",
        "restlessness": "restlessness",
        "dizzy": "dizzy/faint",
        "faint": "dizzy/faint",
        "nausea": "nausea/abdo distress",
        "abdo distress": "nausea/abdo distress",
        "swallowing difficulties": "swallowing difficulties",
        "choking": "choking",
        "on edge": "on edge",
        "feeling on edge": "on edge",
        "increased startle": "increased startle",
        "muscle tension": "muscle tension/aches",
        "muscle aches": "muscle tension/aches",
        "initial insomnia": "initial insomnia",
        "fear of dying": "Fear of dying",
        "a fear of dying": "Fear of dying",
        "and of dying": "Fear of dying",
        "of dying": "Fear of dying",
        "fear of losing control": "Fear of losing control",
        "a fear of losing control": "Fear of losing control",
        "losing control and of dying": "Fear of dying",
        "depersonalisation": "depersonalisation/derealisation",
        "derealisation": "depersonalisation/derealisation",
    }

    # Determine default severity from text
    default_severity = 2  # moderate
    if "predominantly severe" in text_lower:
        default_severity = 3
    elif "predominantly mild" in text_lower:
        default_severity = 1
    elif "all severe" in text_lower:
        default_severity = 3
    elif "all mild" in text_lower:
        default_severity = 1

    # Special handling for combined "fear of losing control and of dying"
    if "a fear of losing control and of dying" in text_lower:
        popup.values.setdefault("Anxiety/Panic/Phobia", {})
        popup.values["Anxiety/Panic/Phobia"]["Fear of losing control"] = (default_severity, "")
        popup.values["Anxiety/Panic/Phobia"]["Fear of dying"] = (default_severity, "")
        print("[IMPORT] Set both Fear of losing control AND Fear of dying")

    # Find mentioned symptoms
    found_symptoms = []
    for pattern, label in symptom_mapping.items():
        if pattern in text_lower and label not in found_symptoms:
            found_symptoms.append(label)

    # Set values for found symptoms
    if found_symptoms:
        popup.values.setdefault("Anxiety/Panic/Phobia", {})
        for symptom in found_symptoms:
            popup.values["Anxiety/Panic/Phobia"][symptom] = (default_severity, "")
        print(f"[IMPORT] Set Anxiety symptoms: {found_symptoms} (severity {default_severity})")

    # ========================================
    # PANIC ATTACKS
    # ========================================
    panic_match = re.search(r"(mild|moderate|severe)\s+panic(?:\s+attacks)?", text_lower)
    if panic_match:
        popup.panic_associated = True
        popup.panic_severity = panic_match.group(1)
        # Update UI controls
        if hasattr(popup, 'panic_checkbox'):
            popup.panic_checkbox.setChecked(True)
        if hasattr(popup, 'panic_severity_combo'):
            popup.panic_severity_combo.setCurrentText(popup.panic_severity)
            popup.panic_severity_combo.setVisible(True)
        print(f"[IMPORT] Set panic attacks: {popup.panic_severity}")

    # ========================================
    # PHOBIAS/AVOIDANCE
    # ========================================
    phobia_patterns = {
        "agoraphobia": "Agoraphobia",
        "specific phobia": "Specific phobia",
        "social phobia": "Social phobia",
        "hypochondriacal": "Hypochondriacal",
    }

    for pattern, phobia_type in phobia_patterns.items():
        phobia_match = re.search(rf"(mild|moderate|severe)\s+{pattern}", text_lower)
        if phobia_match:
            popup.avoidance_associated = True
            popup.avoidance_phobia_type = phobia_type
            popup.avoidance_severity = phobia_match.group(1)

            # Detect phobia sub-symptoms FIRST (before setting UI controls)
            # Match against PHOBIA_SUB_PHRASES exported text
            phobia_sub_patterns = {
                "Agoraphobia": {
                    "anxious in crowded places": "crowds",
                    "crowded places": "crowds",
                    "avoidant of public places": "public places",
                    "public places": "public places",
                    "not liking travelling alone": "travelling alone",
                    "travelling alone": "travelling alone",
                    "anxious when leaving home": "travel away from home",
                    "leaving home": "travel away from home",
                },
                "Specific phobia": {
                    "animals": "animals",
                    "sight of blood": "blood",
                    "exams": "exams",
                    "small spaces": "small spaces",
                },
                "Social phobia": {
                    "anxiety mainly in the presence of others": "social situations",
                    "presence of others": "social situations",
                },
                "Hypochondriacal": {
                    "fears of having heart disease": "heart disease",
                    "heart disease": "heart disease",
                    "distorted belief about body shape": "body shape (dysmorphic)",
                    "dysmorphic": "body shape (dysmorphic)",
                    "concerns about a specific organ": "specific",
                    "being worried about having cancer": "organ cancer",
                    "worried about having cancer": "organ cancer",
                },
            }

            # Add sub-symptoms to the set BEFORE UI controls trigger signals
            if phobia_type in phobia_sub_patterns:
                for sub_pattern, sub_symptom in phobia_sub_patterns[phobia_type].items():
                    if sub_pattern in text_lower:
                        popup.phobia_sub_selected.add(sub_symptom)
                        print(f"[IMPORT] Set phobia sub-symptom: {sub_symptom}")

            # NOW update UI controls (after sub-symptoms are in the set)
            if hasattr(popup, 'avoidance_checkbox'):
                popup.avoidance_checkbox.setChecked(True)
            if hasattr(popup, 'phobia_type_combo'):
                popup.phobia_type_combo.setVisible(True)
                popup.phobia_type_combo.setCurrentText(phobia_type)
            if hasattr(popup, 'avoidance_severity_combo'):
                popup.avoidance_severity_combo.setCurrentText(popup.avoidance_severity)
                popup.avoidance_severity_combo.setVisible(True)
            if hasattr(popup, 'phobia_severity_label'):
                popup.phobia_severity_label.setVisible(True)

            print(f"[IMPORT] Set phobia: {phobia_type} ({popup.avoidance_severity})")
            break

    # ========================================
    # OCD - Thoughts
    # ========================================
    ocd_thoughts = {
        "obsessive impulses": "impulses",
        "obsessional impulses": "impulses",
        "obsessional ideas": "ideas",
        "recurrent obsessional ideas": "ideas",
        "magical thinking": "magical thoughts",
        "recurrent intrusive imagery": "images",
        "intrusive imagery": "images",
        "excessive rumination": "ruminations",
        "rumination": "ruminations",
    }

    for pattern, thought_type in ocd_thoughts.items():
        if pattern in text_lower:
            popup.ocd_values.setdefault("Thoughts", set())
            popup.ocd_values["Thoughts"].add(thought_type)
            print(f"[IMPORT] Set OCD thought: {thought_type}")

    # ========================================
    # OCD - Compulsions
    # ========================================
    ocd_compulsions = {
        "obsessional slowness": "obsessional slowness",
        "compulsions took a long time": "obsessional slowness",
        "checking gas": "gas/elec checking",
        "checking electrics": "gas/elec checking",
        "gas/elec checking": "gas/elec checking",
        "lock-checking": "lock-checking",
        "lock checking": "lock-checking",
        "excessive lock": "lock-checking",
        "overcleaning": "cleaning",
        "cleaning": "cleaning",
        "handwashing": "handwashing",
        "compulsive handwashing": "handwashing",
    }

    for pattern, compulsion_type in ocd_compulsions.items():
        if pattern in text_lower:
            popup.ocd_values.setdefault("Compulsions", set())
            popup.ocd_values["Compulsions"].add(compulsion_type)
            print(f"[IMPORT] Set OCD compulsion: {compulsion_type}")

    # ========================================
    # OCD - Associated with
    # ========================================
    ocd_associated = {
        "sense of fear": "fear",
        "feeling of relief": "relief/contentment",
        "significant distress": "distress",
        "depersonalisation/derealisation": "depers/dereal",
        "feeling unreal": "depers/dereal",
        "tries to resist": "tries to resist",
        "recognising the thoughts": "recognised as own thoughts",
    }

    for pattern, assoc_type in ocd_associated.items():
        if pattern in text_lower:
            popup.ocd_values.setdefault("Associated with", set())
            popup.ocd_values["Associated with"].add(assoc_type)
            print(f"[IMPORT] Set OCD associated: {assoc_type}")

    # ========================================
    # OCD - Comorbid depression prominence
    # ========================================
    if "depression that was less prominent" in text_lower:
        popup.ocd_values.setdefault("Comorbid depression prominence", set())
        popup.ocd_values["Comorbid depression prominence"].add("less")
        print("[IMPORT] Set OCD depression prominence: less")
    elif "depression that was equally prominent" in text_lower:
        popup.ocd_values.setdefault("Comorbid depression prominence", set())
        popup.ocd_values["Comorbid depression prominence"].add("equal")
        print("[IMPORT] Set OCD depression prominence: equal")
    elif "depression that was more prominent" in text_lower:
        popup.ocd_values.setdefault("Comorbid depression prominence", set())
        popup.ocd_values["Comorbid depression prominence"].add("more")
        print("[IMPORT] Set OCD depression prominence: more")

    # ========================================
    # OCD - Organic mental disorder
    # ========================================
    if "organic mental disorder was present" in text_lower:
        popup.ocd_values.setdefault("Organic mental disorder", set())
        popup.ocd_values["Organic mental disorder"].add("present")
        print("[IMPORT] Set OCD organic mental disorder: present")
    elif "organic mental disorder was absent" in text_lower:
        popup.ocd_values.setdefault("Organic mental disorder", set())
        popup.ocd_values["Organic mental disorder"].add("absent")
        print("[IMPORT] Set OCD organic mental disorder: absent")

    # ========================================
    # OCD - Schizophrenia
    # ========================================
    if "schizophrenia was present" in text_lower:
        popup.ocd_values.setdefault("Schizophrenia", set())
        popup.ocd_values["Schizophrenia"].add("present")
        print("[IMPORT] Set OCD schizophrenia: present")
    elif "schizophrenia was absent" in text_lower:
        popup.ocd_values.setdefault("Schizophrenia", set())
        popup.ocd_values["Schizophrenia"].add("absent")
        print("[IMPORT] Set OCD schizophrenia: absent")

    # ========================================
    # OCD - Tourette's
    # ========================================
    if "comorbid tourette" in text_lower and "was noted" in text_lower:
        popup.ocd_values.setdefault("Tourette's", set())
        popup.ocd_values["Tourette's"].add("present")
        print("[IMPORT] Set OCD Tourette's: present")
    elif "no comorbid tourette" in text_lower:
        popup.ocd_values.setdefault("Tourette's", set())
        popup.ocd_values["Tourette's"].add("absent")
        print("[IMPORT] Set OCD Tourette's: absent")

    # ========================================
    # PTSD - Precipitating event
    # ========================================
    ptsd_events = {
        "accidental trauma": "accidental",
        "ongoing trauma": "current",
        "ongoing abuse": "current",
        "current trauma": "current",
        "past trauma": "historical",
        "historical trauma": "historical",
        "past abuse": "historical",
    }

    for pattern, event_type in ptsd_events.items():
        if pattern in text_lower:
            popup.ptsd_values.setdefault("Precipitating event", set())
            popup.ptsd_values["Precipitating event"].add(event_type)
            print(f"[IMPORT] Set PTSD event: {event_type}")

    # ========================================
    # PTSD - Recurrent symptoms
    # ========================================
    ptsd_recurrent = {
        "flashbacks": "flashbacks",
        "video-like flashbacks": "flashbacks",
        "vivid flashbacks": "flashbacks",
        "recurrent imagery": "imagery",
        "imagery of the events": "imagery",
        "intense memories": "intense memories",
        "overwhelming memories": "intense memories",
        "nightmares": "nightmares",
        "distressing nightmares": "nightmares",
    }

    for pattern, symptom_type in ptsd_recurrent.items():
        if pattern in text_lower:
            popup.ptsd_values.setdefault("Recurrent symptoms", set())
            popup.ptsd_values["Recurrent symptoms"].add(symptom_type)
            print(f"[IMPORT] Set PTSD recurrent: {symptom_type}")

    # ========================================
    # PTSD - Onset
    # ========================================
    if "within six months" in text_lower:
        popup.ptsd_values.setdefault("Onset", set())
        popup.ptsd_values["Onset"].add("within six months")
        print("[IMPORT] Set PTSD onset: within six months")

    # ========================================
    # PTSD - Associated with
    # ========================================
    ptsd_associated = {
        "significant distress": "distress",
        "distress on discussion": "distress",
        "feelings of anxiety": "hyperarousal",
        "panic on recall": "hyperarousal",
        "hyperarousal": "hyperarousal",
        "avoidance of sharing": "avoidance",
        "avoidance": "avoidance",
        "recurrent fear": "fear",
        "numbness": "numbness/depersonalisation",
        "depersonalisation around the event": "numbness/depersonalisation",
    }

    for pattern, assoc_type in ptsd_associated.items():
        if pattern in text_lower:
            popup.ptsd_values.setdefault("Associated with", set())
            popup.ptsd_values["Associated with"].add(assoc_type)
            print(f"[IMPORT] Set PTSD associated: {assoc_type}")

    # ========================================
    # Determine which mode to set based on content
    # ========================================
    has_anxiety = bool(popup.values.get("Anxiety/Panic/Phobia"))
    has_ocd = bool(popup.ocd_values.get("Thoughts") or popup.ocd_values.get("Compulsions"))
    has_ptsd = bool(popup.ptsd_values.get("Precipitating event") or popup.ptsd_values.get("Recurrent symptoms"))

    # Set appropriate mode
    if has_ocd:
        popup.set_mode("OCD")
        popup._ocd_started = True
    elif has_ptsd:
        popup.set_mode("PTSD")
        popup._ptsd_started = True
    elif has_anxiety:
        popup.set_mode("Anxiety/Panic/Phobia")

    # Update UI
    if hasattr(popup, '_update_preview'):
        popup._update_preview()
    if hasattr(popup, '_apply_all_highlights'):
        popup._apply_all_highlights()

    print(f"[IMPORT] Anxiety popup populated - Anxiety: {has_anxiety}, OCD: {has_ocd}, PTSD: {has_ptsd}")


def populate_psychosis_popup(popup, text: str):
    """
    Populate Psychosis popup from imported text.

    Handles two modes:
    - Delusions: delusional content, thought interference, passivity phenomena, associated with
    - Hallucinations: auditory, other modalities, associated with

    Values are stored as popup.values with keys like "del|persecutory" or "hal|2nd person"
    """
    text_lower = text.lower()

    # Default severity (2 = moderate)
    default_severity = 2
    if "prominent" in text_lower or "marked" in text_lower or "significant" in text_lower:
        default_severity = 3
    elif "mild" in text_lower:
        default_severity = 1

    # ========================================
    # DELUSIONS - Delusional content
    # ========================================
    delusion_patterns = {
        "persecutory delusions": "persecutory",
        "persecutory": "persecutory",
        "delusions of reference": "reference",
        "reference/misidentification": "reference",
        "misidentification": "reference",
        "delusional perceptions": "delusional perception",
        "delusional perception": "delusional perception",
        "somatic delusions": "somatic",
        "religious delusions": "religious",
        "delusions of mood": "mood/feeling",
        "delusions of affect": "mood/feeling",
        "delusions of guilt": "guilt/worthlessness",
        "guilt/worthlessness": "guilt/worthlessness",
        "delusional jealousy": "infidelity/jealousy",
        "infidelity": "infidelity/jealousy",
        "nihilistic": "nihilistic/negation",
        "delusions of worthlessness": "nihilistic/negation",
        "nihilism": "nihilistic/negation",
        "delusions of grandiosity": "grandiosity",
        "grandiosity": "grandiosity",
        "grandiose": "grandiosity",
    }

    for pattern, key in delusion_patterns.items():
        if pattern in text_lower:
            popup.values[f"del|{key}"] = (default_severity, "")
            print(f"[IMPORT] Set psychosis delusion: {key}")

    # ========================================
    # DELUSIONS - Thought interference
    # ========================================
    thought_patterns = {
        "thought broadcast": "broadcast",
        "thought withdrawal": "withdrawal",
        "thought insertion": "insertion",
    }

    for pattern, key in thought_patterns.items():
        if pattern in text_lower:
            popup.values[f"del|{key}"] = (default_severity, "")
            print(f"[IMPORT] Set psychosis thought interference: {key}")

    # ========================================
    # DELUSIONS - Passivity phenomena
    # ========================================
    passivity_patterns = {
        "external control of thoughts": "thoughts",
        "control of thoughts": "thoughts",
        "external control of actions": "actions",
        "control of actions": "actions",
        "external limb-control": "limbs",
        "limb-control": "limbs",
        "passivity": "limbs",
        "external control of sensations": "sensation",
        "control of sensations": "sensation",
    }

    for pattern, key in passivity_patterns.items():
        if pattern in text_lower:
            popup.values[f"del|{key}"] = (default_severity, "")
            print(f"[IMPORT] Set psychosis passivity: {key}")

    # ========================================
    # DELUSIONS - Associated with (no severity)
    # ========================================
    del_assoc_patterns = {
        "mannerisms": "mannerisms",
        "sense of fear": "fear",
        "fear around these experiences": "fear",
        "thought disorder": "thought disorder",
        "negative symptoms": "negative symptoms",
        "acting on delusions": "acting on delusions",
        "acting on these experiences": "acting on delusions",
        "catatonic": "catatonia",
        "catatonia": "catatonia",
        "overvalued ideas": "overvalued ideas",
        "inappropriate affect": "inappropriate affect",
        "behavioural change": "behaviour change / withdrawal",
        "behaviour change": "behaviour change / withdrawal",
        "withdrawal": "behaviour change / withdrawal",
        "obsessional beliefs": "obsessional beliefs",
    }

    for pattern, key in del_assoc_patterns.items():
        if pattern in text_lower:
            popup.values[f"del|{key}"] = (1, "")  # No severity for associated
            print(f"[IMPORT] Set psychosis delusion associated: {key}")

    # ========================================
    # HALLUCINATIONS - Auditory
    # ========================================
    auditory_patterns = {
        "second-person auditory": "2nd person",
        "2nd person": "2nd person",
        "third-person auditory": "3rd person",
        "3rd person": "3rd person",
        "first-rank": "3rd person",
        "derogatory voices": "derogatory",
        "derogatory": "derogatory",
        "thought echo": "thought echo",
        "command hallucinations": "command",
        "command": "command",
        "running commentary": "running commentary",
        "multiple voices": "multiple voices",
    }

    for pattern, key in auditory_patterns.items():
        if pattern in text_lower:
            popup.values[f"hal|{key}"] = (default_severity, "")
            print(f"[IMPORT] Set psychosis auditory: {key}")

    # ========================================
    # HALLUCINATIONS - Other modalities
    # ========================================
    other_hal_patterns = {
        "visual": "visual",
        "tactile": "tactile",
        "somatic": "somatic",
        "olfactory": "olfactory/taste",
        "gustatory": "olfactory/taste",
    }

    for pattern, key in other_hal_patterns.items():
        if pattern in text_lower:
            popup.values[f"hal|{key}"] = (default_severity, "")
            print(f"[IMPORT] Set psychosis other hallucination: {key}")

    # ========================================
    # HALLUCINATIONS - Associated with (no severity)
    # ========================================
    hal_assoc_patterns = {
        "pseudohallucinations": "pseudohallucinations",
        "pseudo-hallucinations": "pseudohallucinations",
        "sleep-related": "sleep related",
        "hypnagogic": "sleep related",
        "hypnopompic": "sleep related",
        "illusions rather than": "shadows/illusions",
        "shadows": "shadows/illusions",
        "illusions": "shadows/illusions",
        "fear around these perceptions": "fear",
        "acting on hallucinations": "acting on hallucinations",
        "acting on these hallucinations": "acting on hallucinations",
    }

    for pattern, key in hal_assoc_patterns.items():
        if pattern in text_lower:
            popup.values[f"hal|{key}"] = (1, "")  # No severity for associated
            print(f"[IMPORT] Set psychosis hallucination associated: {key}")

    # ========================================
    # Determine which mode to set based on content
    # ========================================
    has_delusions = any(k.startswith("del|") for k in popup.values)
    has_hallucinations = any(k.startswith("hal|") for k in popup.values)

    # Set appropriate mode (prefer delusions if both present)
    if has_delusions:
        popup._set_mode("Delusions")
    elif has_hallucinations:
        popup._set_mode("Hallucinations")

    # Refresh UI
    if hasattr(popup, '_refresh_highlights'):
        popup._refresh_highlights()
    if hasattr(popup, '_update_preview'):
        popup._update_preview()

    print(f"[IMPORT] Psychosis popup populated - Delusions: {has_delusions}, Hallucinations: {has_hallucinations}")


def populate_psych_history_popup(popup, text: str):
    """
    Populate Past Psychiatric History popup from imported text.

    The popup has 4 combo boxes with specific options.
    We match text patterns to find which option to select.
    """
    text_lower = text.lower()

    # The popup has 4 combo boxes stored in popup._rows
    # Index 0: Previous psychiatric contact
    # Index 1: GP contact for psychiatric issues
    # Index 2: Psychiatric medication
    # Index 3: Psychological therapy / counselling

    # ========================================
    # Previous psychiatric contact (combo index 0)
    # ========================================
    psych_contact_patterns = [
        ("never seen a psychiatrist", 1),
        ("did not wish to discuss previous psychiatric", 2),
        ("outpatient in the past but did not attend", 3),
        ("outpatient in the past without psychiatric admission", 4),
        ("outpatient in the past and has had one inpatient", 5),
        ("one inpatient admission", 5),
        ("outpatient in the past and has had several inpatient", 6),
        ("several inpatient admissions", 6),
        ("only had inpatient psychiatric admissions", 7),
    ]

    for pattern, idx in psych_contact_patterns:
        if pattern in text_lower:
            if len(popup._rows) > 0:
                popup._rows[0].setCurrentIndex(idx)
                popup._update_combo_highlight(popup._rows[0])
                print(f"[IMPORT] Set psych history contact: index {idx}")
            break

    # ========================================
    # GP contact for psychiatric issues (combo index 1)
    # ========================================
    gp_contact_patterns = [
        ("never seen their gp for psychiatric", 1),
        ("never seen his gp for psychiatric", 1),
        ("never seen her gp for psychiatric", 1),
        ("did not wish to discuss gp contact", 2),
        ("occasionally seen their gp for psychiatric", 3),
        ("occasionally seen his gp for psychiatric", 3),
        ("occasionally seen her gp for psychiatric", 3),
        ("frequently seen their gp for psychiatric", 4),
        ("frequently seen his gp for psychiatric", 4),
        ("frequently seen her gp for psychiatric", 4),
        ("regular gp contact for psychiatric", 5),
    ]

    for pattern, idx in gp_contact_patterns:
        if pattern in text_lower:
            if len(popup._rows) > 1:
                popup._rows[1].setCurrentIndex(idx)
                popup._update_combo_highlight(popup._rows[1])
                print(f"[IMPORT] Set psych history GP contact: index {idx}")
            break

    # ========================================
    # Psychiatric medication (combo index 2)
    # ========================================
    medication_patterns = [
        ("never taken psychiatric medication", 1),
        ("did not wish to discuss psychiatric medication", 2),
        ("taken psychiatric medication intermittently", 3),
        ("taken psychiatric medication regularly", 4),
        ("currently prescribed psychiatric medication with good adherence", 5),
        ("good adherence", 5),
        ("currently prescribed psychiatric medication with variable adherence", 6),
        ("variable adherence", 6),
        ("currently prescribed psychiatric medication with poor adherence", 7),
        ("poor adherence", 7),
        ("refuses psychiatric medication currently and historically", 8),
        ("refuses psychiatric medication", 8),
    ]

    for pattern, idx in medication_patterns:
        if pattern in text_lower:
            if len(popup._rows) > 2:
                popup._rows[2].setCurrentIndex(idx)
                popup._update_combo_highlight(popup._rows[2])
                print(f"[IMPORT] Set psych history medication: index {idx}")
            break

    # ========================================
    # Psychological therapy / counselling (combo index 3)
    # ========================================
    therapy_patterns = [
        ("did not wish to discuss psychological therapy", 1),
        ("received intermittent psychological therapy", 2),
        ("intermittent psychological therapy", 2),
        ("currently receiving psychological therapy", 3),
        ("received extensive psychological therapy", 4),
        ("extensive psychological therapy", 4),
        ("refuses psychological therapy currently and historically", 5),
        ("refuses psychological therapy", 5),
    ]

    for pattern, idx in therapy_patterns:
        if pattern in text_lower:
            if len(popup._rows) > 3:
                popup._rows[3].setCurrentIndex(idx)
                popup._update_combo_highlight(popup._rows[3])
                print(f"[IMPORT] Set psych history therapy: index {idx}")
            break

    # Update preview
    if hasattr(popup, '_update_preview'):
        popup._update_preview()

    print("[IMPORT] Psychiatric history popup populated")


def populate_drugs_alcohol_popup(popup, text: str):
    """
    Populate Drugs and Alcohol popup from imported text.

    State structure:
    - alcohol: [age_idx, amt_idx]
    - smoking: [age_idx, amt_idx]
    - drugs: {drug_name: {age, amount, active, ever_used}}
    """
    import re
    text_lower = text.lower()

    # Age started mapping
    age_mapping = {
        "early teens": 1,
        "mid-teens": 2,
        "early adulthood": 3,
        "30s and 40s": 4,
        "50s": 5,
        "later adulthood": 6,
    }

    # ========================================
    # ALCOHOL - Extract the alcohol-specific section
    # ========================================
    alcohol_units = {
        "1–5 units": 1, "1-5 units": 1,
        "5–10 units": 2, "5-10 units": 2,
        "10–20 units": 3, "10-20 units": 3,
        "20–35 units": 4, "20-35 units": 4,
        "35–50 units": 5, "35-50 units": 5,
        ">50 units": 6,
    }

    # Extract alcohol section: from "drinking alcohol" to next period or "smoking tobacco"
    alcohol_match = re.search(r'drinking alcohol[^.]*', text_lower)
    if alcohol_match:
        alcohol_section = alcohol_match.group(0)
        print(f"[IMPORT] Alcohol section: {alcohol_section}")

        # Find age started within alcohol section
        for age_text, idx in age_mapping.items():
            if f"starting in {age_text}" in alcohol_section:
                popup.alc_age.slider.setValue(idx)
                print(f"[IMPORT] Set alcohol age: {age_text}")
                break

        # Find amount within alcohol section
        for unit_text, idx in alcohol_units.items():
            if unit_text in alcohol_section:
                popup.alc_amt.slider.setValue(idx)
                print(f"[IMPORT] Set alcohol amount: {unit_text}")
                break

    # ========================================
    # SMOKING - Extract the smoking-specific section
    # ========================================
    smoking_amounts = {
        "1–5 cigarettes": 1, "1-5 cigarettes": 1,
        "5–10 cigarettes": 2, "5-10 cigarettes": 2,
        "10–20 cigarettes": 3, "10-20 cigarettes": 3,
        "20–30 cigarettes": 4, "20-30 cigarettes": 4,
        ">30 cigarettes": 5,
    }

    # Extract smoking section: from "smoking tobacco" to next period
    smoking_match = re.search(r'smoking tobacco[^.]*', text_lower)
    if smoking_match:
        smoking_section = smoking_match.group(0)
        print(f"[IMPORT] Smoking section: {smoking_section}")

        # Find age started within smoking section
        for age_text, idx in age_mapping.items():
            if f"starting in {age_text}" in smoking_section:
                popup.smoke_age.slider.setValue(idx)
                print(f"[IMPORT] Set smoking age: {age_text}")
                break

        # Find amount within smoking section
        for amount_text, idx in smoking_amounts.items():
            if amount_text in smoking_section:
                popup.smoke_amt.slider.setValue(idx)
                print(f"[IMPORT] Set smoking amount: {amount_text}")
                break

    # ========================================
    # DRUGS
    # ========================================
    drug_types = [
        "cannabis", "cocaine", "crack cocaine", "heroin",
        "ecstasy", "mdma", "lsd", "spice", "synthetic cannabinoids",
        "amphetamines", "ketamine", "benzodiazepines"
    ]

    drug_costs = {
        "<£20": 1, "£20–50": 2, "£20-50": 2,
        "£50–100": 3, "£50-100": 3,
        "£100–250": 4, "£100-250": 4,
        ">£250": 5,
    }

    # Map lowercase to actual drug name
    drug_name_map = {
        "cannabis": "Cannabis",
        "cocaine": "Cocaine",
        "crack cocaine": "Crack cocaine",
        "heroin": "Heroin",
        "ecstasy": "Ecstasy (MDMA)",
        "mdma": "Ecstasy (MDMA)",
        "lsd": "LSD",
        "spice": "Spice / synthetic cannabinoids",
        "synthetic cannabinoids": "Spice / synthetic cannabinoids",
        "amphetamines": "Amphetamines",
        "ketamine": "Ketamine",
        "benzodiazepines": "Benzodiazepines",
    }

    for drug_lower in drug_types:
        drug_name = drug_name_map.get(drug_lower)
        if not drug_name or drug_name not in popup.drug_states:
            continue

        # Check for current use
        current_pattern = f"current use of {drug_lower}"
        if current_pattern in text_lower:
            popup.drug_states[drug_name]["active"] = True
            popup.drug_states[drug_name]["ever_used"] = True

            # Find age
            for age_text, idx in age_mapping.items():
                if f"starting in {age_text}" in text_lower:
                    popup.drug_states[drug_name]["age"] = idx
                    break

            # Find cost
            for cost_text, idx in drug_costs.items():
                if f"spending {cost_text}" in text_lower:
                    popup.drug_states[drug_name]["amount"] = idx
                    break

            popup.drug_buttons[drug_name].setChecked(True)
            print(f"[IMPORT] Set drug current use: {drug_name}")

        # Check for previous use
        elif f"previous use of {drug_lower}" in text_lower or f"previously used {drug_lower}" in text_lower:
            popup.drug_states[drug_name]["ever_used"] = True
            popup.drug_states[drug_name]["active"] = False
            print(f"[IMPORT] Set drug previous use: {drug_name}")

    popup._update_preview()
    print("[IMPORT] Drugs and alcohol popup populated")


def populate_social_history_popup(popup, text: str):
    """
    Populate Social History popup from imported text.

    State structure:
    - housing: {type, qualifier}
    - benefits: {none, items}
    - debt: {status, severity_idx, managing}
    """
    text_lower = text.lower()

    # ========================================
    # HOUSING
    # ========================================
    if "currently homeless" in text_lower:
        popup.state["housing"]["type"] = "homeless"
        for rb in popup.housing_type_buttons:
            if rb.text().lower() == "homeless":
                rb.setChecked(True)
                break
        print("[IMPORT] Set housing: homeless")

    elif "living in" in text_lower:
        # Determine type
        if "house" in text_lower:
            popup.state["housing"]["type"] = "house"
            for rb in popup.housing_type_buttons:
                if rb.text().lower() == "house":
                    rb.setChecked(True)
                    break
        elif "flat" in text_lower:
            popup.state["housing"]["type"] = "flat"
            for rb in popup.housing_type_buttons:
                if rb.text().lower() == "flat":
                    rb.setChecked(True)
                    break

        # Determine qualifier
        qualifiers = {
            "own house": "own", "own flat": "own",
            "his own": "own", "her own": "own", "their own": "own",
            "privately rented": "private",
            "council": "council",
            "family": "family",
            "temporary accommodation": "temporary",
        }

        for pattern, qual in qualifiers.items():
            if pattern in text_lower:
                popup.state["housing"]["qualifier"] = qual
                for rb in popup.housing_qual_buttons:
                    if rb.text().lower() == qual:
                        rb.setChecked(True)
                        break
                print(f"[IMPORT] Set housing qualifier: {qual}")
                break

    # ========================================
    # BENEFITS
    # ========================================
    if "did not wish to discuss benefits" in text_lower:
        popup.state["benefits"]["none"] = True
        popup.benefits_none.setChecked(True)
        print("[IMPORT] Set benefits: did not wish to discuss")

    elif "access to" in text_lower:
        benefit_list = [
            "Section 117 aftercare", "ESA", "PIP", "Universal Credit",
            "DLA", "Pension", "Income Support", "Child Tax Credit", "Child Benefit"
        ]

        for benefit in benefit_list:
            if benefit.lower() in text_lower:
                popup.state["benefits"]["items"].add(benefit)
                if benefit in popup.benefit_checks:
                    popup.benefit_checks[benefit].setChecked(True)
                print(f"[IMPORT] Set benefit: {benefit}")

    # ========================================
    # DEBT
    # ========================================
    # Debt severity patterns (in order from the DEBT_SEVERITY list)
    # Check more specific patterns first to avoid false matches
    debt_severity_patterns = [
        ("severely in debt", 4),
        ("significant debt", 3),
        ("some moderate debt", 2),
        ("some small debt", 1),
        ("no significant debt", 0),
    ]

    if "did not wish to discuss financial" in text_lower:
        popup.state["debt"]["status"] = "none"
        popup.debt_status_buttons["none"].setChecked(True)
        print("[IMPORT] Set debt: did not wish to discuss")

    elif "not currently in debt" in text_lower:
        popup.state["debt"]["status"] = "not_in_debt"
        popup.debt_status_buttons["not_in_debt"].setChecked(True)
        print("[IMPORT] Set debt: not in debt")

    else:
        # Check for any debt severity pattern (indicates in_debt status)
        debt_found = False
        for pattern, idx in debt_severity_patterns:
            if pattern in text_lower:
                debt_found = True
                popup.state["debt"]["status"] = "in_debt"
                popup.debt_status_buttons["in_debt"].setChecked(True)
                popup.state["debt"]["severity_idx"] = idx

                # Make slider visible and set value
                popup.debt_slider_slot.setVisible(True)
                popup.debt_slider_panel.setMaximumHeight(56)
                popup.debt_slider_panel.setVisible(True)
                popup.debt_slider.setValue(idx)

                # Make manage panel visible
                popup.debt_manage_panel.setMaximumHeight(48)
                popup.debt_manage_panel.setVisible(True)

                print(f"[IMPORT] Set debt status: in_debt, severity: {pattern} (idx={idx})")
                break

        if debt_found:
            # Determine managing
            if "is managing" in text_lower or "and is managing" in text_lower:
                popup.state["debt"]["managing"] = "managing"
                popup.debt_manage_buttons["managing"].setChecked(True)
                print("[IMPORT] Set debt managing: yes")
            elif "is not managing" in text_lower or "not managing" in text_lower:
                popup.state["debt"]["managing"] = "not_managing"
                popup.debt_manage_buttons["not_managing"].setChecked(True)
                print("[IMPORT] Set debt managing: no")

    popup._update_preview()
    print("[IMPORT] Social history popup populated")


def populate_background_popup(popup, text: str):
    """
    Populate Background History popup from imported text.

    Widget state formats:
    - birth_widget.set_value(str): "normal", "difficult", "premature", "traumatic"
    - milestones_widget.set_value(str): "normal", "mildly delayed", etc.
    - family_history_widget.set_value(str): "none_no_alcohol", "some_with_alcohol", etc.
    - abuse_widget.set_state(dict): {"severity": "none"/"some"/"significant", "types": [...]}
    - schooling_widget.set_state(dict): {"severity": "none"/"some"/"significant", "issues": [...]}
    - qualifications_widget.set_value(str): "none", "gcse_above", "degree", etc.
    - work_history_widget.set_state(dict): {"pattern": "never"/"intermittent"/etc., "last_worked_years": int}
    - sexual_orientation_widget.set_value(str): "heterosexual", "homosexual", etc.
    - children_widget.set_state(dict): {"count": int, "age_band": str, "composition": str}
    - relationships_widget.set_state(dict): {"status": "none"/"relationship"/"married", "duration_years": int}
    """
    text_lower = text.lower()

    # ========================================
    # BIRTH - values: "normal", "difficult", "premature", "traumatic"
    # ========================================
    birth_patterns = [
        ("birth as normal", "normal"),
        ("normal birth", "normal"),
        ("birth was normal", "normal"),
        ("birth as difficult", "difficult"),
        ("difficult birth", "difficult"),
        ("born prematurely", "premature"),
        ("premature birth", "premature"),
        ("birth as traumatic", "traumatic"),
        ("traumatic birth", "traumatic"),
    ]

    for pattern, value in birth_patterns:
        if pattern in text_lower:
            popup.birth_widget.set_value(value)
            popup._sentences["BIRTH"] = popup._apply_pronouns(popup.birth_widget._to_sentence(value))
            print(f"[IMPORT] Set background birth: {value}")
            break

    # ========================================
    # MILESTONES
    # ========================================
    milestone_patterns = [
        ("milestones were normal", "normal"),
        ("normal developmental", "normal"),
        ("mildly delayed", "mildly delayed"),
        ("moderately delayed", "moderately delayed"),
        ("significantly delayed", "significantly delayed"),
        ("delayed in speech and motor", "delayed with concerns about speech and motor function"),
        ("speech and motor", "delayed with concerns about speech and motor function"),
        ("delayed in speech", "delayed with concerns about speech"),
        ("speech delay", "delayed with concerns about speech"),
        ("delayed in motor", "delayed with concerns about motor function"),
        ("motor delay", "delayed with concerns about motor function"),
    ]

    for pattern, value in milestone_patterns:
        if pattern in text_lower:
            popup.milestones_widget.set_value(value)
            popup._sentences["MILESTONES"] = popup._apply_pronouns(popup.milestones_widget._to_sentence())
            print(f"[IMPORT] Set background milestones: {value}")
            break

    # ========================================
    # FAMILY HISTORY
    # ========================================
    has_alcoholism = "alcoholism" in text_lower and "no history of alcoholism" not in text_lower and "no alcoholism" not in text_lower

    family_value = None
    if "no known family history of mental illness" in text_lower or "no family history of mental illness" in text_lower:
        family_value = "none_with_alcohol" if has_alcoholism else "none_no_alcohol"
    elif "significant family history of mental illness" in text_lower:
        family_value = "significant_with_alcohol" if has_alcoholism else "significant_no_alcohol"
    elif "some family history of mental illness" in text_lower:
        family_value = "some_with_alcohol" if has_alcoholism else "some_no_alcohol"

    if family_value:
        popup.family_history_widget.set_value(family_value)
        popup._sentences["FAMILY_HISTORY"] = popup.family_history_widget._to_sentence(family_value)
        print(f"[IMPORT] Set background family history: {family_value}")

    # ========================================
    # ABUSE - state: {"severity": str, "types": list}
    # severity: "none", "some", "significant"
    # types: "emotional", "physical", "sexual", "neglect"
    # ========================================
    abuse_state = {"severity": None, "types": []}

    if "no history of childhood abuse" in text_lower or "described no history of" in text_lower:
        abuse_state["severity"] = "none"
    elif "significant abuse" in text_lower:
        abuse_state["severity"] = "significant"
        # Check for types
        if "emotional" in text_lower:
            abuse_state["types"].append("emotional")
        if "physical" in text_lower:
            abuse_state["types"].append("physical")
        if "sexual" in text_lower:
            abuse_state["types"].append("sexual")
        if "neglect" in text_lower:
            abuse_state["types"].append("neglect")
    elif "some abuse" in text_lower or "history of" in text_lower and "abuse" in text_lower:
        abuse_state["severity"] = "some"
        if "emotional" in text_lower:
            abuse_state["types"].append("emotional")
        if "physical" in text_lower:
            abuse_state["types"].append("physical")
        if "sexual" in text_lower:
            abuse_state["types"].append("sexual")
        if "neglect" in text_lower:
            abuse_state["types"].append("neglect")

    if abuse_state["severity"]:
        popup.abuse_widget.set_state(abuse_state)
        popup._sentences["ABUSE"] = popup._apply_pronouns(popup.abuse_widget._to_sentence())
        print(f"[IMPORT] Set background abuse: {abuse_state}")

    # ========================================
    # SCHOOLING - state: {"severity": str, "issues": list}
    # severity: "none", "some", "significant"
    # issues: "conduct problems", "bullying", "truancy", "expulsion"
    # ========================================
    schooling_state = {"severity": None, "issues": []}

    if "schooling was unremarkable" in text_lower:
        schooling_state["severity"] = "none"
    elif "significantly disrupted" in text_lower:
        schooling_state["severity"] = "significant"
    elif "some difficulties" in text_lower or "educational difficulties" in text_lower:
        schooling_state["severity"] = "some"

    # Check for issues
    if "conduct problems" in text_lower or "conduct" in text_lower:
        schooling_state["issues"].append("conduct problems")
    if "bullying" in text_lower or "bullied" in text_lower:
        schooling_state["issues"].append("bullying")
    if "truancy" in text_lower or "truant" in text_lower:
        schooling_state["issues"].append("truancy")
    if "expulsion" in text_lower or "expelled" in text_lower:
        schooling_state["issues"].append("expulsion")

    if schooling_state["severity"]:
        popup.schooling_widget.set_state(schooling_state)
        popup._sentences["SCHOOLING"] = popup._apply_pronouns(popup.schooling_widget._to_sentence())
        print(f"[IMPORT] Set background schooling: {schooling_state}")

    # ========================================
    # QUALIFICATIONS
    # ========================================
    qualifications_patterns = [
        ("postgraduate", "postgraduate"),
        ("obtained a degree", "degree"),
        ("university but did not complete", "uni_incomplete"),
        ("completed a levels", "alevel_completed"),
        ("a levels completed", "alevel_completed"),
        ("started a levels", "alevel_started"),
        ("gcses, all above", "gcse_above"),
        ("gcses with mixed", "gcse_mixed"),
        ("gcses, all below", "gcse_below"),
        ("no qualifications", "none"),
        ("left school with no", "none"),
    ]

    for pattern, value in qualifications_patterns:
        if pattern in text_lower:
            popup.qualifications_widget.set_value(value)
            popup._sentences["QUALIFICATIONS"] = popup._apply_pronouns(popup.qualifications_widget._to_sentence(value))
            print(f"[IMPORT] Set background qualifications: {value}")
            break

    # ========================================
    # WORK HISTORY - state: {"pattern": str, "last_worked_years": int}
    # pattern: "never", "intermittent", "erratic", "continuous"
    # last_worked_years: 0, 1, 2, 3, 5
    # ========================================
    work_state = {"pattern": None, "last_worked_years": None}

    if "never worked" in text_lower or "have never worked" in text_lower:
        work_state["pattern"] = "never"
    elif "worked continuously" in text_lower:
        work_state["pattern"] = "continuous"
    elif "intermittently" in text_lower or "only intermittently" in text_lower:
        work_state["pattern"] = "intermittent"
    elif "erratic" in text_lower:
        work_state["pattern"] = "erratic"

    # Check for last worked time
    if "less than six months" in text_lower:
        work_state["last_worked_years"] = 0
    elif "one year ago" in text_lower:
        work_state["last_worked_years"] = 1
    elif "2 years ago" in text_lower or "two years ago" in text_lower:
        work_state["last_worked_years"] = 2
    elif "3 years ago" in text_lower or "three years ago" in text_lower:
        work_state["last_worked_years"] = 3
    elif "5 years" in text_lower or "five years" in text_lower:
        work_state["last_worked_years"] = 5

    if work_state["pattern"]:
        popup.work_history_widget.set_state(work_state)
        popup._sentences["WORK_HISTORY"] = popup._apply_pronouns(popup.work_history_widget._to_sentence())
        print(f"[IMPORT] Set background work history: {work_state}")

    # ========================================
    # SEXUAL ORIENTATION
    # ========================================
    orientation = None
    if "heterosexual" in text_lower:
        orientation = "heterosexual"
    elif "homosexual" in text_lower:
        orientation = "homosexual"
    elif "bisexual" in text_lower:
        orientation = "bisexual"
    elif "transgender" in text_lower:
        orientation = "transgender"
    elif "did not wish to specify" in text_lower:
        orientation = "not_specified"

    if orientation:
        popup.sexual_orientation_widget.set_value(orientation)
        popup._sentences["SEXUAL_ORIENTATION"] = popup._apply_pronouns(popup.sexual_orientation_widget._to_sentence(orientation))
        print(f"[IMPORT] Set background sexual orientation: {orientation}")

    # ========================================
    # CHILDREN - state: {"count": int, "age_band": str, "composition": str}
    # count: 0-5
    # age_band: "toddlers", "primary", "secondary", "adult", "mixed"
    # composition: "sons", "daughters", "mixed"
    # ========================================
    children_state = {"count": None, "age_band": None, "composition": None}

    if "no children" in text_lower or "have no children" in text_lower:
        children_state["count"] = 0
    else:
        # Check for count
        count_patterns = [
            ("one child", 1),
            ("have one child", 1),
            ("two child", 2),
            ("have two child", 2),
            ("three child", 3),
            ("have three child", 3),
            ("four child", 4),
            ("have four child", 4),
            ("five or more", 5),
            ("have five", 5),
        ]
        for pattern, count in count_patterns:
            if pattern in text_lower:
                children_state["count"] = count
                break

        # Check for age band
        if "toddler" in text_lower:
            children_state["age_band"] = "toddlers"
        elif "primary school" in text_lower:
            children_state["age_band"] = "primary"
        elif "secondary school" in text_lower:
            children_state["age_band"] = "secondary"
        elif "are adults" in text_lower or "adult children" in text_lower:
            children_state["age_band"] = "adult"
        elif "mixed ages" in text_lower:
            children_state["age_band"] = "mixed"

        # Check for composition
        if "all sons" in text_lower:
            children_state["composition"] = "sons"
        elif "all daughters" in text_lower:
            children_state["composition"] = "daughters"

    if children_state["count"] is not None:
        popup.children_widget.set_state(children_state)
        popup._sentences["CHILDREN"] = popup._apply_pronouns(popup.children_widget._to_sentence())
        print(f"[IMPORT] Set background children: {children_state}")

    # ========================================
    # RELATIONSHIPS - state: {"status": str, "duration_years": int}
    # status: "none", "relationship", "married"
    # duration_years: 0, 1, 2, 3, 5, 10
    # ========================================
    rel_state = {"status": None, "duration_years": None}

    if "not currently in a relationship" in text_lower or "not in a relationship" in text_lower:
        rel_state["status"] = "none"
    elif "married" in text_lower or "have been married" in text_lower:
        rel_state["status"] = "married"
    elif "in a relationship" in text_lower:
        rel_state["status"] = "relationship"

    # Check for duration
    if "less than one year" in text_lower:
        rel_state["duration_years"] = 0
    elif "for one year" in text_lower:
        rel_state["duration_years"] = 1
    elif "for two years" in text_lower:
        rel_state["duration_years"] = 2
    elif "for three years" in text_lower:
        rel_state["duration_years"] = 3
    elif "for five years" in text_lower:
        rel_state["duration_years"] = 5
    elif "over ten years" in text_lower or "for ten years" in text_lower:
        rel_state["duration_years"] = 10

    if rel_state["status"]:
        popup.relationships_widget.set_state(rel_state)
        popup._sentences["RELATIONSHIPS"] = popup._apply_pronouns(popup.relationships_widget._to_sentence())
        print(f"[IMPORT] Set background relationships: {rel_state}")

    # Refresh preview
    popup._refresh_preview()
    print("[IMPORT] Background history popup populated")


def populate_forensic_popup(popup, forensic_text: str):
    """
    Populate forensic history popup from imported text.

    Text patterns to detect:
    - Convictions: "has no convictions", "has X conviction(s)", "did not wish to discuss convictions"
    - Offences: "from X offence(s)"
    - Prison: "never been in prison", "has been remanded", "has spent X in prison"
    """
    from forensic_history_popup import CONVICTION_COUNTS, OFFENCE_COUNTS, PRISON_DURATIONS
    import re

    text_lower = forensic_text.lower()

    # =====================================================
    # CONVICTIONS
    # =====================================================
    # Check for conviction count patterns FIRST (most specific)
    conviction_found = False
    for idx, count_text in enumerate(CONVICTION_COUNTS):
        if count_text.lower() in text_lower:
            popup.state["convictions"]["status"] = "some"
            popup.state["convictions"]["count_idx"] = idx
            if "some" in popup.conv_buttons:
                popup.conv_buttons["some"].setChecked(True)
            popup.conv_slider_box.setVisible(True)
            popup.conv_slider.setValue(idx)
            conviction_found = True
            print(f"[IMPORT] Set forensic convictions: some, count_idx={idx}")
            break

    if not conviction_found:
        if "did not wish to discuss convictions" in text_lower:
            popup.state["convictions"]["status"] = "declined"
            if "declined" in popup.conv_buttons:
                popup.conv_buttons["declined"].setChecked(True)
            print("[IMPORT] Set forensic convictions: declined")

        elif "no convictions" in text_lower:
            # More flexible pattern - matches "has no convictions" or "have no convictions"
            popup.state["convictions"]["status"] = "none"
            if "none" in popup.conv_buttons:
                popup.conv_buttons["none"].setChecked(True)
            print("[IMPORT] Set forensic convictions: none")

    # =====================================================
    # OFFENCES (only if convictions = some)
    # =====================================================
    if popup.state["convictions"]["status"] == "some":
        popup.off_slider_box.setVisible(True)
        for idx, offence_text in enumerate(OFFENCE_COUNTS):
            if offence_text.lower() in text_lower:
                popup.state["offences"]["count_idx"] = idx
                popup.off_slider.setValue(idx)
                print(f"[IMPORT] Set forensic offences: count_idx={idx}")
                break

    # =====================================================
    # PRISON
    # =====================================================
    if "did not wish to discuss prison" in text_lower:
        popup.state["prison"]["status"] = "declined"
        if "declined" in popup.prison_buttons:
            popup.prison_buttons["declined"].setChecked(True)
        print("[IMPORT] Set forensic prison: declined")

    elif "never been in prison" in text_lower or "never been to prison" in text_lower:
        popup.state["prison"]["status"] = "never"
        if "never" in popup.prison_buttons:
            popup.prison_buttons["never"].setChecked(True)
        print("[IMPORT] Set forensic prison: never")

    elif "been remanded" in text_lower or "spent" in text_lower and "prison" in text_lower:
        popup.state["prison"]["status"] = "yes"
        if "yes" in popup.prison_buttons:
            popup.prison_buttons["yes"].setChecked(True)
        popup.prison_slider_box.setVisible(True)

        # Check for duration
        for idx, duration_text in enumerate(PRISON_DURATIONS):
            if duration_text.lower() in text_lower:
                popup.state["prison"]["duration_idx"] = idx
                popup.prison_slider.setValue(idx)
                print(f"[IMPORT] Set forensic prison: yes, duration_idx={idx}")
                break

    popup._update_preview()
    print("[IMPORT] Forensic history popup populated")


def populate_physical_health_popup(popup, health_text: str):
    """
    Populate physical health popup from imported text.

    Matches condition names from HEALTH_CONDITIONS dict.
    """
    from physical_health_popup import HEALTH_CONDITIONS
    import re

    text_lower = health_text.lower()
    matched_conditions = []

    # Check each condition against the text
    for category, conditions in HEALTH_CONDITIONS.items():
        for condition in conditions:
            condition_lower = condition.lower()

            if category == "Cancer history":
                # Cancer output format: "history of lung, breast cancer"
                # So we need to check if the cancer type appears near "cancer" or "history of"
                # Check for: "lung cancer", "lung," followed later by "cancer", or just "lung" in cancer context
                cancer_context = re.search(r"history of ([^.]+)cancer", text_lower)
                if cancer_context:
                    cancer_types_text = cancer_context.group(1)
                    # Check if this cancer type is mentioned (as word boundary)
                    if re.search(rf"\b{re.escape(condition_lower)}\b", cancer_types_text):
                        matched_conditions.append(condition)
                        print(f"[IMPORT] Found physical health condition (cancer): {condition}")
                        continue

                # Also check for standalone "X cancer" pattern
                if f"{condition_lower} cancer" in text_lower:
                    matched_conditions.append(condition)
                    print(f"[IMPORT] Found physical health condition: {condition}")
            else:
                # For non-cancer conditions, do direct match
                if condition_lower in text_lower:
                    matched_conditions.append(condition)
                    print(f"[IMPORT] Found physical health condition: {condition}")

    if matched_conditions:
        # Use load_state to properly set checkboxes
        popup.load_state({"conditions": matched_conditions})
        print(f"[IMPORT] Physical health popup populated with {len(matched_conditions)} conditions")
    else:
        print("[IMPORT] No physical health conditions found in text")


def populate_function_popup(popup, function_text: str):
    """
    Populate function popup from imported text.

    Detects:
    - Self care impacts (personal care, home care, children, pets)
    - Relationship impacts (intimate, birth family, friends)
    - Work status (not working, occasionally, part time, full time)
    - Travel impacts (trains, buses, cars)

    Severity levels: slight, mild, moderate, significant, severe
    """
    text_lower = function_text.lower()
    state = {
        "self_care": {},
        "relationships": {},
        "work": {"none": None, "some": None, "part_time": None, "full_time": None},
        "travel": {},
    }

    # Severity patterns (ordered most specific first)
    severity_patterns = [
        ("severely", "severe"),
        ("significantly", "significant"),
        ("moderately", "moderate"),
        ("mildly", "mild"),
        ("slight", "slight"),
        ("severe", "severe"),
        ("significant", "significant"),
        ("moderate", "moderate"),
        ("mild", "mild"),
    ]

    def detect_severity(context: str) -> str:
        """Detect severity level from context string."""
        context_lower = context.lower()
        for pattern, level in severity_patterns:
            if pattern in context_lower:
                return level
        return "mild"  # default

    # =====================================================
    # SELF CARE
    # =====================================================
    self_care_keys = ["personal care", "home care", "children", "pets"]

    for key in self_care_keys:
        if key in text_lower:
            # Try to find severity context
            # Look for patterns like "severely affecting his ability to personal care"
            import re
            pattern = rf"([\w\s]{{0,30}}){re.escape(key)}([\w\s]{{0,30}})"
            match = re.search(pattern, text_lower)
            if match:
                context = match.group(0)
                severity = detect_severity(context)
            else:
                severity = "mild"

            state["self_care"][key] = severity
            print(f"[IMPORT] Set function self_care[{key}] = {severity}")

    # =====================================================
    # RELATIONSHIPS
    # =====================================================
    relationship_keys = ["intimate", "birth family", "friends"]

    for key in relationship_keys:
        search_key = key
        if key == "birth family":
            search_key = "family of origin"

        if search_key in text_lower or key in text_lower:
            import re
            pattern = rf"([\w\s]{{0,30}})({re.escape(search_key)}|{re.escape(key)})([\w\s]{{0,30}})"
            match = re.search(pattern, text_lower)
            if match:
                context = match.group(0)
                severity = detect_severity(context)
            else:
                severity = "mild"

            state["relationships"][key] = severity
            print(f"[IMPORT] Set function relationships[{key}] = {severity}")

    # =====================================================
    # WORK
    # =====================================================
    if "not working" in text_lower or "is not working" in text_lower or "are not working" in text_lower:
        state["work"]["none"] = True
        print("[IMPORT] Set function work: none")
    elif "work only occasionally" in text_lower or "works occasionally" in text_lower:
        state["work"]["some"] = True
        print("[IMPORT] Set function work: some")
    elif "working part time" in text_lower or "part-time" in text_lower:
        state["work"]["part_time"] = True
        print("[IMPORT] Set function work: part_time")
    elif "working full time" in text_lower or "full-time" in text_lower:
        state["work"]["full_time"] = True
        print("[IMPORT] Set function work: full_time")

    # =====================================================
    # TRAVEL
    # =====================================================
    travel_keys = ["trains", "buses", "cars"]

    for key in travel_keys:
        if key in text_lower:
            import re
            pattern = rf"([\w\s]{{0,30}}){re.escape(key)}([\w\s]{{0,30}})"
            match = re.search(pattern, text_lower)
            if match:
                context = match.group(0)
                severity = detect_severity(context)
            else:
                severity = "mild"

            state["travel"][key] = severity
            print(f"[IMPORT] Set function travel[{key}] = {severity}")

    # Load the state into the popup
    popup.load_state(state)
    popup._update_preview()
    print("[IMPORT] Function popup populated")


def populate_mental_state_popup(popup, mse_text: str):
    """
    Populate mental state examination popup from imported text.

    Detects:
    - Demographics (age range, ethnicity)
    - Appearance
    - Behavior
    - Speech
    - Mood (objective, subjective, depressive features)
    - Anxiety symptoms
    - Thoughts (delusions, thought interference)
    - Perceptions (hallucinations)
    - Cognition concern level
    - Insight (overall, risk, treatment, diagnosis)
    """
    from mental_state_examination_popup import (
        MSE_CONDITIONS, MOOD_SCALE, DEPRESSION_SCALE, COGNITION_CONCERN_SCALE
    )

    text_lower = mse_text.lower()

    # Build state structure
    state = {
        "checked": {},
        "mood": {},
        "cognition": None,
    }

    # =====================================================
    # DEMOGRAPHICS - Age Range
    # =====================================================
    age_options = MSE_CONDITIONS["Demographics"]["Age Range"]
    for age in age_options:
        age_lower = age.lower()
        # Handle special patterns
        if "teenager" in age_lower and "teenager" in text_lower:
            state["checked"].setdefault("Age Range", []).append(age)
            print(f"[IMPORT] Set MSE Age Range: {age}")
            break
        elif age_lower in text_lower or age_lower.replace("/", " ") in text_lower:
            state["checked"].setdefault("Age Range", []).append(age)
            print(f"[IMPORT] Set MSE Age Range: {age}")
            break

    # =====================================================
    # DEMOGRAPHICS - Ethnicity
    # =====================================================
    ethnicity_options = MSE_CONDITIONS["Demographics"]["Ethnicity"]
    for eth in ethnicity_options:
        if eth.lower() in text_lower:
            state["checked"].setdefault("Ethnicity", []).append(eth)
            print(f"[IMPORT] Set MSE Ethnicity: {eth}")
            break

    # =====================================================
    # APPEARANCE
    # =====================================================
    appearance_options = MSE_CONDITIONS["Appearance"]
    for app in appearance_options:
        if app.lower() in text_lower:
            state["checked"].setdefault("Appearance", []).append(app)
            print(f"[IMPORT] Set MSE Appearance: {app}")
            break

    # =====================================================
    # BEHAVIOR
    # =====================================================
    behavior_map = MSE_CONDITIONS["Behavior"]
    for label, narrative in behavior_map.items():
        if narrative.lower() in text_lower:
            state["checked"].setdefault("Behavior", []).append(narrative)
            print(f"[IMPORT] Set MSE Behavior: {narrative}")
            break

    # =====================================================
    # SPEECH
    # =====================================================
    speech_map = MSE_CONDITIONS["Speech"]
    for label, narrative in speech_map.items():
        if narrative.lower() in text_lower:
            state["checked"].setdefault("Speech", []).append(narrative)
            print(f"[IMPORT] Set MSE Speech: {narrative}")
            break

    # =====================================================
    # MOOD - Objective
    # =====================================================
    if "objectively" in text_lower:
        for mood in MOOD_SCALE:
            if f"objectively {mood}" in text_lower:
                state["mood"]["Mood Objective"] = mood
                print(f"[IMPORT] Set MSE Mood Objective: {mood}")
                break

    # =====================================================
    # MOOD - Subjective
    # =====================================================
    if "subjectively" in text_lower:
        for mood in MOOD_SCALE:
            if f"subjectively {mood}" in text_lower:
                state["mood"]["Mood Subjective"] = mood
                print(f"[IMPORT] Set MSE Mood Subjective: {mood}")
                break

    # Handle combined mood pattern "objectively and subjectively X"
    if "objectively and subjectively" in text_lower:
        for mood in MOOD_SCALE:
            if f"objectively and subjectively {mood}" in text_lower:
                state["mood"]["Mood Objective"] = mood
                state["mood"]["Mood Subjective"] = mood
                print(f"[IMPORT] Set MSE Mood (both): {mood}")
                break

    # =====================================================
    # MOOD - Depression
    # =====================================================
    for dep in DEPRESSION_SCALE:
        if dep == "nil":
            continue
        if f"{dep} depressive features" in text_lower:
            state["mood"]["Mood Depression"] = dep
            print(f"[IMPORT] Set MSE Mood Depression: {dep}")
            break

    # =====================================================
    # ANXIETY
    # =====================================================
    if "no evidence of pathological anxiety" in text_lower:
        state["checked"].setdefault("Anxiety", []).append("normal")
        print("[IMPORT] Set MSE Anxiety: normal")
    else:
        # Special handling for combined fear patterns
        # Output: "a fear of dying and of losing control"
        if "fear of dying" in text_lower or "and of dying" in text_lower:
            state["checked"].setdefault("Anxiety", []).append("Fear of dying")
            print("[IMPORT] Set MSE Anxiety: Fear of dying")
        if "fear of losing control" in text_lower or "losing control" in text_lower:
            state["checked"].setdefault("Anxiety", []).append("Fear of losing control")
            print("[IMPORT] Set MSE Anxiety: Fear of losing control")

        # Check other anxiety symptoms
        anxiety_options = MSE_CONDITIONS["Anxiety"]
        for anx in anxiety_options:
            # Skip already handled fears and normal
            if anx in ("normal", "Fear of dying", "Fear of losing control"):
                continue
            if anx.lower() in text_lower:
                state["checked"].setdefault("Anxiety", []).append(anx)
                print(f"[IMPORT] Set MSE Anxiety: {anx}")

    # =====================================================
    # THOUGHTS
    # =====================================================
    if "thoughts were normal" in text_lower:
        state["checked"].setdefault("Thoughts", []).append("normal")
        print("[IMPORT] Set MSE Thoughts: normal")
    else:
        # Reverse mapping from output text to checkbox labels
        # (output text from transform_thought_symptoms -> checkbox label)
        thought_reverse_map = {
            "grandiose delusions": "grandiosity",
            "persecutory delusions": "persecutory",
            "delusions of reference": "reference",
            "delusional perceptions": "delusional perception",
            "somatic delusions": "somatic",
            "religious delusions": "religious",
            "delusions of mood/feeling": "mood/feeling",
            "delusions of guilt/worthlessness": "guilt/worthlessness",
            "delusions of infidelity/jealousy": "infidelity/jealousy",
            "delusions of nihilistic/negation": "nihilistic/negation",
            "delusions of thought broadcast": "broadcast",
            "delusions of thought withdrawal": "withdrawal",
            "delusions of thought insertion": "insertion",
        }

        # Check reverse mappings first
        for output_text, checkbox_label in thought_reverse_map.items():
            if output_text in text_lower:
                state["checked"].setdefault("Thoughts", []).append(checkbox_label)
                print(f"[IMPORT] Set MSE Thoughts: {checkbox_label} (from '{output_text}')")

        # Also check direct matches for any remaining
        thoughts_options = MSE_CONDITIONS["Thoughts"]
        already_added = state["checked"].get("Thoughts", [])
        for thought in thoughts_options:
            if thought in already_added or thought == "normal":
                continue
            if thought.lower() in text_lower:
                state["checked"].setdefault("Thoughts", []).append(thought)
                print(f"[IMPORT] Set MSE Thoughts: {thought}")

    # =====================================================
    # PERCEPTIONS
    # =====================================================
    if "no evidence of perceptual disturbance" in text_lower:
        state["checked"].setdefault("Perceptions", []).append("normal")
        print("[IMPORT] Set MSE Perceptions: normal")
    else:
        perceptions_options = MSE_CONDITIONS["Perceptions"]
        for perc in perceptions_options:
            if perc.lower() in text_lower and perc != "normal":
                state["checked"].setdefault("Perceptions", []).append(perc)
                print(f"[IMPORT] Set MSE Perceptions: {perc}")

    # =====================================================
    # COGNITION
    # =====================================================
    if "cognition was broadly intact" in text_lower or "not assessed clinically" in text_lower:
        state["cognition"] = "nil"
        print("[IMPORT] Set MSE Cognition: nil")
    else:
        for level in COGNITION_CONCERN_SCALE:
            if level == "nil":
                continue
            if f"{level} concern" in text_lower:
                state["cognition"] = level
                print(f"[IMPORT] Set MSE Cognition: {level}")
                break

    # =====================================================
    # INSIGHT
    # =====================================================
    import re

    # Check overall insight first
    overall_match = re.search(r"insight was (present|partial|absent) overall", text_lower)
    if overall_match:
        overall_value = overall_match.group(1)
        state["checked"].setdefault("Insight Overall", []).append(overall_value)
        print(f"[IMPORT] Set MSE Insight Overall: {overall_value}")

    # Handle combined insight patterns like:
    # "with insight into risk being present, and into treatment and diagnosis being partial"
    # or "with insight into treatment and diagnosis being present"

    # Find all "into X being Y" or "into X and Y being Z" patterns
    insight_pattern = r"into\s+([\w\s,]+?)\s+being\s+(present|partial|absent)"
    for match in re.finditer(insight_pattern, text_lower):
        categories_text = match.group(1).strip()
        value = match.group(2)

        # Parse the categories (could be "risk", "treatment", "treatment and diagnosis", etc.)
        # Split by "and" and ","
        categories = re.split(r'\s+and\s+|,\s*', categories_text)
        categories = [c.strip() for c in categories if c.strip()]

        for cat in categories:
            if cat == "risk":
                state["checked"].setdefault("Insight Risk", []).append(value)
                print(f"[IMPORT] Set MSE Insight Risk: {value}")
            elif cat == "treatment":
                state["checked"].setdefault("Insight Treatment", []).append(value)
                print(f"[IMPORT] Set MSE Insight Treatment: {value}")
            elif cat == "diagnosis":
                state["checked"].setdefault("Insight Diagnosis", []).append(value)
                print(f"[IMPORT] Set MSE Insight Diagnosis: {value}")

    # Load the state
    popup.load_state(state)
    popup._refresh_preview()
    print("[IMPORT] Mental state examination popup populated")


def extract_diagnoses_from_summary(text: str) -> list:
    """
    Extract ICD-10 diagnoses from summary/impression text.

    Looks for patterns like:
    - "Diagnoses under consideration include X (ICD-10 F32.1); Y (ICD-10 F41.0)"
    - "X (ICD-10 F32.1)"

    Returns:
        list of dicts: [{"diagnosis": "...", "icd10": "Fxx.x"}, ...]
    """
    diagnoses = []

    # More robust pattern - match anything before (ICD-10 Fxx.x) that looks like a diagnosis name
    # Use greedy match but anchor to the ICD-10 marker
    pattern = r"([A-Za-z][A-Za-z\s\-\'\,]+?)\s*\(ICD-10\s*([Ff]\d+\.?\d*)\)"

    matches = re.findall(pattern, text)
    for diagnosis, icd10 in matches:
        # Clean up the diagnosis name
        dx_name = diagnosis.strip()
        # Remove leading semicolons or separators that might have been captured
        dx_name = dx_name.lstrip(";, ")
        if dx_name:
            diagnoses.append({
                "diagnosis": dx_name,
                "icd10": icd10.upper()
            })
            print(f"[IMPORT] Extracted diagnosis: {dx_name} ({icd10.upper()})")

    return diagnoses


def populate_impression_popup(popup, summary_text: str):
    """
    Populate impression popup with diagnoses extracted from summary text.
    """
    diagnoses = extract_diagnoses_from_summary(summary_text)

    if not diagnoses:
        print("[IMPORT] No diagnoses found in summary text")
        return

    print(f"[IMPORT] Found {len(diagnoses)} diagnoses: {diagnoses}")

    # Populate the diagnosis dropdown boxes
    for i, dx in enumerate(diagnoses):
        if i >= len(popup.dx_boxes):
            print(f"[IMPORT] No more dx_boxes available (have {len(popup.dx_boxes)}, need {i+1})")
            break

        combo = popup.dx_boxes[i]
        dx_name = dx.get("diagnosis", "")
        dx_code = dx.get("icd10", "")

        found = False

        # Try to match by ICD-10 code first (more reliable)
        if dx_code:
            for idx in range(combo.count()):
                item_data = combo.itemData(idx)
                if item_data and isinstance(item_data, dict):
                    if item_data.get("icd10", "").upper() == dx_code.upper():
                        combo.setCurrentIndex(idx)
                        print(f"[IMPORT] Set diagnosis {i+1} by code: {combo.itemText(idx)}")
                        found = True
                        break

        # Fallback to name matching
        if not found and dx_name:
            for idx in range(combo.count()):
                item_text = combo.itemText(idx)
                if dx_name.lower() in item_text.lower():
                    combo.setCurrentIndex(idx)
                    print(f"[IMPORT] Set diagnosis {i+1} by name: {item_text}")
                    found = True
                    break

        if not found:
            print(f"[IMPORT] Could not find match for diagnosis: {dx_name} ({dx_code})")

    # Update preview
    popup._refresh_preview()


def populate_plan_popup(popup, plan_text: str):
    """
    Populate plan popup from imported text.

    Detects:
    - Medication action (start/stop/increase/decrease)
    - Psychoeducation (diagnosis discussed, medication discussed)
    - Capacity (has/lacks + domain)
    - Psychology (continue/start/refused + therapy type)
    - Occupational Therapy
    - Care Coordination
    - Physical Health items
    - Letter Signed By
    - Next Appointment date
    """
    import re
    from plan_popup import PLAN_SECTIONS

    # Strip markdown bold markers before processing
    plan_text = re.sub(r'\*\*', '', plan_text)
    text_lower = plan_text.lower()

    state = {
        "plan": {},
        "medication_action": None,
        "capacity": None,
        "psychology": None,
        "ot_status": None,
        "care_status": None,
        "next_appointment": None,
        "signed_by": None,
    }

    # =====================================================
    # MEDICATION
    # =====================================================
    med_patterns = {
        "starting": "Start",
        "stopping": "Stop",
        "increasing": "Increase",
        "decreasing": "Decrease",
    }
    for pattern, action in med_patterns.items():
        if f"recommend {pattern}" in text_lower:
            state["medication_action"] = action
            print(f"[IMPORT] Set plan medication action: {action}")
            break

    # =====================================================
    # PSYCHOEDUCATION
    # =====================================================
    psycho_items = []
    if "diagnosis was discussed" in text_lower:
        psycho_items.append("Diagnosis discussed with patient")
        print("[IMPORT] Set plan: Diagnosis discussed")
    if "advised about medication" in text_lower or "side-effects" in text_lower:
        psycho_items.append("Medication / side-effects discussed")
        print("[IMPORT] Set plan: Medication discussed")
    if psycho_items:
        state["plan"]["Psychoeducation"] = psycho_items

    # =====================================================
    # CAPACITY
    # =====================================================
    capacity_match = re.search(
        r"capacity assessment.*?carried out for (\w+).*?noted to (have|lack) capacity",
        text_lower
    )
    if capacity_match:
        domain = capacity_match.group(1)
        status = "has" if capacity_match.group(2) == "have" else "lacks"
        state["capacity"] = {"status": status, "domain": domain}
        print(f"[IMPORT] Set plan capacity: {status} for {domain}")

    # =====================================================
    # PSYCHOLOGY
    # =====================================================
    psych_match = re.search(
        r"discussed psychology and .+? will (continue|start|refused?) (\w+) therapy",
        text_lower
    )
    if psych_match:
        status = psych_match.group(1)
        if status == "refused":
            status = "refused"
        therapy = psych_match.group(2).upper()
        # Map common therapy names
        therapy_map = {
            "CBT": "CBT",
            "TRAUMA-FOCUSSED": "Trauma-focussed",
            "TRAUMA": "Trauma-focussed",
            "DBT": "DBT",
            "PSYCHODYNAMIC": "Psychodynamic",
            "SUPPORTIVE": "Supportive",
        }
        therapy = therapy_map.get(therapy.upper(), therapy.capitalize())
        state["psychology"] = {"status": status, "therapy": therapy}
        print(f"[IMPORT] Set plan psychology: {status} {therapy}")

    # =====================================================
    # OCCUPATIONAL THERAPY
    # =====================================================
    ot_options = PLAN_SECTIONS.get("Occupational Therapy", [])
    for opt in ot_options:
        if opt.lower() in text_lower:
            state["ot_status"] = opt
            print(f"[IMPORT] Set plan OT: {opt}")
            break

    # =====================================================
    # CARE COORDINATION
    # =====================================================
    care_options = PLAN_SECTIONS.get("Care Coordination", [])
    for opt in care_options:
        if opt.lower() in text_lower:
            state["care_status"] = opt
            print(f"[IMPORT] Set plan Care: {opt}")
            break

    # =====================================================
    # PHYSICAL HEALTH
    # =====================================================
    if "please can you arrange" in text_lower:
        ph_items = ["Please can you arrange"]
        ph_options = ["Annual physical", "U&Es", "FBC", "LFTs", "TFTs", "PSA", "Haematinics", "ECG", "CXR"]
        for opt in ph_options:
            if opt.lower() in text_lower:
                ph_items.append(opt)
                print(f"[IMPORT] Set plan Physical Health: {opt}")
        state["plan"]["Physical Health"] = ph_items

    # =====================================================
    # NEXT APPOINTMENT
    # =====================================================
    appt_match = re.search(r"next appointment.*?(\d{1,2}\s+\w+\s+\d{4})", text_lower)
    if appt_match:
        date_str = appt_match.group(1)
        # Try to parse the date
        from PySide6.QtCore import QDate
        for fmt in ["d MMM yyyy", "dd MMM yyyy", "d MMMM yyyy", "dd MMMM yyyy"]:
            qd = QDate.fromString(date_str.title(), fmt)
            if qd.isValid():
                state["next_appointment"] = qd.toString("yyyy-MM-dd")
                print(f"[IMPORT] Set plan next appointment: {state['next_appointment']}")
                break

    # =====================================================
    # LETTER SIGNED BY
    # =====================================================
    if "consultant psychiatrist" in text_lower:
        state["signed_by"] = {"role": "Consultant Psychiatrist"}
        print("[IMPORT] Set plan signed by: Consultant Psychiatrist")
    elif "specialty doctor" in text_lower:
        state["signed_by"] = {"role": "Specialty Doctor"}
        print("[IMPORT] Set plan signed by: Specialty Doctor")
    elif "registrar" in text_lower:
        grade_match = re.search(r"registrar.*?\((ct\d|st\d)\)", text_lower)
        grade = grade_match.group(1).upper() if grade_match else None
        state["signed_by"] = {"role": "Registrar", "grade": grade}
        print(f"[IMPORT] Set plan signed by: Registrar ({grade})")

    # Restore the state
    popup.restore_state(state)
    popup._refresh_preview()
    print("[IMPORT] Plan popup populated")


def populate_front_popup(fp, front_details: dict):
    """Populate front page popup with extracted details."""
    from PySide6.QtCore import QDate

    if front_details.get("patient_name"):
        # Use name_field (single field) if available
        if hasattr(fp, 'name_field'):
            fp.name_field.setText(front_details["patient_name"])
        # Fallback to first_name/surname if they exist
        elif hasattr(fp, 'first_name_field'):
            names = front_details["patient_name"].split()
            if names:
                fp.first_name_field.setText(names[0])
            if hasattr(fp, 'surname_field') and len(names) > 1:
                fp.surname_field.setText(" ".join(names[1:]))
        print(f"[IMPORT] Set patient name: {front_details['patient_name']}")

    if front_details.get("dob") and hasattr(fp, 'dob_field'):
        dob_str = front_details["dob"]
        # Try common date formats
        for fmt in ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "dd.MM.yyyy"]:
            parsed = QDate.fromString(dob_str, fmt)
            if parsed.isValid():
                fp.dob_field.setDate(parsed)
                print(f"[IMPORT] Set DOB: {dob_str}")
                break

    if front_details.get("nhs_number") and hasattr(fp, 'nhs_field'):
        fp.nhs_field.setText(front_details["nhs_number"])
        print(f"[IMPORT] Set NHS: {front_details['nhs_number']}")

    if front_details.get("gender") and hasattr(fp, 'gender_field'):
        gender = front_details["gender"].capitalize()
        fp.gender_field.setCurrentText(gender)
        print(f"[IMPORT] Set gender: {gender}")

    if front_details.get("clinician") and hasattr(fp, 'clinician_field'):
        fp.clinician_field.setText(front_details["clinician"])
        print(f"[IMPORT] Set clinician: {front_details['clinician']}")

    if front_details.get("address") and hasattr(fp, 'address_field'):
        fp.address_field.setText(front_details["address"])


def parse_front_page(text: str) -> dict:
    """
    Parse front page text to extract patient details.

    Returns:
        dict with keys like 'patient_name', 'dob', 'nhs_number', etc.
    """
    details = {}

    lines = text.split("\n")
    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Try to match common patterns
        lower = line.lower()

        # Patient name patterns
        if "patient:" in lower or "name:" in lower:
            match = re.search(r"(?:patient|name):\s*(.+)", line, re.I)
            if match:
                details["patient_name"] = match.group(1).strip()

        elif lower.startswith("re:") or "regarding:" in lower:
            # "Re: Rachel Weiss" or "Regarding: John Smith"
            match = re.search(r"(?:re|regarding):\s*(.+)", line, re.I)
            if match:
                # Only use if we don't already have a patient name
                if "patient_name" not in details:
                    details["patient_name"] = match.group(1).strip()

        elif "dob:" in lower or "date of birth:" in lower:
            match = re.search(r"(?:dob|date of birth):\s*(.+)", line, re.I)
            if match:
                details["dob"] = match.group(1).strip()

        elif "nhs" in lower:
            match = re.search(r"nhs\s*(?:number)?:\s*(.+)", line, re.I)
            if match:
                details["nhs_number"] = match.group(1).strip()

        elif "address:" in lower:
            match = re.search(r"address:\s*(.+)", line, re.I)
            if match:
                details["address"] = match.group(1).strip()

        elif "clinician:" in lower or "doctor:" in lower:
            match = re.search(r"(?:clinician|doctor):\s*(.+)", line, re.I)
            if match:
                details["clinician"] = match.group(1).strip()

        elif "date:" in lower and "birth" not in lower:
            match = re.search(r"date:\s*(.+)", line, re.I)
            if match:
                details["letter_date"] = match.group(1).strip()

        elif "gender:" in lower or "sex:" in lower:
            match = re.search(r"(?:gender|sex):\s*(.+)", line, re.I)
            if match:
                details["gender"] = match.group(1).strip()

    # If no gender found, try to infer from pronouns in the text
    if "gender" not in details:
        text_lower = text.lower()
        # Check for female pronouns
        if " she " in text_lower or " her " in text_lower or "she presents" in text_lower:
            details["gender"] = "Female"
        # Check for male pronouns
        elif " he " in text_lower or " his " in text_lower or "he presents" in text_lower:
            details["gender"] = "Male"

    return details


class DocxLetterImporter:
    """Import a DOCX letter and populate letter cards."""

    @staticmethod
    def import_letter(file_path: str, letter_page) -> bool:
        """
        Import a DOCX letter file and populate the letter page cards.

        Args:
            file_path: Path to the DOCX file
            letter_page: The LetterWriterPage instance

        Returns:
            bool: True if successful
        """
        try:
            # =====================================================
            # RESET ALL CARDS AND POPUPS BEFORE IMPORT
            # =====================================================
            print("[IMPORT] Resetting letter and all popups...")

            # Clear all card editors
            for key, card in letter_page.cards.items():
                if hasattr(card, 'editor'):
                    card.editor.blockSignals(True)
                    card.editor.clear()
                    card.editor.blockSignals(False)

            # Clear popup memory
            if hasattr(letter_page, 'popup_memory'):
                letter_page.popup_memory.clear()

            # Clear imported sections
            if hasattr(letter_page, '_imported_sections'):
                letter_page._imported_sections = {}
            if hasattr(letter_page, '_imported_front_data'):
                letter_page._imported_front_data = {}

            # Reset all popups to fresh state
            popup_attrs = [
                'front_popup', 'presenting_complaint_popup', 'history_popup',
                'affect_popup', 'anxiety_popup', 'psychosis_popup', 'psychhx_popup',
                'background_popup', 'drugalc_popup', 'social_popup', 'forensic_popup',
                'physical_popup', 'function_popup', 'mse_popup', 'impression_popup',
                'plan_popup'
            ]

            for popup_name in popup_attrs:
                popup = getattr(letter_page, popup_name, None)
                if popup is not None:
                    # Try to reset the popup state
                    if hasattr(popup, 'reset_state'):
                        popup.reset_state()
                    elif hasattr(popup, 'clear'):
                        popup.clear()
                    # Delete the popup so it gets recreated fresh
                    try:
                        popup.deleteLater()
                    except:
                        pass
                    setattr(letter_page, popup_name, None)

            print("[IMPORT] Reset complete, now importing...")

            # =====================================================
            # PARSE AND IMPORT
            # =====================================================
            sections = parse_docx_letter(file_path)

            if not sections:
                print("[IMPORT] No sections found in document")
                return False

            print(f"[IMPORT] Found sections: {list(sections.keys())}")

            # Store all imported section data on letter_page for popup population later
            letter_page._imported_sections = sections.copy()
            print("[IMPORT] Stored section data for popup population")

            # Populate each card
            for key, content in sections.items():
                if key in letter_page.cards:
                    editor = letter_page.cards[key].editor
                    editor.blockSignals(True)
                    editor.setPlainText(content)
                    editor.blockSignals(False)
                    print(f"[IMPORT] Populated card '{key}' with {len(content)} chars")
                else:
                    print(f"[IMPORT] Card '{key}' not found in letter page")

            # Try to populate front page popup if we have front page data
            if "front" in sections:
                front_details = parse_front_page(sections["front"])

                # If gender not found in front page, try to infer from other sections
                if "gender" not in front_details:
                    all_text = " ".join(sections.values()).lower()
                    if " she " in all_text or " her " in all_text or "she presents" in all_text:
                        front_details["gender"] = "Female"
                    elif " he " in all_text or " his " in all_text or "he presents" in all_text:
                        front_details["gender"] = "Male"

                print(f"[IMPORT] Front page details parsed: {front_details}")

                # Store the imported front data on letter_page for later use
                letter_page._imported_front_data = front_details

                # Try to ensure front_popup exists
                fp = None
                if hasattr(letter_page, '_ensure_front_popup'):
                    fp = letter_page._ensure_front_popup()
                elif hasattr(letter_page, 'front_popup') and letter_page.front_popup:
                    fp = letter_page.front_popup

                if fp:
                    populate_front_popup(fp, front_details)
                else:
                    print("[IMPORT] Front popup not available yet, data stored for later")

            # ========================================================
            # POPULATE POPUPS BASED ON SECTION CONTENT
            # ========================================================

            # Presenting Complaint popup
            if "pc" in sections:
                pc_popup = getattr(letter_page, 'pc_popup', None)
                if pc_popup is None:
                    pc_popup = getattr(letter_page.page_ref, 'pc_popup', None) if hasattr(letter_page, 'page_ref') else None

                if pc_popup and hasattr(pc_popup, 'clusters'):
                    populate_presenting_complaint_popup(pc_popup, sections["pc"])
                    print("[IMPORT] Populated Presenting Complaint popup")

            # History of Presenting Complaint - also check for symptoms
            if "hpc" in sections:
                pc_popup = getattr(letter_page, 'pc_popup', None)
                if pc_popup is None:
                    pc_popup = getattr(letter_page.page_ref, 'pc_popup', None) if hasattr(letter_page, 'page_ref') else None

                if pc_popup and hasattr(pc_popup, 'clusters'):
                    # Also scan HPC for symptoms
                    populate_presenting_complaint_popup(pc_popup, sections["hpc"])

            return True

        except Exception as e:
            print(f"[IMPORT] Error importing letter: {e}")
            import traceback
            traceback.print_exc()
            return False

# ================================================================
#  LETTER TEMPLATES — Structured Content Blocks
#  Module 5/10 for MyPsy Dynamic Letter Writer
# ================================================================
#  Provides:
#   • Standard HPC/MSE/Risk/Social/Plan templates
#   • Formal NHS-style MyPsy signature tone
#   • Placeholder-based text blocks for generators to populate
# ================================================================

from __future__ import annotations


# ================================================================
# PRESENTING COMPLAINT
# ================================================================
PRESENTING_COMPLAINT_TEMPLATE = """
{patient_name} presents with concerns relating to {chief_complaint}. 
The primary issues at this review include {primary_issues}.
"""


# ================================================================
# HISTORY OF PRESENTING COMPLAINT (HPC)
# ================================================================
HPC_TEMPLATE = """
Over the past {duration}, {patient_name} has experienced {symptoms}. 
There has been a {course} in their presentation, with {key_details}. 
Relevant contextual factors include {context}.
"""


# ================================================================
# MENTAL STATE EXAMINATION
# ================================================================
MSE_TEMPLATE = """
Appearance & Behaviour:
{appearance}

Speech:
{speech}

Mood & Affect:
{mood}

Thought Form:
{thought_form}

Thought Content:
{thought_content}

Perception:
{perception}

Cognition:
{cognition}

Insight:
{insight}
"""


# ================================================================
# RISK ASSESSMENT
# ================================================================
RISK_TEMPLATE = """
Current risk factors include {risk_factors}. 
Protective factors include {protective_factors}. 
Overall, the risk is assessed as {risk_level} at this time.
"""


# ================================================================
# SOCIAL HISTORY
# ================================================================
SOCIAL_HISTORY_TEMPLATE = """
{patient_name} lives {living_situation}. 
They report {family_context}. 
Educational and occupational history indicates {work_history}. 
Additional relevant social factors include {social_factors}.
"""


# ================================================================
# FORENSIC HISTORY
# ================================================================
FORENSIC_HISTORY_TEMPLATE = """
Forensic history includes {forensic_summary}. 
No further concerns have been identified at this time.
"""


# ================================================================
# PHYSICAL HEALTH
# ================================================================
PHYSICAL_HEALTH_TEMPLATE = """
Physical health records indicate {physical_summary}. 
Recent investigations show {investigations}. 
There are {physical_concerns}.
"""


# ================================================================
# MEDICATION TEMPLATE
# ================================================================
MEDICATION_TEMPLATE = """
Current medication includes: {current_medications}. 
Recent changes consist of {med_changes}. 
The patient reports {med_adherence}.
"""


# ================================================================
# DIAGNOSIS TEMPLATE
# ================================================================
DIAGNOSIS_TEMPLATE = """
Working diagnosis:
{diagnosis}

Differential diagnoses:
{differentials}
"""


# ================================================================
# PLAN TEMPLATE
# ================================================================
PLAN_TEMPLATE = """
1. Medication: {plan_medication}
2. Psychological interventions: {plan_psychology}
3. Social interventions: {plan_social}
4. Risk management: {plan_risk}
5. Follow-up: {plan_followup}
"""


# ================================================================
# OPTIONAL DETAIL MODULES (OCD / PTSD / ANXIETY / PSYCHOSIS)
# ================================================================
OCD_TEMPLATE = """
{patient_name} reports intrusive thoughts consistent with obsessions involving {obsessions}. 
Compulsions include {compulsions}, which temporarily alleviate distress.
"""

PTSD_TEMPLATE = """
Symptoms consistent with post-traumatic stress disorder are reported, including 
re-experiencing phenomena ({reexperiencing}), avoidance ({avoidance}), 
and hyperarousal ({hyperarousal}). 
These symptoms arise in the context of {trauma_context}.
"""

ANXIETY_TEMPLATE = """
Anxiety symptoms include {anxiety_symptoms}. 
Triggers include {triggers}. 
Physiological symptoms reported are {physical_symptoms}.
"""

PSYCHOSIS_TEMPLATE = """
Psychotic symptoms include {psychotic_symptoms}. 
This comprises {delusions}, {hallucinations}, and disturbances in thought form ({thought_form}). 
The symptoms have been {course} in recent days.
"""


# ================================================================
# FULL LETTER TEMPLATE (fallback or manual use)
# ================================================================
FULL_LETTER_TEMPLATE = """
CLINIC LETTER

Presenting Complaint:
{presenting_complaint}

History of Presenting Complaint:
{hpc}

Mental State Examination:
{mse}

Diagnosis:
{diagnosis}

Risk Assessment:
{risk}

Medication:
{medication}

Social History:
{social}

Forensic History:
{forensic}

Physical Health:
{physical}

Plan:
{plan}
""".strip()

# ================================================================
#  SENTENCE TEMPLATES — Insertable Micro-Templates
#  Module 6/10 for MyPsy Dynamic Letter Writer
# ================================================================
#  These are short clinical phrases the user can insert at the cursor.
#  They support creative writing and structure-building.
# ================================================================

from __future__ import annotations


# ================================================================
# GENERIC SENTENCE STARTERS
# ================================================================
GENERIC_SENTENCES = [
    "He reports that ",
    "She reports that ",
    "They describe ",
    "There has been a gradual change in ",
    "Symptoms appear to fluctuate in relation to ",
    "This presentation is consistent with ",
    "There is evidence of ongoing difficulties with ",
    "A number of psychosocial factors contribute to ",
    "He denies any current thoughts of ",
    "She denies any current thoughts of ",
    "They deny any current thoughts of ",
    "He acknowledges some difficulty with ",
    "She acknowledges some difficulty with ",
    "They acknowledge some difficulty with ",
]


# ================================================================
# HPC SENTENCES
# ================================================================
HPC_SENTENCES = [
    "The onset of symptoms appears to have been approximately ",
    "Recent stressors include ",
    "He notes a worsening of symptoms over the past ",
    "She identifies key triggers such as ",
    "They report a decline in function related to ",
    "Collateral information suggests ",
    "Symptoms first emerged following ",
]


# ================================================================
# MSE SENTENCES
# ================================================================
MSE_SENTENCES = [
    "On approach, the patient appeared ",
    "Behaviour was characterised by ",
    "Speech was noted to be ",
    "Mood was described as ",
    "Affect was ",
    "Thought processes appeared ",
    "Thought content included ",
    "Perceptual disturbances were noted in the form of ",
    "Cognitive function appeared broadly ",
    "Insight into their condition is assessed as ",
]


# ================================================================
# RISK SENTENCES
# ================================================================
RISK_SENTENCES = [
    "Current dynamic risk factors include ",
    "Historical risk factors include ",
    "Protective factors include ",
    "At present, risk is assessed as ",
    "There is no evidence at this time of ",
    "Risk is increased by recent events including ",
]


# ================================================================
# SOCIAL HISTORY SENTENCES
# ================================================================
SOCIAL_SENTENCES = [
    "He currently lives ",
    "She currently lives ",
    "They currently live ",
    "Family relationships are described as ",
    "Occupational history indicates ",
    "Educational background includes ",
    "There is a history of adverse childhood experiences including ",
    "Current social stressors include ",
]


# ================================================================
# FORMULATION SENTENCES
# ================================================================
FORMULATION_SENTENCES = [
    "This presentation may be understood in the context of ",
    "Contributing biological factors include ",
    "Psychological factors influencing presentation include ",
    "Social factors contributing to difficulties include ",
    "Overall formulation indicates ",
]


# ================================================================
# PLAN SENTENCES
# ================================================================
PLAN_SENTENCES = [
    "We agreed on a plan to ",
    "He will continue on current medication with monitoring for ",
    "She will continue on current medication with monitoring for ",
    "They will continue on current medication with monitoring for ",
    "Psychological interventions will focus on ",
    "A referral will be made to ",
    "Follow-up will take place in ",
    "Crisis planning was reviewed including ",
]


# ================================================================
# PUBLIC EXPORT: grouping everything for UI listing
# ================================================================
SENTENCE_TEMPLATES = {
    "Generic": GENERIC_SENTENCES,
    "HPC": HPC_SENTENCES,
    "MSE": MSE_SENTENCES,
    "Risk": RISK_SENTENCES,
    "Social": SOCIAL_SENTENCES,
    "Formulation": FORMULATION_SENTENCES,
    "Plan": PLAN_SENTENCES,
}

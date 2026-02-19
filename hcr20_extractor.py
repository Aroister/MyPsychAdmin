# ============================================================
# HCR-20 RISK ASSESSMENT EXTRACTOR
# Extracts relevant information from clinical notes for each HCR-20 item
# H = Historical (all notes), C = Clinical (last 6 months), R = Risk Management (future-oriented)
# ============================================================

from __future__ import annotations
import re
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dateutil import parser as date_parser


# ============================================================
# HCR-20 EXTRACTION TERMS - Keywords to search for each item
# ============================================================

HCR20_EXTRACTION_TERMS = {
    # ===================== HISTORICAL ITEMS (H1-H10) =====================
    # Search ALL notes for historical information

    "H1": {
        "title": "History of Problems with Violence",
        "scope": "historical",
        "terms": [
            "violence", "violent", "assault", "assaulted", "attack", "attacked",
            "aggression", "aggressive", "hit", "struck", "punch", "punched",
            "fight", "fighting", "fought", "battery", " abh ", " gbh ", "actual bodily harm",
            "grievous bodily harm", "threat", "threatening", "intimidat",
            "physical altercation", "physical aggression", "weapon", "knife", "stabbed",
            "self-harm", "self harm", "suicide", "suicidal", "overdose", " od ",
            "cutting", "ligature", "hanging", "attempted suicide",
            "deliberate self-harm", " dsh ", "nonfatal", "parasuicide",
        ],
        "subsections": {
            "prior_violent_behavior": [
                "previous violence", "history of violence", "prior assault",
                "past aggression", "violent offence", "violent offense",
                "index offence", "index offense", "conviction for violence",
            ],
            "self_harm_suicide": [
                "self-harm", "self harm", "suicide attempt", "suicidal ideation",
                "overdose", "cutting", "ligature", " dsh ", "deliberate self-harm",
            ],
        },
    },

    "H2": {
        "title": "History of Problems with Other Antisocial Behaviour",
        "scope": "historical",
        "terms": [
            "first offence", "first offense", "first violent", "age at first",
            "juvenile", "youth offend", "young offender", "childhood violence",
            "adolescent violence", "early onset", "childhood conduct",
            "conduct disorder", "early behaviour", "early behavior",
            "school exclusion", "expelled", "antisocial behaviour in childhood",
        ],
        "subsections": {
            "age_first_violence": [
                "age at first", "first violent incident", "first offence age",
                "onset of violence", "early violence", "childhood aggression",
            ],
            "juvenile_offending": [
                "juvenile", "youth court", "young offender", "yoi",
                "youth custody", "borstal", "secure unit", "care order",
            ],
        },
    },

    "H3": {
        "title": "History of Problems with Relationships",
        "scope": "historical",
        "terms": [
            "relationship", "partner", "marriage", "married", "divorce", "divorced",
            "separation", "separated", "domestic", "intimate partner",
            "boyfriend", "girlfriend", "spouse", "wife", "husband",
            "family conflict", "estranged", "custody", "children", "parenting",
            "domestic violence", "domestic abuse", "coercive control",
            "breakup", "break-up", "split", "acrimonious",
        ],
        "subsections": {
            "intimate_relationships": [
                "partner", "wife", "husband", "girlfriend", "boyfriend",
                "marriage", "divorce", "intimate", "romantic relationship",
            ],
            "non_intimate_relationships": [
                "family", "friend", "colleague", "neighbour", "acquaintance",
                "social network", "isolation", "estranged from family",
            ],
        },
    },

    "H4": {
        "title": "History of Problems with Employment",
        "scope": "historical",
        "terms": [
            "employment", "employed", "unemployed", "job", "work", "working",
            "occupation", "career", "profession", "vocational",
            "dismissed", "sacked", "fired", "redundant", "quit",
            "education", "school", "college", "university", "degree",
            "qualification", "training", "apprentice", "truant", "expelled",
            "academic", "literacy", "illiterate", "special needs",
        ],
        "subsections": {
            "employment_history": [
                "employment", "job", "work", "occupation", "unemployed",
                "dismissed", "sacked", "fired", "redundant",
            ],
            "education": [
                "school", "education", "college", "university", "expelled",
                "truant", "special educational needs", "learning difficulty",
            ],
        },
    },

    "H5": {
        "title": "History of Problems with Substance Use",
        "scope": "historical",
        "terms": [
            # Specific substance names
            "cannabis", "cocaine", "heroin", "crack",
            "amphetamine", "methamphetamine", "benzodiazepine", "opioid", "opiate",
            "ecstasy", "mdma", "lsd", "ketamine", "spice", "mamba",
            # Alcohol-specific (not just "drink")
            "alcohol dependence", "alcohol misuse", "alcoholic", "drunk", "intoxicated",
            "smelling of alcohol", "under the influence",
            # Clinical/treatment terms
            "addiction", "dependence syndrome", "withdrawal", "detox", "detoxification",
            "rehab", "rehabilitation", " aa ", " na ", "alcoholics anonymous", "narcotics anonymous",
            # Specific drug-related phrases
            "substance misuse", "substance dependence", "drug misuse", "drug dependence",
            "illicit substance", "recreational drug", "drug test", "uds positive",
            "positive for cannabis", "positive for cocaine", "positive for opiates",
            "admitted using", "admitted smoking cannabis", "found with drugs",
        ],
        "subsections": {
            "alcohol": [
                "alcohol dependence", "alcohol misuse", "alcoholic", "drunk", "intoxicated",
                "smelling of alcohol", "under the influence", "alcohol withdrawal",
            ],
            "drugs": [
                "cannabis", "cocaine", "heroin", "amphetamine", "spice",
                "substance misuse", "illicit substance", "recreational drug",
                "drug test positive", "uds positive", "positive for",
            ],
            "impact_on_risk": [
                "intoxicated during offence", "drug-related offence",
                "disinhibition", "substance use and violence",
                "under the influence when", "admitted using before",
            ],
        },
    },

    "H6": {
        "title": "History of Problems with Major Mental Disorder",
        "scope": "historical",
        "terms": [
            # ICD-10 F20-F29: Schizophrenia and related disorders
            "schizophrenia", "paranoid schizophrenia", "hebephrenic schizophrenia",
            "catatonic schizophrenia", "undifferentiated schizophrenia",
            "residual schizophrenia", "simple schizophrenia",
            "schizotypal disorder", "schizoaffective disorder", "schizoaffective",
            "persistent delusional disorder", "delusional disorder",
            "acute psychotic disorder", "brief psychotic disorder",
            "induced delusional disorder", "folie a deux",
            # ICD-10 F30-F39: Mood/Affective disorders
            "bipolar affective disorder", "bipolar disorder", "bipolar i", "bipolar ii",
            "manic episode", "hypomanic episode",
            "major depressive disorder", "recurrent depressive disorder",
            "severe depression", "depressive episode",
            "cyclothymia", "dysthymia",
            # Specific diagnosis phrases
            "diagnosis of schizophrenia", "diagnosed with schizophrenia",
            "diagnosis of bipolar", "diagnosed with bipolar",
            "diagnosis of schizoaffective", "diagnosed with schizoaffective",
            "psychotic illness", "first episode psychosis",
        ],
        "subsections": {
            "schizophrenia_spectrum": [
                "schizophrenia", "schizoaffective", "schizotypal",
                "paranoid schizophrenia", "residual schizophrenia",
            ],
            "mood_disorders": [
                "bipolar disorder", "bipolar affective", "manic episode",
                "major depressive disorder", "recurrent depressive",
                "severe depression",
            ],
            "psychotic_disorders": [
                "delusional disorder", "acute psychotic",
                "brief psychotic", "first episode psychosis",
            ],
        },
    },

    "H7": {
        "title": "History of Problems with Personality Disorder",
        "scope": "historical",
        "terms": [
            # ICD-10 Personality Disorders (F60-F61)
            "personality disorder", "dissocial personality", "emotionally unstable",
            "borderline personality", "antisocial personality", " aspd ", " eupd ", " bpd ",
            "paranoid personality", "schizoid personality", "histrionic personality",
            "narcissistic personality", "avoidant personality", "dependent personality",
            # DSM terms
            "cluster a", "cluster b", "cluster c",
            # Psychopathy assessment (proper clinical terms)
            "psychopathy", "psychopathic", "pcl-r", "pcl score", "psychopathy checklist",
            # Clinical traits (specific to PD)
            "antisocial traits", "borderline traits", "narcissistic traits",
            "lack of remorse", "lack of empathy", "shallow affect",
            "impulsive lifestyle", "irresponsible behaviour",
        ],
        "subsections": {
            "pcl_assessment": [
                "pcl-r", "pcl score", "psychopathy checklist",
                "psychopathy assessment", "factor 1", "factor 2",
            ],
            "psychopathic_traits": [
                "lack of remorse", "lack of empathy",
                "manipulative behaviour", "superficial charm", "grandiose sense",
            ],
        },
    },

    "H8": {
        "title": "History of Problems with Traumatic Experiences",
        "scope": "historical",
        "terms": [
            # Abuse terms (specific)
            "physical abuse", "sexual abuse", "emotional abuse", "psychological abuse",
            "child abuse", "childhood abuse", "was abused", "history of abuse",
            "neglect", "neglected as a child", "childhood neglect",
            # Trauma/PTSD terms (specific phrases to avoid "no PTSD")
            "traumatic experience", "traumatic event", "traumatic history",
            "post-traumatic stress", "ptsd diagnosis", "diagnosed with ptsd",
            "symptoms of ptsd", "trauma symptoms", "trauma-related",
            "complex trauma", "developmental trauma", "childhood trauma",
            # Physical trauma
            "head injury", "traumatic brain injury", " tbi ", "brain injury",
            "road traffic accident", " rta ", "car accident", "motor vehicle accident",
            "serious injury", "physical trauma", "assault victim",
            # Domestic violence
            "domestic violence", "domestic abuse", "witnessed violence",
            "violence in the home", "victim of violence",
            # Adverse childhood experiences
            "adverse childhood", "aces score", "childhood adversity",
            "foster care", "children's home", "local authority care",
            "taken into care", "removed from parents",
            # Loss/bereavement
            "loss of parent", "parental death", "childhood bereavement",
            "separation from parent", "abandoned",
        ],
        "subsections": {
            "violence_in_home": [
                "witnessed violence", "domestic violence", "violence in the home",
                "saw father", "saw mother", "parental violence",
            ],
            "maltreatment": [
                "physical abuse", "sexual abuse", "emotional abuse",
                "childhood abuse", "was abused", "history of abuse",
                "neglect", "childhood neglect", "cruelty",
            ],
            "physical_trauma": [
                "head injury", "brain injury", " tbi ", " rta ",
                "road traffic accident", "car accident", "serious injury",
                "assault victim", "physical trauma",
            ],
            "ptsd_related": [
                "post-traumatic stress", "ptsd diagnosis", "trauma symptoms",
                "complex trauma", "trauma-related", "traumatic experience",
            ],
            "caregiver_disruption": [
                "foster care", "children's home", "taken into care",
                "removed from parents", "local authority care",
                "separated from parent", "abandoned", "loss of parent",
            ],
        },
    },

    "H9": {
        "title": "History of Problems with Violent Attitudes",
        "scope": "historical",
        "terms": [
            # Justification / endorsement of violence
            "he had no choice", "she had no choice", "said he had no choice",
            "said she had no choice", "states had no choice", "stated had no choice",
            "reports had no choice", "claims had no choice",
            "forced my hand", "deserved it", "had it coming",
            "was justified", "necessary response", "only way to deal with",
            "people only understand force",
            # Victim-blaming / externalisation
            "they provoked me", "provoked me", "staff caused it", "victim started it",
            "police exaggerated", "system failed me", "if they hadn't",
            # Grievance / persecution
            "treated unfairly", "people are against me", "constantly disrespected",
            "nobody listens", "everyone is out to get me", "out to get me",
            "feel victimised",
            # Pro-violence identity language
            "don't back down", "won't be pushed around", "pushed around",
            "people need to know", "have to show strength", "show strength",
            "I see red", "see red",
            # Authority / rule hostility
            "rules don't apply", "staff deserved it", "police were corrupt",
            "police were wrong", "courts are biased", "court is biased",
            # Group-based hostility
            "can't be trusted", "staff are useless", "people like them",
            "they're all the same", "all the same",
            # Lack of empathy / remorse for violence
            "no regret", "not my problem", "they'll get over it",
            "wasn't a big deal", "don't feel sorry", "no remorse",
        ],
        "subsections": {
            "justification": [
                "he had no choice", "she had no choice", "said he had no choice",
                "said she had no choice", "states had no choice", "stated had no choice",
                "forced my hand", "deserved it", "had it coming",
                "was justified", "necessary response", "only way",
            ],
            "victim_blaming": [
                "provoked me", "caused it", "started it", "exaggerated",
                "system failed", "if they hadn't", "their fault",
            ],
            "grievance": [
                "treated unfairly", "against me", "disrespected",
                "out to get me", "victimised", "persecuted",
            ],
            "lack_of_remorse": [
                "no regret", "not my problem", "wasn't a big deal",
                "they'll get over", "don't feel sorry", "no remorse",
            ],
        },
    },

    "H10": {
        "title": "History of Problems with Treatment or Supervision Response",
        "scope": "historical",
        "terms": [
            # Medication Non-Adherence
            "non-compliant with medication", "poor adherence", "frequently refuses medication",
            "stopped medication without medical advice", "intermittent compliance",
            "declined prescribed treatment", "not concordant with treatment plan",
            "refused depot", "missed multiple doses", "missed multiple appointments",
            "self-discontinued medication", "medication non-compliance",
            # Disengagement From Services
            "dna appointments", "disengaged from services", "lost to follow-up",
            "poor engagement", "failed to attend repeatedly", "minimal engagement with mdt",
            "does not attend reviews", "refuses community follow-up",
            "uncontactable for prolonged periods", "did not attend",
            # Resistance or Hostility Toward Treatment
            "refuses to engage", "hostile to staff", "dismissive of treatment",
            "lacks insight into need for treatment", "does not believe treatment is necessary",
            "rejects psychological input", "uncooperative with ward rules",
            "oppositional behaviour toward clinicians", "oppositional behavior",
            # Failure Under Supervision
            "breach of conditions", "breach of cto", "breach of probation",
            "recall to hospital", "recalled to hospital", "recalled under cto",
            "recalled from community", "recalled from leave", "cto recall",
            "returned to custody", "readmitted following",
            "non-compliance with licence conditions", "failed community placement",
            "absconded", "awol", "breach", "breached",
            # Ineffective Past Interventions
            "little benefit from treatment", "limited response to interventions",
            "no sustained improvement", "treatment gains not maintained",
            "relapse following discharge", "risk escalated despite treatment",
            "repeated admissions despite support", "treatment resistant",
            # Only Complies Under Compulsion
            "only compliant under section", "engages only when detained",
            "improves under close supervision but deteriorates in community",
            "compliance contingent on legal framework", "responds only to enforced treatment",
            "only engages when detained", "deteriorates in community",
        ],
        "subsections": {
            "medication_non_adherence": [
                "non-compliant with medication", "poor adherence", "frequently refuses medication",
                "stopped medication without medical advice", "intermittent compliance",
                "declined prescribed treatment", "refused depot", "self-discontinued medication",
            ],
            "disengagement_from_services": [
                "dna appointments", "disengaged from services", "lost to follow-up",
                "poor engagement", "failed to attend repeatedly", "minimal engagement",
                "does not attend reviews", "refuses community follow-up", "uncontactable",
            ],
            "resistance_hostility": [
                "refuses to engage", "hostile to staff", "dismissive of treatment",
                "lacks insight into need for treatment", "rejects psychological input",
                "uncooperative with ward rules", "oppositional behaviour",
            ],
            "failure_under_supervision": [
                "breach of conditions", "breach of cto", "breach of probation",
                "recall to hospital", "returned to custody", "failed community placement",
                "absconded", "awol", "non-compliance with licence",
            ],
            "ineffective_interventions": [
                "little benefit from treatment", "limited response to interventions",
                "no sustained improvement", "treatment gains not maintained",
                "relapse following discharge", "risk escalated despite treatment",
            ],
            "complies_under_compulsion": [
                "only compliant under section", "engages only when detained",
                "improves under close supervision", "deteriorates in community",
                "compliance contingent on legal", "responds only to enforced treatment",
            ],
        },
    },

    # ===================== CLINICAL ITEMS (C1-C5) =====================
    # Search LAST 6 MONTHS of notes for current clinical state

    "C1": {
        "title": "Recent Problems with Insight",
        "scope": "clinical",  # Last 6 months only
        "terms": [
            # Insight into mental disorder
            "insight", "poor insight", "limited insight", "absent insight",
            "lack of insight", "partial insight", "good insight", "full insight",
            "acknowledges diagnosis", "accepts diagnosis", "denies illness",
            "does not believe he is unwell", "does not believe she is unwell",
            "nothing wrong with me", "attributes difficulties to others",
            "rejects diagnosis", "voices are part of my illness",
            "recognises relapse signs", "does not recognise", "does not recognize",
            # Insight into link between illness & risk
            "was unwell when that happened", "lacks victim empathy",
            "limited reflection on index offence", "does not link mental state",
            "minimises violence", "denies link", "externalises blame",
            "they provoked me", "anyone would have reacted",
            "no reflection on offence", "understands triggers",
            # Insight into need for treatment
            "accepts need for treatment", "refuses treatment",
            "non-concordant with medication", "lacks understanding of need",
            "engagement improves under section", "accepts medication",
            "engages with mdt", "requests help when unwell",
            "only accepts treatment under compulsion",
            # Stability/fluctuation of insight
            "insight fluctuates", "insight improves with medication",
            "poor insight when acutely unwell", "insight only when well",
            "insight lost during relapse", "disengagement then deterioration",
            # Behavioural indicators
            "stops meds after discharge", "misses appointments",
            "rejects follow-up", "blames services", "recurrent relapse",
        ],
        "subsections": {
            "mental_disorder_insight": [
                "acknowledges diagnosis", "accepts diagnosis", "denies illness",
                "does not believe unwell", "nothing wrong with me",
                "rejects diagnosis", "poor insight", "limited insight",
                "recognises relapse signs", "attributes symptoms externally",
            ],
            "illness_risk_link": [
                "was unwell when that happened", "lacks victim empathy",
                "limited reflection on index offence", "does not link mental state",
                "minimises violence", "externalises blame", "they provoked me",
                "understands triggers", "no reflection on offence",
            ],
            "treatment_need_insight": [
                "accepts need for treatment", "refuses treatment",
                "non-concordant", "lacks understanding of need for treatment",
                "engagement improves under section", "accepts medication",
                "only accepts treatment under compulsion",
            ],
            "insight_stability": [
                "insight fluctuates", "insight improves with medication",
                "poor insight when acutely unwell", "insight only when well",
                "insight lost during relapse",
            ],
            "behavioural_indicators": [
                "stops meds after discharge", "misses appointments",
                "rejects follow-up", "blames services", "recurrent relapse",
                "disengagement", "non-adherence",
            ],
        },
    },

    "C2": {
        "title": "Recent Problems with Violent Ideation or Intent",
        "scope": "clinical",
        "terms": [
            # Explicit violent thoughts or intent
            "thoughts of harming others", "violent thoughts", "feels like hurting",
            "desire to assault", "desire to kill", "threats made", "verbal threats",
            "threatened staff", "threatened family", "made threats",
            # Conditional or contingent violence
            "if they push me", "if someone disrespects me", "i'll snap",
            "defend myself", "don't know what i'll do", "someone will get hurt",
            # Justification or endorsement of violence
            "they deserved it", "anyone would've done the same", "provoked me",
            "violence is part of life", "had to do it", "no choice",
            # Violent ideation linked to mental state
            "command hallucinations to harm", "voices telling him to hurt",
            "voices telling her to hurt", "paranoid with retaliatory",
            "believes others trying to harm", "violent thoughts when paranoid",
            # Recurrent aggressive rumination
            "persistent anger", "grievance", "grudge", "brooding",
            "revenge", "repeated complaints", "escalating language",
            # Threats without action
            "threatened but no follow-through", "aggressive statements",
            "threatening", "intimidating", "verbal aggression",
            # General terms
            "hostile", "hostility", "violent ideation", "homicidal ideation",
        ],
        "subsections": {
            "explicit_violent_ideation": [
                "thoughts of harming others", "violent thoughts", "feels like hurting",
                "desire to assault", "desire to kill", "homicidal ideation",
            ],
            "conditional_violence": [
                "if they push me", "defend myself", "i'll snap",
                "someone will get hurt", "don't know what i'll do",
            ],
            "justification_endorsement": [
                "they deserved it", "anyone would've done the same", "provoked me",
                "violence is part of life", "had to do it",
            ],
            "ideation_linked_symptoms": [
                "command hallucinations to harm", "voices telling to hurt",
                "paranoid with retaliatory", "violent thoughts when paranoid",
            ],
            "aggressive_rumination": [
                "persistent anger", "grievance", "grudge", "brooding",
                "revenge", "escalating language",
            ],
            "threats": [
                "threatened staff", "verbal threats", "made threats",
                "threatening", "aggressive statements",
            ],
        },
    },

    "C3": {
        "title": "Recent Problems with Symptoms of Major Mental Disorder",
        "scope": "clinical",
        "terms": [
            # Psychotic symptoms
            "paranoid ideation", "persecutory beliefs", "persecutory delusions",
            "responding to unseen stimuli", "hearing voices", "command hallucinations",
            "fixed false beliefs", "thoughts are disorganised", "thought disorder",
            "delusional", "hallucinating", "psychotic", "grandiose delusions",
            "jealous delusions", "passivity phenomena",
            # Mania / hypomania
            "manic", "hypomanic", "disinhibited", "overfamiliar",
            "elevated mood", "irritable mood", "grandiosity",
            "reduced need for sleep", "poor impulse control",
            # Severe depression with risk
            "agitated depression", "hopelessness with anger",
            "nihilistic", "paranoid depression", "severe depression",
            # Affective instability
            "emotionally unstable", "affect labile", "easily provoked",
            "low frustration tolerance", "rapid mood shifts", "explosive anger",
            "poor emotional regulation",
            # Anxiety / arousal states
            "hypervigilant", "on edge", "exaggerated threat response",
            "ptsd symptoms exacerbated", "heightened threat perception",
            # Symptoms linked to past violence
            "violence occurred during psychosis", "violence linked to relapse",
            "aggression increases when unwell", "offence in context of",
            # Recency indicators
            "currently experiencing", "recent deterioration", "ongoing symptoms",
            "acute relapse", "actively psychotic", "acutely unwell",
            # Remission (protective)
            "no evidence of psychosis", "euthymic", "symptoms in remission",
            "stable on medication", "mental state stable",
        ],
        "subsections": {
            "psychotic_symptoms": [
                "paranoid ideation", "persecutory beliefs", "persecutory delusions",
                "command hallucinations", "hearing voices", "delusional",
                "hallucinating", "psychotic", "thought disorder",
            ],
            "mania_hypomania": [
                "manic", "hypomanic", "disinhibited", "overfamiliar",
                "elevated mood", "grandiosity", "reduced need for sleep",
            ],
            "severe_depression": [
                "agitated depression", "hopelessness with anger",
                "nihilistic", "severe depression", "paranoid depression",
            ],
            "affective_instability": [
                "emotionally unstable", "affect labile", "easily provoked",
                "low frustration tolerance", "explosive anger",
            ],
            "arousal_anxiety": [
                "hypervigilant", "on edge", "exaggerated threat response",
                "ptsd symptoms exacerbated",
            ],
            "symptoms_linked_violence": [
                "violence occurred during psychosis", "violence linked to relapse",
                "aggression increases when unwell",
            ],
        },
    },

    "C4": {
        "title": "Recent Problems with Instability",
        "scope": "clinical",
        "terms": [
            "impulsive", "impulsivity", "impetuous", "reckless",
            "unpredictable", "erratic", "volatile", "labile",
            "poor impulse control", "acts without thinking",
            "angry outburst", "outburst", "explosive",
            "mood swing", "irritable", "agitated", "restless",
            "distractible", "hyperactive", "adhd", "attention deficit",
        ],
        "subsections": {
            "behavioral_impulsivity": [
                "impulsive", "acts without thinking", "poor impulse control",
                "reckless behaviour", "unpredictable",
            ],
            "lifestyle_impulsivity": [
                "impulsive spending", "risky behaviour", "reckless",
                "dangerous activities", "thrill-seeking",
            ],
            "anger_management": [
                "anger", "angry", "explosive", "outburst", "temper",
                "difficulty managing anger", "anger management",
            ],
            "adhd": [
                "adhd", "attention deficit", "hyperactive", "distractible",
                "concentration problems", "restless",
            ],
        },
    },

    "C5": {
        "title": "Recent Problems with Treatment or Supervision Response",
        "scope": "clinical",
        "terms": [
            "treatment", "therapy", "medication", "compliance", "adherence",
            "response to treatment", "treatment resistant", "refractory",
            "refuses", "declines", "non-compliant", "noncompliant",
            "disengaged", "not engaging", "poor engagement",
            "covert non-compliance", "stockpiling", "cheeking",
            "side effects", "does not attend", "missed appointment",
        ],
        "subsections": {
            "treatment_acceptance": [
                "accepts treatment", "refuses treatment", "agrees to",
                "declines medication", "voluntary", "informal",
            ],
            "treatment_compliance": [
                "compliant", "non-compliant", "adherent", "takes medication",
                "refuses medication", "covert non-compliance",
            ],
            "treatment_responsiveness": [
                "responding to treatment", "treatment resistant",
                "no improvement", "refractory", "tried multiple medications",
            ],
        },
    },

    # ===================== RISK MANAGEMENT ITEMS (R1-R5) =====================
    # Search notes for future-oriented/planning content

    "R1": {
        "title": "Future Problems with Professional Services and Plans",
        "scope": "risk_management",
        "terms": [
            # Plan presence and clarity
            "care plan", "discharge plan", "treatment plan", " cpa ", "risk plan",
            "risk management plan", "crisis plan", "contingency plan", "safety plan",
            "no clear plan", "plan not finalised", "discharge planning incomplete",
            # Risk-informed planning
            "risk not addressed", "does not reflect risks", "no relapse indicators",
            "no escalation strategy", "historical risks", "triggers not addressed",
            # Service intensity and appropriateness
            "insufficient support", "limited community input", "contact inadequate",
            "high intensity", "low intensity", "matched to risk", "appropriate services",
            # Continuity and transitions
            "awaiting allocation", "on waiting list", "no confirmed follow-up",
            "care to be transferred", "gap in care", "handover", "transition",
            # Contingency and escalation
            "early warning signs", "escalation pathway", "recall criteria",
            "out-of-hours", "crisis response", "threshold for admission",
            # Multi-agency coordination
            "mdt involvement", "information sharing", "defined roles",
            "fragmented care", "disputes between services", "unclear responsibility",
            # Protective indicators
            "robust care plan", "risk well managed", "comprehensive plan",
            "services in place", "timely follow-up", "personalised plan",
        ],
        "subsections": {
            "plan_clarity": [
                "care plan", "treatment plan", "risk management plan",
                "no clear plan", "plan not finalised", "discharge planning incomplete",
            ],
            "risk_informed": [
                "risk not addressed", "does not reflect risks", "triggers addressed",
                "relapse indicators", "historical risks",
            ],
            "service_adequacy": [
                "insufficient support", "limited community input", "appropriate services",
                "matched to risk", "service intensity",
            ],
            "transitions": [
                "awaiting allocation", "on waiting list", "gap in care",
                "transition", "handover", "transfer of care",
            ],
            "contingency_planning": [
                "crisis plan", "contingency plan", "early warning signs",
                "escalation pathway", "recall criteria",
            ],
        },
    },

    "R2": {
        "title": "Future Problems with Living Situation",
        "scope": "risk_management",
        "terms": [
            # Accommodation stability
            "no fixed abode", "accommodation not identified", "unstable housing",
            "at risk of eviction", "temporary accommodation", "emergency housing",
            "frequent moves", "sofa-surfing", "homeless", "nfa",
            # Who they live with
            "living with victim", "conflictual family", "volatile relationships",
            "returns to conflict environment", "domestic conflict", "history of violence",
            # Environmental stressors
            "overcrowding", "lack of privacy", "chaotic environment",
            "overwhelming", "shared accommodation", "high-demand",
            # Level of supervision
            "supported accommodation", "staffed setting", "on-site monitoring",
            "unsupervised living", "step-down", "deteriorates without support",
            "requires supported living", "unable to manage independently",
            # Substance access
            "access to substances", "peers use drugs", "peers use alcohol",
            "environment not substance-free", "local triggers",
            # Transitions and change
            "pending move", "recently relocated", "placement breakdown",
            "discharge accommodation", "moving to",
            # Protective factors
            "stable accommodation", "appropriate supported placement",
            "environment conducive to stability", "distance from victims",
            "long-term housing", "calm environment",
        ],
        "subsections": {
            "accommodation_stability": [
                "no fixed abode", "unstable housing", "homeless", "nfa",
                "at risk of eviction", "temporary", "frequent moves",
            ],
            "cohabitants": [
                "living with victim", "conflictual family", "volatile relationships",
                "domestic conflict", "returns to conflict environment",
            ],
            "environmental_stressors": [
                "overcrowding", "chaotic", "overwhelming", "lack of privacy",
                "high-demand environment",
            ],
            "supervision_level": [
                "supported accommodation", "staffed", "unsupervised",
                "deteriorates without support", "requires support",
            ],
            "substance_access": [
                "access to substances", "peers use drugs", "not substance-free",
                "local triggers",
            ],
        },
    },

    "R3": {
        "title": "Future Problems with Personal Support",
        "scope": "risk_management",
        "terms": [
            # Presence of supportive relationships
            "supportive family", "positive relationship", "regular contact",
            "emotional support", "practical support", "crisis support",
            # Weak/absent support
            "limited social support", "socially isolated", "estranged from family",
            "superficial contact", "unreliable contact", "no one to turn to",
            "lives alone", "limited contact",
            # Quality of support
            "encourages treatment", "promotes calm", "appropriate boundaries",
            "recognises warning signs", "reinforces maladaptive", "normalises aggression",
            "undermines treatment", "colludes with avoidance",
            # Conflict within network
            "interpersonal conflict", "volatile relationship", "disputes with family",
            "recurrent arguments", "domestic violence",
            # Antisocial/substance peers
            "antisocial peers", "criminal peers", "substance-using peers",
            "negative peer influence", "mixes with", "pressure to",
            # Reliability under stress
            "support breaks down", "limited availability", "conditional support",
            "inconsistent support", "withdraws during crises",
            # Protective factors
            "family actively involved", "strong protective relationships",
            "supportive network in place", "supportive partner", "stable relationships",
        ],
        "subsections": {
            "supportive_relationships": [
                "supportive family", "positive relationship", "regular contact",
                "crisis support", "family involved",
            ],
            "isolation": [
                "limited social support", "socially isolated", "estranged",
                "lives alone", "no friends", "no one to turn to",
            ],
            "quality_of_support": [
                "encourages treatment", "undermines treatment", "appropriate boundaries",
                "reinforces maladaptive", "normalises aggression",
            ],
            "conflict": [
                "interpersonal conflict", "volatile relationship", "disputes",
                "domestic violence", "recurrent arguments",
            ],
            "negative_peers": [
                "antisocial peers", "criminal peers", "substance-using peers",
                "negative peer influence",
            ],
        },
    },

    "R4": {
        "title": "Future Problems with Treatment or Supervision Response",
        "scope": "risk_management",
        "terms": [
            # Medication adherence
            "non-compliant with medication", "stops medication", "poor concordance",
            "refuses medication", "selective adherence", "partial adherence",
            "depot", "requires supervision", "covert non-compliance",
            "takes medication consistently", "accepts medication",
            # Attendance and engagement
            "fails to attend", "disengaged from services", "poor attendance",
            "misses appointments", " dna ", "avoidance of reviews",
            "late attendance", "inconsistent attendance",
            # Compliance with conditions
            "breach of conditions", "required recall", "absconded", "awol",
            "non-compliant with licence", "enforcement required",
            "cto recall", "conditional discharge recall",
            # Pattern over time
            "repeated disengagement", "history of non-compliance",
            "pattern of disengagement", "cycle of engagement",
            "engagement then discharge then disengagement",
            # Insight-linked non-compliance
            "does not believe medication needed", "rejects supervision",
            "lacks understanding of risk management", "denies need",
            # Response to enforcement
            "only compliant when detained", "becomes hostile when supervised",
            "resists monitoring", "hostility to monitoring", "escalation when challenged",
            # Protective factors
            "consistently engaged", "good adherence over time",
            "actively participates", "voluntary engagement", "insight-driven compliance",
            "uses services proactively", "sustained adherence",
        ],
        "subsections": {
            "medication_adherence": [
                "non-compliant with medication", "stops medication", "refuses medication",
                "takes medication consistently", "depot", "covert non-compliance",
            ],
            "attendance": [
                "fails to attend", "poor attendance", "misses appointments",
                " dna ", "inconsistent attendance",
            ],
            "supervision_compliance": [
                "breach of conditions", "required recall", "absconded",
                "non-compliant with licence", "cto recall",
            ],
            "pattern": [
                "repeated disengagement", "history of non-compliance",
                "pattern of disengagement", "cycle of engagement",
            ],
            "enforcement_response": [
                "only compliant when detained", "resists monitoring",
                "hostility to monitoring", "voluntary engagement",
            ],
        },
    },

    "R5": {
        "title": "Future Problems with Stress or Coping",
        "scope": "risk_management",
        "terms": [
            # Anticipated future stressors
            "upcoming stressors", "likely to face", "transition period",
            "reduced support planned", "discharge stress", "housing uncertainty",
            "relationship strain", "legal proceedings", "financial problems",
            "reduced supervision", "loss of structure",
            # Historical pattern under stress
            "deteriorates under stress", "struggles during transitions",
            "stress preceded incidents", "stress-linked", "stress-triggered",
            "decompensates under stress", "historically struggles",
            # Coping capacity
            "limited coping skills", "requires external containment",
            "coping strategies unlikely", "limited ability to manage",
            "independent coping", "reliance on others", "coping only in structured",
            # Maladaptive coping
            "likely to revert", "history suggests", "risk of relapse",
            "anger as coping", "intimidation", "withdrawal and rumination",
            "blame fixation", "grievance fixation",
            # Substance use as coping
            "substance use likely", "relapse risk high", "uses substances to manage",
            "stress-linked substance use", "copes with alcohol", "copes with drugs",
            # Protective factors
            "demonstrated ability to cope", "effective coping strategies",
            "seeks support early", "rehearsed crisis plan", "help-seeking",
            "coping skills used successfully", "stable supports available",
            # General stress terms
            "stress", "stressor", "overwhelmed", "pressure", "anxious",
            "coping", "resilience", "cannot cope",
        ],
        "subsections": {
            "anticipated_stressors": [
                "upcoming stressors", "transition", "discharge stress",
                "reduced support", "housing uncertainty", "legal proceedings",
            ],
            "stress_pattern": [
                "deteriorates under stress", "struggles during transitions",
                "stress preceded incidents", "decompensates",
            ],
            "coping_capacity": [
                "limited coping skills", "requires containment",
                "coping strategies", "independent coping",
            ],
            "maladaptive_coping": [
                "anger as coping", "withdrawal and rumination",
                "blame fixation", "intimidation as coping",
            ],
            "substance_coping": [
                "substance use likely", "uses substances to manage",
                "stress-linked substance use", "relapse risk",
            ],
        },
    },
}


# ============================================================
# DATE PARSING UTILITIES
# ============================================================

def parse_date_from_note(note: Dict) -> Optional[datetime]:
    """Extract date from a note entry."""
    # Try common date fields
    date_fields = ['date', 'datetime', 'entry_date', 'note_date', 'created', 'timestamp']

    for field in date_fields:
        if field in note and note[field]:
            try:
                if isinstance(note[field], datetime):
                    return note[field]
                return date_parser.parse(str(note[field]), dayfirst=True)
            except:
                continue

    # Try to extract date from text content
    content = note.get('content', '') or note.get('text', '') or str(note)
    date_patterns = [
        r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        r'(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})',
    ]

    for pattern in date_patterns:
        match = re.search(pattern, content, re.I)
        if match:
            try:
                return date_parser.parse(match.group(1), dayfirst=True)
            except:
                continue

    return None


def filter_notes_by_date(notes: List[Dict], months: int = 6) -> List[Dict]:
    """Filter notes to only include those within the specified number of months."""
    cutoff = datetime.now() - timedelta(days=months * 30)
    filtered = []

    for note in notes:
        note_date = parse_date_from_note(note)
        if note_date and note_date >= cutoff:
            filtered.append(note)
        elif not note_date:
            # If we can't determine the date, include it to be safe
            filtered.append(note)

    return filtered


# ============================================================
# EXTRACTION FUNCTIONS
# ============================================================

def get_note_content(note: Dict) -> str:
    """Extract text content from a note entry."""
    if isinstance(note, str):
        return note

    # Try common content fields
    content_fields = ['content', 'text', 'body', 'note', 'entry', 'detail', 'details']
    for field in content_fields:
        if field in note and note[field]:
            return str(note[field])

    # Fallback to string representation
    return str(note)


def search_notes_for_terms(notes: List[Dict], terms: List[str], preprocessed: List[tuple] = None) -> List[Dict]:
    """Search notes for specific terms and return matching excerpts.

    Args:
        notes: List of note dictionaries
        terms: List of search terms
        preprocessed: Optional list of (note, content_lower) tuples for efficiency
    """
    import re
    matches = []

    # Pre-compile lowercase terms for faster lookup
    terms_lower = [t.lower() for t in terms]

    # Build a combined regex pattern for faster initial screening
    # Escape special regex chars and join with |
    escaped_terms = [re.escape(t) for t in terms_lower]
    combined_pattern = re.compile('|'.join(escaped_terms), re.IGNORECASE) if escaped_terms else None

    # Use preprocessed data if available, otherwise process on the fly
    notes_to_search = preprocessed if preprocessed else [(note, get_note_content(note).lower()) for note in notes]

    for note, content in notes_to_search:
        # Quick check: does ANY term exist in this note?
        if combined_pattern and not combined_pattern.search(content):
            continue

        note_matches = []
        seen_excerpts = set()  # Avoid duplicate excerpts

        for term, term_lower in zip(terms, terms_lower):
            if term_lower in content:
                # Find the context around the match
                idx = content.find(term_lower)
                start = max(0, idx - 100)  # Reduced context for speed
                end = min(len(content), idx + len(term) + 100)
                excerpt = content[start:end]

                # Clean up the excerpt
                if start > 0:
                    excerpt = "..." + excerpt
                if end < len(content):
                    excerpt = excerpt + "..."

                excerpt = excerpt.strip()

                # Skip if we've already captured this excerpt
                if excerpt not in seen_excerpts:
                    seen_excerpts.add(excerpt)
                    note_matches.append({
                        'term': term,
                        'excerpt': excerpt,
                    })

                # Limit matches per note for performance
                if len(note_matches) >= 3:
                    break

        if note_matches:
            matches.append({
                'note': note if not preprocessed else note,
                'date': parse_date_from_note(note if not preprocessed else note),
                'matches': note_matches,
            })

    return matches


def extract_for_hcr_item(item_key: str, notes: List[Dict], preprocessed: List[tuple] = None, max_notes: int = 2000) -> Dict[str, Any]:
    """
    Extract relevant information for a specific HCR-20 item.

    Args:
        item_key: The HCR-20 item code (e.g., 'H1', 'C3', 'R5')
        notes: List of note dictionaries
        preprocessed: Optional pre-processed notes (note, content_lower) tuples
        max_notes: Maximum notes to search for historical items (default 2000)

    Returns:
        Dictionary with extracted information for each subsection
    """
    if item_key not in HCR20_EXTRACTION_TERMS:
        return {'error': f'Unknown item: {item_key}'}

    item_config = HCR20_EXTRACTION_TERMS[item_key]
    scope = item_config['scope']

    # Filter notes based on scope
    if scope == 'clinical':
        # Clinical items: only last 6 months
        filtered_notes = filter_notes_by_date(notes, months=6)
    else:
        # Historical and Risk Management: limit to most recent notes for performance
        filtered_notes = notes[:max_notes] if len(notes) > max_notes else notes

    # Pre-process notes for this search (lowercase conversion done once)
    if not preprocessed:
        preprocessed_notes = [(note, get_note_content(note).lower()) for note in filtered_notes]
    else:
        # Filter preprocessed list to match filtered_notes
        filtered_set = set(id(n) for n in filtered_notes)
        preprocessed_notes = [(n, c) for n, c in preprocessed if id(n) in filtered_set]

    # Search for main terms using preprocessed notes
    main_matches = search_notes_for_terms(filtered_notes, item_config['terms'], preprocessed_notes)

    # Only search subsections if we found main matches (optimization)
    subsection_results = {}
    if main_matches:
        for subsection_key, subsection_terms in item_config.get('subsections', {}).items():
            subsection_matches = search_notes_for_terms(filtered_notes, subsection_terms, preprocessed_notes)
            if subsection_matches:
                subsection_results[subsection_key] = subsection_matches

    return {
        'item_key': item_key,
        'title': item_config['title'],
        'scope': scope,
        'notes_searched': len(filtered_notes),
        'total_notes': len(notes),
        'main_matches': main_matches,
        'subsection_matches': subsection_results,
    }


def extract_all_hcr20(notes: List[Dict], max_notes: int = 2000) -> Dict[str, Any]:
    """
    Extract information for all HCR-20 items from notes.

    Args:
        notes: List of note dictionaries
        max_notes: Maximum notes to process for historical items (default 2000)

    Returns:
        Dictionary with results for each HCR-20 item
    """
    results = {}

    # Pre-process notes ONCE for all searches (major optimization)
    # Limit to most recent notes for performance
    notes_to_process = notes[:max_notes] if len(notes) > max_notes else notes
    print(f"[HCR-20 Extractor] Pre-processing {len(notes_to_process)} notes...")
    preprocessed = [(note, get_note_content(note).lower()) for note in notes_to_process]
    print(f"[HCR-20 Extractor] Pre-processing complete. Extracting items...")

    for item_key in HCR20_EXTRACTION_TERMS.keys():
        results[item_key] = extract_for_hcr_item(item_key, notes_to_process, preprocessed, max_notes)

    return results


def format_extraction_for_display(extraction_result: Dict[str, Any]) -> str:
    """
    Format extraction results as readable text for a text field.

    Args:
        extraction_result: Result from extract_for_hcr_item

    Returns:
        Formatted string for display
    """
    if not extraction_result or 'error' in extraction_result:
        return ""

    lines = []

    # Add scope information
    scope = extraction_result.get('scope', 'unknown')
    notes_searched = extraction_result.get('notes_searched', 0)
    total_notes = extraction_result.get('total_notes', 0)

    if scope == 'clinical':
        lines.append(f"[Clinical item - searched {notes_searched} notes from last 6 months]")
    else:
        lines.append(f"[{scope.title()} item - searched {notes_searched} of {total_notes} notes]")
    lines.append("")

    # Add main matches
    main_matches = extraction_result.get('main_matches', [])
    if main_matches:
        lines.append("RELEVANT EXCERPTS FROM NOTES:")
        lines.append("-" * 40)

        for i, match in enumerate(main_matches[:10], 1):  # Limit to 10 matches
            date = match.get('date')
            date_str = date.strftime('%d/%m/%Y') if date else 'Unknown date'

            lines.append(f"\n[{date_str}]")
            for term_match in match.get('matches', [])[:3]:  # Limit terms per note
                lines.append(f"  Found '{term_match['term']}':")
                lines.append(f"  {term_match['excerpt']}")
    else:
        lines.append("No specific matches found in notes for this item.")

    # Add subsection matches
    subsection_matches = extraction_result.get('subsection_matches', {})
    if subsection_matches:
        lines.append("")
        lines.append("SUBSECTION-SPECIFIC FINDINGS:")
        lines.append("-" * 40)

        for subsection, matches in subsection_matches.items():
            subsection_title = subsection.replace('_', ' ').title()
            lines.append(f"\n{subsection_title}:")

            for match in matches[:3]:  # Limit matches per subsection
                date = match.get('date')
                date_str = date.strftime('%d/%m/%Y') if date else 'Unknown date'

                for term_match in match.get('matches', [])[:2]:
                    lines.append(f"  [{date_str}] {term_match['excerpt'][:200]}...")

    return "\n".join(lines)


def get_suggested_rating(extraction_result: Dict[str, Any]) -> Dict[str, str]:
    """
    Suggest presence and relevance ratings based on extraction results.

    Args:
        extraction_result: Result from extract_for_hcr_item

    Returns:
        Dictionary with 'presence' and 'relevance' suggestions
    """
    main_matches = extraction_result.get('main_matches', [])
    subsection_matches = extraction_result.get('subsection_matches', {})

    total_matches = len(main_matches)
    for matches in subsection_matches.values():
        total_matches += len(matches)

    # Suggest presence rating
    if total_matches == 0:
        presence = "Absent"
    elif total_matches <= 3:
        presence = "Possibly/Partially Present"
    else:
        presence = "Present"

    # Suggest relevance based on recency and frequency
    recent_matches = 0
    six_months_ago = datetime.now() - timedelta(days=180)

    for match in main_matches:
        if match.get('date') and match['date'] >= six_months_ago:
            recent_matches += 1

    if total_matches == 0:
        relevance = "Low"
    elif recent_matches >= 3 or total_matches >= 5:
        relevance = "High"
    elif recent_matches >= 1 or total_matches >= 2:
        relevance = "Moderate"
    else:
        relevance = "Low"

    return {
        'presence': presence,
        'relevance': relevance,
        'confidence': 'low' if total_matches < 2 else 'moderate' if total_matches < 5 else 'high',
    }


# ============================================================
# MAIN EXTRACTION INTERFACE
# ============================================================

class HCR20Extractor:
    """
    Main class for extracting HCR-20 relevant data from clinical notes.
    """

    def __init__(self, notes: List[Dict] = None):
        self.notes = notes or []
        self.results = {}

    def set_notes(self, notes: List[Dict]):
        """Set the notes to extract from."""
        self.notes = notes
        self.results = {}  # Clear previous results

    def extract_all(self) -> Dict[str, Any]:
        """Extract information for all HCR-20 items."""
        self.results = extract_all_hcr20(self.notes)
        return self.results

    def extract_item(self, item_key: str) -> Dict[str, Any]:
        """Extract information for a specific HCR-20 item."""
        result = extract_for_hcr_item(item_key, self.notes)
        self.results[item_key] = result
        return result

    def get_formatted_text(self, item_key: str) -> str:
        """Get formatted text for a specific item."""
        if item_key not in self.results:
            self.extract_item(item_key)
        return format_extraction_for_display(self.results.get(item_key, {}))

    def get_suggested_rating(self, item_key: str) -> Dict[str, str]:
        """Get suggested ratings for a specific item."""
        if item_key not in self.results:
            self.extract_item(item_key)
        return get_suggested_rating(self.results.get(item_key, {}))

    def get_summary(self) -> Dict[str, Any]:
        """Get a summary of all extractions."""
        if not self.results:
            self.extract_all()

        summary = {
            'total_notes': len(self.notes),
            'items_with_matches': 0,
            'items_without_matches': 0,
            'by_scope': {
                'historical': {'with_matches': 0, 'without_matches': 0},
                'clinical': {'with_matches': 0, 'without_matches': 0},
                'risk_management': {'with_matches': 0, 'without_matches': 0},
            },
        }

        for item_key, result in self.results.items():
            has_matches = len(result.get('main_matches', [])) > 0
            scope = result.get('scope', 'unknown')

            if has_matches:
                summary['items_with_matches'] += 1
                if scope in summary['by_scope']:
                    summary['by_scope'][scope]['with_matches'] += 1
            else:
                summary['items_without_matches'] += 1
                if scope in summary['by_scope']:
                    summary['by_scope'][scope]['without_matches'] += 1

        return summary

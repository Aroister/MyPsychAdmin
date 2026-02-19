# ============================================================
# PHYSICAL HEALTH EXTRACTOR (FULL COMBINED VERSION)
# MyPsychAdmin 2.3 — 28 Nov 2025
# ============================================================
import re
from datetime import datetime

############################################################
# 1. CANONICAL_BLOODS — MUST BE FIRST
############################################################

CANONICAL_BLOODS = {

    # 1. Albumin
    1: {
        "canonical": "Albumin",
        "synonyms": ["albumin", "serum albumin"],
        "unit": "g/L",
        "max": 70,
        "min": 10,
    },

    # 2. ALP — Alkaline Phosphatase
    2: {
        "canonical": "ALP",
        "synonyms": [
            "alk phos",
            "alkaline phosphatase",
            "alkaline phosphatase (total)",
            "alp"
        ],
        "unit": "IU/L",
        "max": 5000,
        "min": 0,
    },

    # 3. ALT — Alanine aminotransferase
    3: {
        "canonical": "ALT",
        "synonyms": ["alanine aminotransferase", "alt"],
        "unit": "IU/L",
        "max": 10000,
        "min": 0,
    },

    # 4. AST — Aspartate aminotransferase
    4: {
        "canonical": "AST",
        "synonyms": ["aspartate aminotransferase", "ast"],
        "unit": "IU/L",
        "max": 10000,
        "min": 0,
    },

    # 5. Basophils
    5: {
        "canonical": "Basophils",
        "synonyms": ["basophils", "baso", "basophil"],
        "unit": "×10^9/L",
        "max": 10,
        "min": 0,
    },

    # 6. Bilirubin (Total)
    6: {
        "canonical": "Bilirubin",
        "synonyms": ["bilirubin", "bilirubin (total)", "total bilirubin"],
        "unit": "µmol/L",
        "max": 500,
        "min": 0,
    },

    # 7. BM / Blood Sugar
    7: {
        "canonical": "BM",
        "synonyms": ["bm", "blood sugar", "blood glucose (bm)"],
        "unit": "mmol/L",
        "max": 100,
        "min": 1,
    },

    # 8. Calcium
    8: {
        "canonical": "Calcium",
        "synonyms": ["calcium"],
        "unit": "mmol/L",
        "max": 4,
        "min": 1.3,
    },

    # 9. Cholesterol
    9: {
        "canonical": "Cholesterol",
        "synonyms": ["chol", "cholesterol", "total cholesterol"],
        "unit": "mmol/L",
        "max": 20,
        "min": 1,
    },

    # 10. CK — Creatine kinase
    10: {
        "canonical": "CK",
        "synonyms": ["creatine kinase", "ck"],
        "unit": "IU/L",
        "max": 300000,
        "min": 0,
    },

    11: {
        "canonical": "Clozapine",
        "synonyms": [
            "clozapine level",
            "serum clozapine",
            "plasma clozapine",
            "clozapine assay",
            "clozapine concentration",
            "clozapine level:",
            "clozapine assay:",
        ],
        "unit": "mg/l",       # our canonical internal unit
        "min": 0.05,          # therapeutic range 0.05–2.0 mg/L
        "max": 8.0,           # allow high levels but avoid tablet doses
        "convert": {
            "mg/l": 1.0,      # direct
            "µg/l": 0.001,    # convert micrograms per litre → mg/L
            "ug/l": 0.001,
            "ng/ml": 0.001,   # ng/mL → mg/L (1000 ng = 1 µg)
        },
        "allow_missing_unit": True,   # allow raw values but check scale
    },

    # 12. Corrected Calcium
    12: {
        "canonical": "Corrected Calcium",
        "synonyms": [
            "calcium (corrected)",
            "corrected calcium",
            "adj calcium",
            "adjusted calcium"
        ],
        "unit": "mmol/l",
        "min": 2.1,
        "max": 2.7,
    },


    # 13. CRP
    13: {
        "canonical": "CRP",
        "synonyms": [
            "c-reactive protein",
            "c reactive protein",
            "crp"
        ],
        "unit": "mg/l",
        "min": 0,
        "max": 500,
    },

    # 14. Creatinine
    14: {
        "canonical": "Creatinine",
        "synonyms": ["creatinine"],
        "unit": "µmol/L",
        "max": 2000,
        "min": 10,
    },

    # 15. D-Dimers
    15: {
        "canonical": "D-Dimers",
        "synonyms": ["d-dimers", "ddimers", "d dimer", "d-dimer"],
        "unit": "µg/L",
        "max": 20000,
        "min": 0,
    },

    # 16. Eosinophils
    16: {
        "canonical": "Eosinophils",
        "synonyms": ["eosinophils", "eosinophil", "eosino", "eos"],
        "unit": "×10^9/L",
        "max": 10,
        "min": 0,
    },

    # 17. eGFR
    17: {
        "canonical": "eGFR",
        "synonyms": [
            "estimated glomerular filtration rate",
            "egfr",
            "gfr"
        ],
        "unit": "ml/min",
        "min": 10,
        "max": 200,
    },

    # 18. ESR
    18: {
        "canonical": "ESR",
        "synonyms": ["esr", "erythrocyte sedimentation rate"],
        "unit": "mm/hr",
        "max": 150,
        "min": 0,
    },

    # 19. Folate
    19: {
        "canonical": "Folate",
        "synonyms": [
            "serum folate",
            "folate",
            "folic acid"
        ],
        "unit": "ug/l",
        "min": 2,
        "max": 20,
    },

    # 20. Free T4
    20: {
        "canonical": "Free T4",
        "synonyms": [
            "free t4",
            "free thyroxine",
            "serum free thyroxine",
            "t4 level",
            "free t4 level",
            "ft4",
        ],
        "unit": "pmol/l",
        "min": 5,
        "max": 30,
    },

    # 21. Gamma GT
    21: {
        "canonical": "GGT",
        "synonyms": [
            "gamma glutamyl transpeptidase",
            "gamma-glutamyl transpeptidase",
            "gamma gt",
            "gammagt",
            "ggt",
        ],
        "unit": "unit/l",
        "min": 0,
        "max": 200,
    },

    # 22. Globulin
    22: {
        "canonical": "Globulin",
        "synonyms": ["globulin"],
        "unit": "g/L",
        "max": 50,
        "min": 15,
    },

    # 23. Glucose
    23: {
        "canonical": "Glucose",
        "synonyms": ["glucose", "serum glucose"],
        "unit": "mmol/L",
        "max": 100,
        "min": 1,
    },

    # 24. Haematocrit
    24: {
        "canonical": "Haematocrit",
        "synonyms": [
            "haematocrit",
            "hematocrit",
            "hct",
            "haematocrit level",
            "haematocrit level, blood",
        ],
        "unit": "l/l",
        "min": 0.30,
        "max": 0.60,
    },

    # 25. Hb
    25: {
        "canonical": "Hb",
        "synonyms": ["haemoglobin", "haemaglobin", "hb", "haemoglobin level"],
        "unit": "g/L",
        "max": 250,
        "min": 20,
    },

    # 26. HbA1c
    26: {
        "canonical": "HbA1c",
        "synonyms": ["hba1c", "glycated haemoglobin"],
        "unit": "mmol/mol",
        "max": 200,
        "min": 10,
    },

    # 27. HDL Cholesterol
    27: {
        "canonical": "HDL Cholesterol",
        "synonyms": ["hdl", "hdl chol", "hdl cholesterol"],
        "unit": "mmol/L",
        "max": 6,
        "min": 0.2,
    },

    # 28. LDL Cholesterol
    28: {
        "canonical": "LDL Cholesterol",
        "synonyms": ["ldl chol", "ldl cholesterol", "ldl"],
        "unit": "mmol/L",
        "max": 15,
        "min": 0.1,
    },

    # 29. Lithium
    29: {
        "canonical": "Lithium",
        "synonyms": ["lithium level", "lithium"],
        "unit": "mmol/L",
        "max": 5,
        "min": 0.05,
    },

    # 30. Lymphocytes
    30: {
        "canonical": "Lymphocytes",
        "synonyms": ["lymphocyte", "lymphocytes"],
        "unit": "×10^9/L",
        "max": 100,
        "min": 0.05,
    },

    # 31. Magnesium
    31: {
        "canonical": "Magnesium",
        "synonyms": ["magnesium"],
        "unit": "mmol/L",
        "max": 2.5,
        "min": 0.2,
    },

    # 32. Macroprolactin
    32: {
        "canonical": "Macroprolactin",
        "synonyms": ["macroprolactin"],
        "unit": "mIU/L",
        "max": 10000,
        "min": 30,
    },

    # 33. MCH
    33: {
        "canonical": "MCH",
        "synonyms": [
            "mean cell haemoglobin",
            "mean corpuscular haemoglobin",
            "mch",
            "mean cell haemoglobin level",
        ],
        "unit": "pg",
        "min": 20,
        "max": 40,
    },

    # 34. MCHC
    34: {
        "canonical": "MCHC",
        "synonyms": [
            "mchc",
            "mean corpuscular haemoglobin concentration",
            "mean corpuscular hemoglobin concentration",
            "mean corpuscular haemoglobin conc",
            "mean corpuscular hemoglobin conc"
        ],
        "unit": "g/L",
        "max": 420,
        "min": 220,
    },

    # 35. MCV
    35: {
        "canonical": "MCV",
        "synonyms": ["mcv", "mean corpuscular volume"],
        "unit": "fL",
        "max": 140,
        "min": 40,
    },

    # 36. Monocytes
    36: {
        "canonical": "Monocytes",
        "synonyms": ["monocytes", "mono", "monocyte"],
        "unit": "×10^9/L",
        "max": 20,
        "min": 0.01,
    },

    # 37. MPV
    37: {
        "canonical": "MPV",
        "synonyms": ["mpv", "mean platelet volume"],
        "unit": "fL",
        "max": 100,
        "min": 10,
    },

    # 38. Neutrophils
    38: {
        "canonical": "Neutrophils",
        "synonyms": ["neutrophils", "neutro", "neut", "neutrophil"],
        "unit": "×10^9/L",
        "max": 150,
        "min": 0.05,
    },

    # 39. Non-HDL Cholesterol
    39: {
        "canonical": "Non-HDL Cholesterol",
        "synonyms": ["non-hdl chol", "non hdl", "non-hdl cholesterol"],
        "unit": "mmol/L",
        "max": 20,
        "min": 0.5,
    },

    # 40. Norclozapine
    40: {
        "canonical": "Norclozapine",
        "synonyms": ["norclozapine"],
        "unit": "mg/L",
        "max": 4000,
        "min": 50,
    },

    # 41. PCV
    41: {
        "canonical": "PCV",
        "synonyms": ["pcv", "haematocrit", "hematocrit", "hct"],
        "unit": "L/L",
        "max": 0.8,
        "min": 0.05,
    },

    # 42. Platelets
    42: {
        "canonical": "Platelets",
        "synonyms": ["platelets", "plt", "platelet"],
        "unit": "×10^9/L",
        "max": 2000,
        "min": 3,
    },

    # 43. Potassium
    43: {
        "canonical": "Potassium",
        "synonyms": ["potassium", "k+"],
        "unit": "mmol/L",
        "max": 8.5,
        "min": 1.5,
    },

    # 44. Prolactin
    44: {
        "canonical": "Prolactin",
        "synonyms": ["prolactin", "macroprolactin"],
        "unit": "mIU/L",
        "max": 20000,
        "min": 30,
    },

    # 45. PSA
    45: {
        "canonical": "PSA",
        "synonyms": ["psa", "prostate specific antigen"],
        "unit": "ng/mL",
        "max": 2000,
        "min": 0.01,
    },

    # 46. RDW
    46: {
        "canonical": "RDW",
        "synonyms": [
            "rdw",
            "red cell distribution width",
            "red blood cell distribution width",
            "distribution width"
        ],
        "unit": "%",
        "max": 30,
        "min": 8,
    },

    # 47. Red Cell Count
    47: {
        "canonical": "Red Cell Count",
        "synonyms": ["red blood cell count", "red cell count", "rbc", "rbc count", "red blood cell"],
        "unit": "×10^12/L",
        "max": 8,
        "min": 1,
    },

    # 48. Sodium
    48: {
        "canonical": "Sodium",
        "synonyms": ["sodium", "na"],
        "unit": "mmol/L",
        "max": 180,
        "min": 80,
    },

    # 49. Thyroxine (Free)
    49: {
        "canonical": "Thyroxine (Free)",
        "synonyms": ["thyroxine (free)", "free thyroxine", "free t4", "t4 free"],
        "unit": "pmol/L",
        "max": 100,
        "min": 2,
    },

    # 50. Total/HDL Cholesterol Ratio
    50: {
        "canonical": "Total/HDL Cholesterol Ratio",
        "synonyms": [
            "tot/hdl chol ratio",
            "total hdl chol ratio",
            "cholesterol ratio",
            "chol ratio"
        ],
        "unit": "ratio",
        "max": 20,
        "min": 1,
    },

    # 51. Total Protein
    51: {
        "canonical": "Total Protein",
        "synonyms": ["total protein", "tp"],
        "unit": "g/L",
        "max": 120,
        "min": 30,
    },

    # 52. Triglycerides
    52: {
        "canonical": "Triglycerides",
        "synonyms": ["triglyceride", "triglycerides", "tri"],
        "unit": "mmol/L",
        "max": 100,
        "min": 0.1,
    },

    # 53. TSH
    53: {
        "canonical": "TSH",
        "synonyms": ["tsh", "thyroid stimulating hormone"],
        "unit": "mIU/L",
        "max": 100,
        "min": 0.01,
    },

    # 54. Urea
    54: {
        "canonical": "Urea",
        "synonyms": ["urea", "serum urea"],
        "unit": "mmol/L",
        "max": 80,
        "min": 0.5,
    },

    # 55. Urine Albumin
    55: {
        "canonical": "Urine Albumin",
        "synonyms": ["urine albumin", "urinary albumin"],
        "unit": "mg/L",
        "max": 3000,
        "min": 0,
    },

    # 56. Urine Creatinine
    56: {
        "canonical": "Urine Creatinine",
        "synonyms": ["urine creatinine"],
        "unit": "mg/L",
        "max": 500,
        "min": 1,
    },

    # 57. Vitamin B12
    57: {
        "canonical": "Vitamin B12",
        "synonyms": [
            "vitamin b12",
            "b12 level",
            "serum vitamin b12",
            "vit b12"
        ],
        "unit": "ng/l",   # matches NHS
        "min": 100,
        "max": 1500,
    },


    # 58. WBC
    58: {
        "canonical": "WBC",
        "synonyms": [
            "wbc",
            "wcc",
            "white cell count",
            "white blood cell count",
            "white blood count",
            "white cell",
            "white cells",
            "white blood cells",
            "white count",
            "total white count",
            "leukocytes",
            "leucocytes"
        ],
        "unit": "×10^9/L",
        "max": 200,
        "min": 0.1,
    },

    59: {
        "canonical": "Vitamin D",
        "synonyms": [
            "vitamin d",
            "vit d",
            "25-hydroxy vitamin d",
            "25 hydroxy vitamin d",
            "25-oh vitamin d",
            "25 oh vitamin d",
            "vitamin d level",
            "vit d level",
            "25-ohd"
        ],
        "unit": "nmol/l",
        "min": 10,
        "max": 200,
        "allow_missing_unit": True  # VERY IMPORTANT for NHS letters
    },

    60: {
        "canonical": "Vitamin B12",
        "synonyms": [
            "vitamin b12",
            "b12 level",
            "serum vitamin b12",
            "vit b12"
        ],
        "unit": "ng/l",   # matches NHS
        "min": 100,
        "max": 1500,
    },

    61: {
        "canonical": "Urate",
        "synonyms": [
            "serum urate",
            "urate",
            "uric acid"
        ],
        "unit": "umol/l",
        "min": 150,
        "max": 450,
    },

    62: {
        "canonical": "Phosphate",
        "synonyms": [
            "serum phosphate",
            "phosphate",
            "inorganic phosphate"
        ],
        "unit": "mmol/l",
        "min": 0.5,
        "max": 2.0,
    },



}

############################################################
# 2. EXPECTED_UNITS MAP
############################################################
    # ---------- BLOCK MEDICATION / NON-BLOOD TERMS ----------
BLOCK_TERMS = {
    "clozapine", "olanzapine", "zuclopenthixol", "zaponex",
    "diazepam", "kwells", "clopixol", "olanzapine", "liquid clozapine",
    "antipsychotic", "depot", "titration", "nocte", "mg"
}

    # If a line includes one of these → DO NOT extract anything from it
EXPECTED_UNITS = {bid: meta["unit"] for bid, meta in CANONICAL_BLOODS.items()}

############################################################
# 3. AUTO-GENERATE SYNONYMS (must run AFTER CANONICAL_BLOODS)
############################################################


def build_auto_synonyms():
    """
    Automatically generates extensive synonym lists for each blood test,
    based on canonical names and provided synonyms.
    Produces 20–60 variations per test covering NHS formats.
    """
    expanded = {}

    COMMON_PREFIXES = [
        "", "serum ", "plasma ", "blood ", "level ", "serum level ",
        "serum ", "serum ", "adjusted ", "total ", "corrected ",
    ]

    COMMON_SUFFIXES = [
        "", " level", " levels", " count", " concentration",
        " result", " results",
    ]

    EXTRA_PATTERNS = [
        "{}",
        "{} level",
        "{} levels",
        "{} concentration",
        "{} (total)",
        "serum {}",
        "{} level, serum",
        "{} level, blood",
        "{} count",
        "{} count, blood",
        "{} level plasma",
        "{} plasma",
        "serum {} level",
        "{} measurement",
        "{} test",
        "{} value"
    ]

    for bid, meta in CANONICAL_BLOODS.items():
        base = meta["canonical"].lower()
        syns = [s.lower() for s in meta.get("synonyms", [])]

        generated = set()

        # base forms
        core_names = set([base] + syns)

        for name in core_names:
            # direct name
            generated.add(name)

            # prefix/suffix generation
            for pre in COMMON_PREFIXES:
                generated.add((pre + name).strip())
                for suf in COMMON_SUFFIXES:
                    generated.add((pre + name + suf).strip())

            # pattern based
            for p in EXTRA_PATTERNS:
                generated.add(p.format(name).strip())

            # fix hyphens/slashes/spaces
            generated.add(name.replace(" / ", " "))
            generated.add(name.replace("/", " "))
            generated.add(name.replace("-", " "))
            generated.add(name.replace("  ", " "))

        # assign
        expanded[bid] = list(generated)

    return expanded

AUTO_SYNONYMS = build_auto_synonyms()

############################################################
# 4. TOKEN MAP — token → bid
############################################################
TOKEN_MAP = {}   # token → (bid, expected_unit)

for bid, syn_list in AUTO_SYNONYMS.items():
    unit = CANONICAL_BLOODS[bid]["unit"].lower()
    for syn in syn_list:
        TOKEN_MAP[syn] = (bid, unit)

############################################################
# 5. SORT TOKENS LONGEST-FIRST FOR REGEX SAFETY
############################################################
SORTED_TOKENS = sorted(TOKEN_MAP.keys(), key=len, reverse=True)

############################################################
# 6. Utility: safe float
############################################################

def _safe_float(x):
    """
    Convert to float safely.
    Handles <0.2 and >9 errors by stripping operators.
    """
    if x is None:
        return None
    x = x.strip().lstrip("<>").replace(",", "")
    try:
        return float(x)
    except:
        return None
############################################################
# 7. Utility: normalise units
############################################################

def _norm_unit(u: str) -> str:
    """
    Normalise lab units to a consistent comparable form.
    """
    if not u:
        return ""

    u = u.strip().lower()

    # common normalisations
    u = u.replace("μ", "µ")           # unify micro symbol
    u = u.replace("umol", "µmol")
    u = u.replace("u/l", "iu/l")
    u = u.replace("units/l", "iu/l")
    u = u.replace("unit/l", "iu/l")
    u = u.replace("unit", "iu")

    # fix micro-exponent formats
    u = u.replace("x10*9/l", "×10^9/l")
    u = u.replace("x 10*9/l", "×10^9/l")
    u = u.replace("x10^9/l", "×10^9/l")
    u = u.replace("10^9/l", "×10^9/l")

    u = u.replace("x10*12/l", "×10^12/l")
    u = u.replace("x 10*12/l", "×10^12/l")
    u = u.replace("x10^12/l", "×10^12/l")
    u = u.replace("10^12/l", "×10^12/l")

    # strip trailing full stops, spaces
    u = u.replace(".", "").strip()

    return u

############################################################
# 8. extract_bloods_from_text wrapper
############################################################
def extract_bloods_from_text(text):
    """
    Wrapper to guarantee a safe list response.
    """
    try:
        out = extract_bloods(text)
        if out is None:
            return []
        return out
    except Exception as e:
        print("!! extract_bloods_from_text ERROR:", e)
        return []

############################################################
# 9. NHS-STYLE BLOOD EXTRACTOR — FAST v3
############################################################
def extract_bloods(text):
    """
    NHS-compatible blood extractor — Flexible Mode.
    Handles Serum/Plasma/Blood prefixed tests, variant units, NHS x10*9 formats,
    and enforces correct test-specific units + min/max sanity.
    Includes Clozapine scale/unit fixer.
    """

    if not text:
        return []

    # working copy
    t = text.lower()

    # Fix NHS glitches where H/L flags glue onto numbers
    # Example: "CountH5.56" → "Count 5.56"
    t = re.sub(r"([a-z])([hHlL])([0-9])", r"\1 \3", t)

    results = []
    seen = set()

    # --- UNIT NORMALISATION ---
    def norm_unit(u):
        if not u:
            return ""

        u = u.lower().strip()
        u = u.replace("μ", "µ")
        u = u.replace("u", "µ") if "mol" in u else u
        u = u.replace(" ", "")

        # ×10 ranges
        u = u.replace("x10*9/l", "×10^9/l").replace("x10^9/l", "×10^9/l")
        u = u.replace("x10*12/l", "×10^12/l").replace("x10^12/l", "×10^12/l")

        # ALT/AST/GGT: "unit/l", "u/l" → "iu/l"
        u = u.replace("unit/l", "iu/l").replace("u/l", "iu/l")

        replacements = {
            "g/l": "g/l", "g\\l": "g/l",
            "mmol/l": "mmol/l",
            "µmol/l": "µmol/l", "umol/l": "µmol/l",
            "iu/l": "iu/l",
            "miu/l": "miu/l", "munit/l": "miu/l",
            "fl": "fl",
            "pg": "pg",
            "l/l": "l/l",
            "%": "%",
            "ratio": "ratio",
            "ng/ml": "ng/ml", "pg/ml": "pg/ml",
            "×10^9/l": "×10^9/l",
            "×10^12/l": "×10^12/l",
        }
        return replacements.get(u, u)

    # --- MAIN EXTRACTION LOOP ---
    for bid, meta in CANONICAL_BLOODS.items():
        syns = meta.get("synonyms", [])
        expected_unit = norm_unit(meta.get("unit", ""))

        # find synonym in text
        syn_found = None
        for syn in syns:
            s = syn.lower()
            if s in t:
                syn_found = s
                break

        if not syn_found:
            continue

        # scan line by line — more accurate
        for line in t.split("\n"):
            if syn_found not in line:
                continue

            patt = rf"""
                {re.escape(syn_found)}
                (?:[^0-9]{{0,80}})?                 # allow extra wording like "level, plasma"
                (?P<val>[0-9]+(?:\.[0-9]+)?)        # capture the number (value)
                (?:\s*(?:h|l|high|low))?            # allow H/L flags
                \s*
                (?P<unit>
                    g\/?l|G\/?L|
                    mmol\/?l|
                    µ?mol\/?l|umol\/?l|
                    iu\/?l|unit\/?l|u\/?l|iu|
                    miu\/?l|munit\/?l|mu\/?l|
                    ng\/ml|pg\/ml|
                    fL|fl|
                    l\/?l|
                    %|
                    ratio|
                    mg\/l| \bmg\b |
                    (?:x|×)\s*10[\*\^]?9\/?l|
                    (?:x|×)\s*10[\*\^]?12\/?l
                )?
            """

            for m in re.finditer(patt, line, flags=re.IGNORECASE | re.VERBOSE):
                raw_val = m.group("val")
                raw_unit = m.group("unit")

                try:
                    val = float(raw_val)
                except:
                    continue

                if raw_unit:
                    unit = norm_unit(raw_unit)
                else:
                    unit = ""

                # ---------------------------------------------------------------------
                # CLOZAPINE SPECIAL HANDLING (bid == 11)
                # ---------------------------------------------------------------------
                if bid == 11:

                    # If no unit was extracted → REJECT (prevents dose extraction)
                    if not raw_unit:
                        continue

                    u = unit.lower()
                    conv = meta.get("convert", {})

                    # If unit explicitly appears in conversion table → convert to mg/L
                    if u in conv:
                        val = val * conv[u]
                        unit = "mg/l"

                    else:
                        # Accept only mg/L or µg/L variants
                        if u not in ("mg/l", "µg/l", "ug/l"):
                            continue

                        # µg/L → mg/L
                        if u in ("µg/l", "ug/l"):
                            val = val / 1000
                            unit = "mg/l"

                # ---------------------------------------------------------------------
                # MIN/MAX CHECK (reject impossible narrative numbers)
                # ---------------------------------------------------------------------
                min_v = meta["min"]
                max_v = meta["max"]
                if val < min_v or val > max_v:
                    continue

                # ---------------------------------------------------------------------
                # UNIT MUST MATCH (except whitelist)
                # ---------------------------------------------------------------------
                allow_missing = bid in {21, 44, 13, 18, 11}  # GGT/Prolactin/CRP/ESR/Clozapine

                if not raw_unit:
                    if not allow_missing:
                        continue
                else:
                    if bid != 11:  # clozapine already handled
                        if unit != expected_unit:
                            continue

                # avoid duplicates
                if bid in seen:
                    continue
                seen.add(bid)

                results.append((bid, val))

    return results


# ============================================================
# DATE NORMALISATION
# ============================================================

def _normalise_date(x):
    if isinstance(x, datetime):
        return x
    if not x:
        return None
    try:
        return datetime.strptime(x, "%Y-%m-%d %H:%M:%S")
    except:
        try:
            return datetime.strptime(x, "%Y-%m-%d")
        except:
            return None

# ============================================================
# HELPERS
# ============================================================

def _safe_float(x):
    try:
        return float(x)
    except:
        return None

def _latest_entry(entries):
    if not entries:
        return None
    clean = []
    for e in entries:
        d = e.get("date")
        nd = _normalise_date(d)
        if nd:
            e2 = dict(e)
            e2["date"] = nd
            clean.append(e2)
    if not clean:
        return None
    clean.sort(key=lambda z: z["date"])
    return clean[-1]

# ============================================================
# MAX FILTERS (VBA-STYLE FALSE POSITIVE REMOVAL)
# ============================================================

MAX_FILTERS = {
    "ALP": 1000, "Alanine aminotransferase": 1000, "ALT": 1000,
    "AST": 1000, "CK": 40000000, "CRP": 1000, "Hb": 138, "LDL": 100,
    "MCH": 100, "MCHC": 1000, "MCV": 200, "MPV": 100, "PCV": 4,
    "TSH": 10, "ALP (total)": 1000, "Albumin": 1000,
    "Alkaline Phosphatase": 1000, "Basophils": 4,
    "Bilirubin": 5, "blood sugar": 147, "BM": 100,
    "C reactive protein": 1000, "Calcium": 9, "Chol": 44,
    "Cholesterol": 44, "Corrected Calcium": 9,
    "Creatinine": 7380, "D-Dimers": 230000, "eGFR": 150, "ESR": 100,
    "Folate": 100, "Free T4": 100, "GGT": 100, "Globulin": 1000,
    "Glucose": 147, "Haemoglobin": 138, "HbA1c": 200, "HDL": 100,
    "Heamatocrit": 100, "Lithium level": 3, "Lymphocyte": 10,
    "Macroprolactin": 10000, "Magnesium": 4, "Monocytes": 4,
    "Neutrophil": 200, "Non-HDL Chol": 100, "Norclozapine": 2,
    "Phosphate": 4, "Platelet": 10000, "Potassium": 7, "Prolactin": 3000,
    "PSA": 100, "RDW": 100, "Red cell count": 100, "Sodium": 200,
    "Thyroid stimulating hormone": 10, "Thyroxine (free)": 100,
    "Total Protein": 1000, "Triglyceride": 100, "Urea": 100,
    "Urine albumin": 100, "Urine creatinine": 100000,
    "Vitamin B12": 10000, "WBC": 100, "White cell count": 100,
}

# ============================================================
# BLOOD SEARCH TABLE (INITIAL TRIGGER SCAN)
# ============================================================

BLOOD_SEARCH_TABLE = [
    # (marker_id internally handled by CANONICAL_BLOODS)
    ("haemoglobin",  "mol", None),
    ("bilirubin",    "mol", None),
    ("creatinine",   "mol", None),
    ("alkaline",     "mol", None),
    ("calcium",      "mol", None),
    ("potassium",    "mol", None),
    ("sodium",       "mol", None),
    ("glucose",      "mol", None),
    ("lipid",        None, None),
    ("ck",           None, None),
    ("cholesterol",  None, None),
    ("triglyceride", None, None),
    ("crp",          None, None),
    ("vitamin",      None, None),
    ("folate",       None, None),
    ("b12",          None, None),
]

############################################################
# 10. extract_physical_health_from_notes
############################################################

BMI_REGEX = re.compile(
    r'\bBMI\b[^0-9]{0,8}([0-9]+(?:\.[0-9]+)?)',
    flags=re.IGNORECASE
)

def extract_bmi_from_text(text):
    if not text:
        return None
    m = BMI_REGEX.search(text)
    if not m:
        return None
    val = _safe_float(m.group(1))
    if val:
        return {"bmi": val}
    return None

# ============================================================
# BLOOD PRESSURE PARSER
# ============================================================

BP_REGEX = re.compile(
    r'(\bBP\b|\bBlood Pressure\b)[^0-9]{0,10}(\d{2,3})\s*/\s*(\d{2,3})',
    flags=re.IGNORECASE
)

def extract_bp_from_text(text):
    if not text:
        return None
    out = []
    for m in BP_REGEX.finditer(text):
        sys = _safe_float(m.group(2))
        dia = _safe_float(m.group(3))
        if sys and dia:
            out.append({"sys": sys, "dia": dia})
    return out


# ============================================================
# EXPECTED UNITS (AUTO-MAPPED FROM CANONICAL_BLOODS)
# ============================================================

EXPECTED_UNITS = {
    bid: CANONICAL_BLOODS[bid]["unit"].strip().lower()
    for bid in CANONICAL_BLOODS
}

def extract_physical_health_from_notes(notes):
    bmi_list = []
    bp_list = []
    bloods = {}

    print("\n======= RUNNING FULL EXTRACTOR =======")

    for n in notes:
        txt = n.get("content", "") or ""
        date = n.get("date") or n.get("datetime")

        # --- BMI ---
        bmi = extract_bmi_from_text(txt)
        if bmi:
            bmi_list.append({"date": date, **bmi})

        # --- BP ---
        bp = extract_bp_from_text(txt)
        for entry in (bp or []):
            bp_list.append({"date": date, **entry})

        # --- BLOODS ---
        hits = extract_bloods_from_text(txt)
        for bid, val in hits:
            meta = CANONICAL_BLOODS.get(bid, {})
            bloods.setdefault(bid, []).append({
                "date": date,
                "value": val,
                "unit": meta.get("unit", ""),
                "name": meta.get("canonical", f"Test {bid}")

            })


    print("Extractor result summary:")
    print(" BMI entries:  ", len(bmi_list))
    print(" BP entries:   ", len(bp_list))
    print(" Blood entries:", sum(len(v) for v in bloods.values()))

    return {
        "bmi": bmi_list,
        "bp": bp_list,
        "bloods": bloods,
    }


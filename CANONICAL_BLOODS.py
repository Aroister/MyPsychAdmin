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
            "25-hydroxy vitamin d",
            "vitamin d",
            "25 hydroxy vitamin d",
            "25-oh vitamin d",
            "25ohd"
        ],
        "unit": "nmol/l",
        "min": 10,
        "max": 250,
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

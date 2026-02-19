from __future__ import annotations

from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
ICD10_FILE = BASE_DIR / "ICD10_DICT.txt"


def load_icd10_dict() -> dict:
    """
    Expected line formats:
        PRIORITY; Diagnosis | FCODE
        PRIORITY; Diagnosis - FCODE   (legacy fallback)

    Examples:
        4; Schizophrenia | F20
        3; Acute psychosis - F23
    """
    out = {}

    if not ICD10_FILE.exists():
        raise FileNotFoundError(f"ICD-10 file not found: {ICD10_FILE}")

    with ICD10_FILE.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()

            if not line or ";" not in line:
                continue

            try:
                priority_part, rest = line.split(";", 1)
                severity = int(priority_part.strip())
                rest = rest.strip()

                if " | " in rest:
                    diagnosis, icd10_code = rest.rsplit(" | ", 1)
                elif " - " in rest:
                    diagnosis, icd10_code = rest.rsplit(" - ", 1)
                else:
                    # Diagnosis-only row (allowed but code empty)
                    diagnosis = rest
                    icd10_code = ""

                diagnosis = diagnosis.strip()
                icd10_code = icd10_code.strip()

                if not diagnosis:
                    continue

                out[diagnosis] = {
                    "severity": severity,
                    "diagnosis": diagnosis,
                    "icd10": icd10_code,
                }

            except Exception as e:
                print(f"[ICD10] Skipped line: {line} ({e})")

    print(f"[ICD10] Loaded {len(out)} diagnoses")
    return out



# --------------------------------------------------
# CANONICAL EXPORT
# --------------------------------------------------
ICD10_DICT = load_icd10_dict()

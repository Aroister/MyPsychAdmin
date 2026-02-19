def load_icd10_dict(path: str) -> dict:
    """
    Expected line format:
        PRIORITY; Diagnosis text | ICDCODE
    """
    out = {}

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            try:
                priority_part, rest = line.split(";", 1)
                severity = int(priority_part.strip())
                rest = rest.strip()

                if " | " in rest:
                    diagnosis, code = rest.rsplit(" | ", 1)
                else:
                    # If no ICD code, keep diagnosis but leave code empty
                    diagnosis = rest
                    code = ""

                diagnosis = diagnosis.strip()
                code = code.strip()

                out[diagnosis] = {
                    "severity": severity,
                    "diagnosis": diagnosis,
                    "icd10": code,
                }

            except Exception as e:
                print(f"[ICD10] Skipped line: {line} ({e})")

    print(f"[ICD10] Loaded {len(out)} diagnoses")
    return out

# importer_common.py
# Shared cleaning utilities for all importer modules.

import re

def clean_line(line: str) -> str:
    """
    Normalises raw Excel text into a usable line.
    - Removes control characters
    - Fixes weird spacing
    - Strips whitespace
    """
    if not line:
        return ""

    # Remove tabs and control chars
    line = re.sub(r"[\t\r\n]+", " ", line)

    # Collapse multiple spaces
    line = re.sub(r"\s{2,}", " ", line)

    return line.strip()

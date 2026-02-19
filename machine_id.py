import uuid
import hashlib
import platform

def get_machine_id():
    """
    Stable hardware identifier based on multiple system parameters.
    Does NOT expose personal data. Hashes to anonymise raw values.
    """

    raw = [
        platform.node(),
        platform.machine(),
        platform.processor(),
        str(uuid.getnode()),  # MAC address
    ]

    text = "|".join(raw)
    return hashlib.sha256(text.encode()).hexdigest()[:32]

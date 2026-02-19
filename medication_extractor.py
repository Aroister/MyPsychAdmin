# ===============================================================
# ULTRA-FAST TOKEN-BASED MEDICATION EXTRACTOR (Hybrid Mode C)
# ~1–2 seconds for 14,000 notes
# Fully cross-platform, no dependencies
# ===============================================================

import re
from datetime import datetime

BUILT = False
TOKEN_MAP = {}        # token -> (key, canonical)
META_MAP = {}         # key -> metadata
FIRST_CHARS = {}      # first char -> list of tokens


# ---------------------------------------------------------------
# BUILD FAST TOKEN INDEX
# ---------------------------------------------------------------

def build_token_index(MEDS):
    global BUILT, TOKEN_MAP, META_MAP, FIRST_CHARS
    if BUILT:
        return

    for key, meta in MEDS.items():
        META_MAP[key] = meta
        canonical = meta["canonical"]

        for syn in meta.get("patterns", []):
            s = syn.lower().strip()
            if not s:
                continue
            TOKEN_MAP[s] = (key, canonical)

            first = s[0]
            FIRST_CHARS.setdefault(first, []).append(s)

    BUILT = True


# ---------------------------------------------------------------
# TOKENISER (extremely fast)
# ---------------------------------------------------------------

def fast_tokenise(text):
    """
    Converts "clozapine 25 mg OD" → ["clozapine", "25mg", "od"]
    """
    text = text.lower()
    # protect decimals
    text = re.sub(r'(?<=\d)\.(?=\d)', 'DOT', text)
    text = re.sub(r'[^a-z0-9DOT]+', ' ', text)
    text = text.replace("DOT", ".")
    tokens = text.split()
    return tokens


# ---------------------------------------------------------------
# DOSE PARSER (token based — extremely fast)
# ---------------------------------------------------------------

UNIT_SET = {"mg","mcg","µg","g","units","iu"}

# Common drug-name suffixes (pharmacological stems)
_DRUG_SUFFIXES = (
    "pine", "lol", "pril", "sartan", "azole", "mycin", "statin",
    "mab", "nib", "tide", "pam", "lam", "done", "ine", "ole",
    "ril", "oxin", "afil", "etine", "xaban", "vaptan", "semide",
)

def parse_dose(tokens, idx):
    """
    Look at token idx-3 → idx+3 for dose tokens.
    """
    start = max(idx - 3, 0)
    end = min(idx + 3, len(tokens))

    for i in range(start, end):
        tok = tokens[i]

        # 1) Combined token e.g. 10mg
        m = re.match(r'(\d+(?:\.\d+)?)(mg|mcg|µg|g|units|iu)$', tok)
        if m:
            return float(m.group(1)), m.group(2)

        # 2) Separate tokens e.g. "10" + "mg"
        if tok.isdigit() or re.match(r'\d+\.\d+', tok):
            if i+1 < end and tokens[i+1] in UNIT_SET:
                return float(tok), tokens[i+1]

    return None, None


# ---------------------------------------------------------------
# FREQ / ROUTE PARSERS
# ---------------------------------------------------------------

FREQ_SET = {"od","bd","tds","qds","qid","nocte","mane","stat","prn",
            "daily","weekly","monthly"}

ROUTE_SET = {"po","oral","im","sc","iv","neb","inhaled","topical",
             "subcut","intramuscular","intravenous"}


def parse_route_freq(tokens, idx):
    end = min(idx + 4, len(tokens))
    route = None
    freq = None

    for i in range(idx, end):
        tok = tokens[i]
        if tok in ROUTE_SET:
            route = tok
        elif tok in FREQ_SET:
            freq = tok

    return route, freq


# ---------------------------------------------------------------
# PLAUSIBILITY CHECK
# ---------------------------------------------------------------

DOSE_TOLERANCE = 0.05

def plausible(strength, meta):
    allowed = meta.get("allowed_strengths")
    if not allowed:
        return True
    for a in allowed:
        if abs(strength - float(a)) <= DOSE_TOLERANCE:
            return True
    return False


# ---------------------------------------------------------------
# MAIN ULTRA-FAST EXTRACTOR
# ---------------------------------------------------------------

def extract_medications_from_notes(notes, MEDS):
    build_token_index(MEDS)

    results = []
    unrecognised = set()

    for n in notes:
        raw = n.get("content", "") or ""
        tokens = fast_tokenise(raw)

        for i, tok in enumerate(tokens):
            first = tok[0]
            # quick reject: if no synonym starts with this letter
            if first not in FIRST_CHARS:
                continue

            # fast exact match
            if tok in TOKEN_MAP:
                key, canonical = TOKEN_MAP[tok]
                meta = META_MAP[key]

                strength, unit = parse_dose(tokens, i)
                if strength is None or not plausible(strength, meta):
                    continue

                route, freq = parse_route_freq(tokens, i)

                date = n.get("date") or n.get("datetime")

                results.append({
                    "med_key": key,
                    "canonical": canonical,
                    "raw": tok,
                    "strength": strength,
                    "unit": unit,
                    "route": route,
                    "frequency": freq,
                    "date": date,
                })
            else:
                # Check for unrecognised medication-like tokens:
                # token has a dose nearby OR ends with a drug suffix
                if len(tok) < 3 or tok in FREQ_SET or tok in ROUTE_SET or tok in UNIT_SET:
                    continue
                dose_nearby, _ = parse_dose(tokens, i)
                has_suffix = any(tok.endswith(s) for s in _DRUG_SUFFIXES)
                if dose_nearby is not None or has_suffix:
                    unrecognised.add(tok)

    print(f"[ULTRA-FAST-MEDS] extracted {len(results)} items, {len(unrecognised)} unrecognised")
    return {"medications": results, "unrecognised_tokens": sorted(unrecognised)}

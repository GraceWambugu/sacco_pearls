import re

_DROP = {"SACCO", "SOCIETY", "LTD", "LIMITED", "DT", "THE"}


def normalize_name(name: str) -> str:
    """Turn 'STIMA DT.' / 'Stima DT-SACCO' into one matching key: 'STIMA'.
    Used so the same SACCO matches across different SASRA reports."""
    s = str(name).upper().replace("&", " AND ")
    s = re.sub(r"[^A-Z0-9 ]", " ", s)
    tokens = [t for t in s.split() if t not in _DROP]
    return " ".join(tokens) if tokens else str(name).upper().strip()

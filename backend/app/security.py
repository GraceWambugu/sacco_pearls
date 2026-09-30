"""Password hashing (Argon2id) and JWT helpers."""
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from .config import ACCESS_TOKEN_MINUTES, ALGORITHM, SECRET_KEY

_ph = PasswordHasher()  # Argon2id with a random salt per password
# Verified against when the email doesn't exist, so login takes similar time either way.
_DUMMY_HASH = _ph.hash("not-a-real-password")


def hash_password(plain: str) -> str:
    return _ph.hash(plain)


def verify_password(stored_hash: str, plain: str) -> bool:
    try:
        return _ph.verify(stored_hash, plain)
    except (VerifyMismatchError, InvalidHashError):
        return False


def verify_dummy(plain: str) -> None:
    verify_password(_DUMMY_HASH, plain)


def create_access_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_MINUTES),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> int | None:
    """Return the user id, or None if the token is invalid/expired."""
    try:
        data = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return int(data["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None

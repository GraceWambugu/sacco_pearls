import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..mailer import email_delivery_configured, send_password_reset_email
from ..models import PasswordResetToken, User
from ..schemas import ForgotPasswordRequest, PasswordResetRequest, Token, UserCreate, UserOut
from ..security import create_access_token, hash_password, verify_dummy, verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(data: UserCreate, db: Session = Depends(get_db)):
    email = data.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already registered")
    user = User(
        email=email,
        password_hash=hash_password(data.password),
        full_name=data.full_name,
        role="member",  # nobody can self-register as admin
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """The 'username' field of the form is the email."""
    user = db.scalar(select(User).where(User.email == form.username.lower()))
    if user is None:
        verify_dummy(form.password)
        ok = False
    else:
        ok = verify_password(user.password_hash, form.password) and user.is_active
    if not ok:
        # one generic message: don't reveal whether the email exists
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"})
    return Token(access_token=create_access_token(user.id))


@router.post("/forgot-password", status_code=status.HTTP_202_ACCEPTED)
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    if not email_delivery_configured():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Password reset email is not configured on this server",
        )

    message = "If the account exists, a password reset token has been sent."
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    if user is None:
        return {"message": message}

    now = datetime.now(timezone.utc)
    recent = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id)
        .order_by(PasswordResetToken.created_at.desc())
    )
    if recent is not None:
        created_at = recent.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        if now - created_at < timedelta(minutes=1):
            return {"message": message}

    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
    previous_tokens = db.scalars(
        select(PasswordResetToken).where(PasswordResetToken.user_id == user.id)
    ).all()
    for previous_token in previous_tokens:
        db.delete(previous_token)
    reset_token = PasswordResetToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=now + timedelta(minutes=20),
    )
    db.add(reset_token)
    try:
        db.flush()
        send_password_reset_email(user.email, raw_token)
        db.commit()
    except Exception as error:
        db.rollback()
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Could not send the password reset email. Try again later.",
        ) from error
    return {"message": message}


@router.post("/reset-password")
def reset_password(data: PasswordResetRequest, db: Session = Depends(get_db)):
    token_hash = hashlib.sha256(data.token.encode("utf-8")).hexdigest()
    reset_token = db.scalar(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
    )
    now = datetime.now(timezone.utc)
    if reset_token is None or reset_token.consumed_at is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired reset token")

    expires_at = reset_token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= now:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired reset token")

    user = db.get(User, reset_token.user_id)
    if user is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired reset token")

    reset_token.consumed_at = now
    user.password_hash = hash_password(data.new_password)
    db.commit()
    return {"message": "Password reset successfully. You can now sign in."}

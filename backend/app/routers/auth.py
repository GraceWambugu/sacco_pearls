from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User
from ..schemas import Token, UserCreate, UserOut
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

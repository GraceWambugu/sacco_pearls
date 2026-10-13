from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


def _check_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not any(c.isalpha() for c in v) or not any(c.isdigit() for c in v):
        raise ValueError("Password must contain at least one letter and one digit")
    return v


# ---------- users / auth ----------
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str = Field(min_length=1, max_length=120)

    @field_validator("password")
    @classmethod
    def _pw(cls, v):
        return _check_password(v)


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    password: Optional[str] = None

    @field_validator("password")
    @classmethod
    def _pw(cls, v):
        return _check_password(v) if v is not None else v


class UserOut(BaseModel):  # note: NO password / password_hash field, ever
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    full_name: str
    role: str
    is_active: bool
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class PasswordResetRequest(BaseModel):
    token: str = Field(min_length=30, max_length=128)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _pw(cls, v):
        return _check_password(v)


# ---------- saccos ----------
class SaccoCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    county: Optional[str] = Field(default=None, max_length=80)


class SaccoUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    county: Optional[str] = Field(default=None, max_length=80)


class SaccoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    county: Optional[str] = None
    is_archived: bool = False


# ---------- financial metrics ----------
class MetricFields(BaseModel):
    total_assets: Optional[float] = None
    total_deposits: Optional[float] = None
    gross_loans: Optional[float] = None
    total_income: Optional[float] = None
    cca: Optional[float] = None
    ccd: Optional[float] = None
    ica: Optional[float] = None
    ext_borrowing: Optional[float] = None
    npl_ratio: Optional[float] = Field(default=None, ge=0)
    liquidity_ratio: Optional[float] = None
    data_stale: bool = False
    source_page: Optional[int] = None


class MetricCreate(MetricFields):
    data_year: int = Field(ge=2000, le=2100)


class MetricUpdate(BaseModel):
    total_assets: Optional[float] = None
    total_deposits: Optional[float] = None
    gross_loans: Optional[float] = None
    total_income: Optional[float] = None
    cca: Optional[float] = None
    ccd: Optional[float] = None
    ica: Optional[float] = None
    ext_borrowing: Optional[float] = None
    npl_ratio: Optional[float] = Field(default=None, ge=0)
    liquidity_ratio: Optional[float] = None
    data_stale: Optional[bool] = None
    source_page: Optional[int] = None


class MetricOut(MetricFields):
    model_config = ConfigDict(from_attributes=True)
    id: int
    sacco_id: int
    data_year: int


# ---------- watchlists ----------
class WatchlistCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    sacco_ids: list[int] = Field(default_factory=list, max_length=3)  # compare up to 3


class WatchlistUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    sacco_ids: Optional[list[int]] = Field(default=None, max_length=3)


class WatchlistOut(BaseModel):
    id: int
    name: str
    created_at: datetime
    saccos: list[SaccoOut]

import re
from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

PASSWORD_REGEX = re.compile(
    r"""
    ^                 # 시작
    (?=.*[A-Za-z])    # 영문자 최소 1개
    (?=.*\d)          # 숫자 최소 1개
    (?=.*[^A-Za-z0-9])# 특수문자 최소 1개
    .{8,}             # 전체 길이 8자 이상
    $                 # 끝
    """,
    re.VERBOSE,
)

PASSWORD_RULE_MESSAGE = (
    "비밀번호는 8자 이상이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다."
)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=20)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not PASSWORD_REGEX.match(v):
            raise ValueError(PASSWORD_RULE_MESSAGE)
        return v

    name: str
    gender: str | None = None
    address: Optional[str] = None
    patient_code: str = Field(min_length=1, description="플랫폼 환자코드")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class EmailVerifyRequest(BaseModel):
    token: str


class PasswordResetStartRequest(BaseModel):
    email: EmailStr


class PasswordResetFinishRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=20)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if not PASSWORD_REGEX.match(v):
            raise ValueError(PASSWORD_RULE_MESSAGE)
        return v


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=20)

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not PASSWORD_REGEX.match(v):
            raise ValueError(PASSWORD_RULE_MESSAGE)
        return v

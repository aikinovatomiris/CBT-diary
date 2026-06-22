from datetime import timedelta

import pytest
from fastapi import HTTPException

from app.models import User
from app.security import (
    create_access_token,
    decode_access_token_user_id,
    hash_password,
    require_admin,
    verify_password,
)


def test_password_is_hashed_and_can_be_verified():
    plain_password = "strong-password"
    password_hash = hash_password(plain_password)

    assert password_hash != plain_password
    assert verify_password(plain_password, password_hash) is True
    assert verify_password("wrong-password", password_hash) is False


def test_access_token_round_trip_returns_user_id():
    token = create_access_token(
        {"sub": "42"},
        expires_delta=timedelta(minutes=5),
    )

    assert decode_access_token_user_id(token) == 42


def test_expired_access_token_is_rejected():
    token = create_access_token(
        {"sub": "42"},
        expires_delta=timedelta(seconds=-1),
    )

    assert decode_access_token_user_id(token) is None


def test_invalid_access_token_is_rejected():
    assert decode_access_token_user_id("not-a-jwt") is None


def test_require_admin_accepts_admin_user():
    admin = User(role="admin")

    assert require_admin(admin) is admin


def test_require_admin_rejects_regular_user():
    regular_user = User(role="user")

    with pytest.raises(HTTPException) as error:
        require_admin(regular_user)

    assert error.value.status_code == 403

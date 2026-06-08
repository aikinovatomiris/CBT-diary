import os
import secrets
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import TherapistProfile, User
from app.schemas import (
    GoogleLoginRequest,
    TherapistRegisterRequest,
    TherapistRegisterResponse,
    TokenResponse,
    UserCreate,
    UserLogin,
    UserResponse,
)
from app.security import (
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES,
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)


router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)


def create_token_response_for_user(user: User) -> dict:
    access_token_expires = timedelta(
        minutes=JWT_ACCESS_TOKEN_EXPIRE_MINUTES
    )

    access_token = create_access_token(
        data={
            "sub": str(user.id),
        },
        expires_delta=access_token_expires,
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
    }


def get_google_client_ids() -> list[str]:
    raw_client_ids = os.getenv("GOOGLE_CLIENT_IDS") or os.getenv("GOOGLE_CLIENT_ID")

    if not raw_client_ids:
        return []

    return [
        client_id.strip()
        for client_id in raw_client_ids.split(",")
        if client_id.strip()
    ]


def verify_google_id_token_or_401(id_token_value: str) -> dict:
    google_client_ids = get_google_client_ids()

    if not google_client_ids:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GOOGLE_CLIENT_IDS не настроен в .env",
        )

    try:
        from google.auth.transport.requests import Request # type: ignore
        from google.oauth2 import id_token # type: ignore
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Пакет google-auth не установлен. Выполните pip install -r requirements.txt",
        )

    last_error = None

    for client_id in google_client_ids:
        try:
            id_info = id_token.verify_oauth2_token(
                id_token_value,
                Request(),
                client_id,
            )

            email = id_info.get("email")
            email_verified = id_info.get("email_verified")

            if not email:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Google token не содержит email",
                )

            if email_verified is not True and str(email_verified).lower() != "true":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Google email не подтвержден",
                )

            return id_info

        except ValueError as error:
            last_error = error
            continue

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Недействительный Google id_token",
    )


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
):
    existing_user = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Пользователь с таким email уже зарегистрирован",
        )

    new_user = User(
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        name=user_data.name,
        role="user",
        assistant_style="supportive",
        auth_provider="local",
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


@router.post(
    "/register-therapist",
    response_model=TherapistRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_therapist(
    therapist_data: TherapistRegisterRequest,
    db: Session = Depends(get_db),
):
    existing_user = (
        db.query(User)
        .filter(User.email == therapist_data.email)
        .first()
    )

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Пользователь с таким email уже зарегистрирован",
        )

    new_user = User(
        email=therapist_data.email,
        hashed_password=hash_password(therapist_data.password),
        name=therapist_data.name,
        role="therapist",
        assistant_style=None,
        auth_provider="local",
    )

    db.add(new_user)
    db.flush()

    therapist_profile = TherapistProfile(
        user_id=new_user.id,
        full_name=therapist_data.full_name,
        qualification=therapist_data.qualification,
        status="draft",
        online_available=True,
    )

    db.add(therapist_profile)
    db.commit()

    db.refresh(new_user)
    db.refresh(therapist_profile)

    return {
        "user": new_user,
        "therapist_profile_id": therapist_profile.id,
    }


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login_user(
    user_data: UserLogin,
    db: Session = Depends(get_db),
):
    user = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )

    is_password_valid = verify_password(
        plain_password=user_data.password,
        hashed_password=user.hashed_password,
    )

    if not is_password_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )

    return create_token_response_for_user(user)


@router.post(
    "/google",
    response_model=TokenResponse,
)
def login_with_google(
    google_data: GoogleLoginRequest,
    db: Session = Depends(get_db),
):
    google_user_data = verify_google_id_token_or_401(
        id_token_value=google_data.id_token,
    )

    email = google_user_data.get("email", "").strip().lower()
    name = (
        google_user_data.get("name")
        or google_user_data.get("given_name")
        or email.split("@")[0]
    )

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        random_unusable_password = secrets.token_urlsafe(32)

        user = User(
            email=email,
            hashed_password=hash_password(random_unusable_password),
            name=name,
            role="user",
            assistant_style="supportive",
            auth_provider="google",
        )

        db.add(user)
        db.commit()
        db.refresh(user)

    return create_token_response_for_user(user)


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_me(
    current_user: User = Depends(get_current_user),
):
    return current_user
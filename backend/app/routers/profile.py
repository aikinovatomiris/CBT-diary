from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import (
    AssistantStyleUpdate,
    ChangePasswordRequest,
    ChangePasswordResponse,
    UserResponse,
)
from app.security import get_current_user, hash_password, verify_password
from app.schemas import UpdateUserNameRequest, UserResponse


router = APIRouter(
    prefix="/profile",
    tags=["Profile"],
)


@router.patch(
    "/assistant-style",
    response_model=UserResponse,
)
def update_assistant_style(
    style_data: AssistantStyleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user.assistant_style = style_data.assistant_style

    db.commit()
    db.refresh(current_user)

    return current_user


@router.patch(
    "/change-password",
    response_model=ChangePasswordResponse,
)
def change_password(
    password_data: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.auth_provider == "google":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для аккаунта, созданного через Google, пароль в приложении не используется",
        )

    is_old_password_correct = verify_password(
        plain_password=password_data.old_password,
        hashed_password=current_user.hashed_password,
    )

    if not is_old_password_correct:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Старый пароль указан неверно",
        )

    current_user.hashed_password = hash_password(
        password_data.new_password
    )

    db.commit()

    return {
        "message": "Пароль успешно изменен"
    }
    
@router.patch(
    "/name",
    response_model=UserResponse,
)
def update_user_name(
    name_data: UpdateUserNameRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_name = name_data.name.strip()

    if not new_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Имя не может быть пустым",
        )

    current_user.name = new_name

    db.commit()
    db.refresh(current_user)

    return current_user
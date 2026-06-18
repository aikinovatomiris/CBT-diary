from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
)
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import (
    TherapistFavorite,
    TherapistProfile,
    User,
)
from app.schemas import (
    PublicTherapistProfileResponse,
    TherapistFavoriteActionResponse,
)
from app.security import decode_access_token_user_id


router = APIRouter(
    prefix="/therapists",
    tags=["Public Therapists"],
)


optional_bearer_scheme = HTTPBearer(
    auto_error=False,
)


def get_optional_current_user(
    credentials: Optional[
        HTTPAuthorizationCredentials
    ] = Depends(optional_bearer_scheme),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """
    Позволяет каталогу оставаться доступным без JWT.

    Если Authorization-заголовка нет:
        возвращает None.

    Если JWT передан:
        проверяет токен и возвращает пользователя.

    Некорректный или просроченный JWT возвращает 401,
    а не маскируется под неавторизованного пользователя.
    """

    if credentials is None:
        return None

    user_id = decode_access_token_user_id(
        credentials.credentials,
    )

    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Не удалось подтвердить авторизацию",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Пользователь не найден",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    return user


def require_regular_user(
    current_user: Optional[User],
) -> User:
    """
    Проверяет, что запрос выполняет обычный пользователь.

    Закладки недоступны:
    - гостю;
    - терапевту;
    - администратору.
    """

    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Для работы с закладками необходимо войти в аккаунт",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Закладки доступны только обычным пользователям",
        )

    return current_user


def get_approved_therapist_or_404(
    profile_id: int,
    db: Session,
) -> TherapistProfile:
    therapist_profile = (
        db.query(TherapistProfile)
        .filter(
            TherapistProfile.id == profile_id,
            TherapistProfile.status == "approved",
        )
        .first()
    )

    if not therapist_profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Терапевт не найден",
        )

    return therapist_profile


def get_user_favorite_profile_ids(
    current_user: Optional[User],
    db: Session,
) -> set[int]:
    """
    Возвращает ID профилей терапевтов,
    добавленных текущим пользователем в закладки.

    Для гостя, therapist и admin возвращает пустой set.
    """

    if (
        current_user is None
        or current_user.role != "user"
    ):
        return set()

    rows = (
        db.query(
            TherapistFavorite.therapist_profile_id,
        )
        .filter(
            TherapistFavorite.user_id
            == current_user.id,
        )
        .all()
    )

    return {
        row[0]
        for row in rows
    }


def build_public_therapist_response(
    therapist_profile: TherapistProfile,
    is_favorite: bool,
) -> dict:
    """
    Формирует ответ публичного каталога.

    Существующие JSON-поля и названия не меняются.
    Добавляется только is_favorite.
    """

    return {
        "id": therapist_profile.id,
        "user_id": therapist_profile.user_id,
        "full_name": therapist_profile.full_name,
        "qualification": (
            therapist_profile.qualification
        ),
        "therapy_approaches": (
            therapist_profile.therapy_approaches
        ),
        "specializations": (
            therapist_profile.specializations
        ),
        "description": (
            therapist_profile.description
        ),
        "price": therapist_profile.price,
        "contacts": therapist_profile.contacts,
        "city": therapist_profile.city,
        "online_available": (
            therapist_profile.online_available
        ),
        "photo_url": therapist_profile.photo_url,
        "created_at": therapist_profile.created_at,
        "is_favorite": is_favorite,
    }


@router.get(
    "",
    response_model=List[
        PublicTherapistProfileResponse
    ],
)
def get_approved_therapists(
    city: Optional[str] = Query(
        default=None,
    ),
    specialization: Optional[str] = Query(
        default=None,
    ),
    online_available: Optional[bool] = Query(
        default=None,
    ),
    favorites_only: bool = Query(
        default=False,
        description=(
            "Показывать только терапевтов, "
            "добавленных текущим пользователем "
            "в закладки"
        ),
    ),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    """
    Возвращает каталог одобренных терапевтов.

    Поддерживает фильтры:
    - city;
    - specialization;
    - online_available;
    - favorites_only.

    Без JWT каталог продолжает работать,
    но is_favorite будет false.

    favorites_only=true доступен только role=user.
    """

    query = (
        db.query(TherapistProfile)
        .filter(
            TherapistProfile.status == "approved",
        )
    )

    if favorites_only:
        user = require_regular_user(
            current_user,
        )

        query = (
            query
            .join(
                TherapistFavorite,
                TherapistFavorite.therapist_profile_id
                == TherapistProfile.id,
            )
            .filter(
                TherapistFavorite.user_id
                == user.id,
            )
        )

    if city:
        normalized_city = city.strip()

        if normalized_city:
            query = query.filter(
                TherapistProfile.city.ilike(
                    f"%{normalized_city}%"
                )
            )

    if specialization:
        normalized_specialization = (
            specialization.strip()
        )

        if normalized_specialization:
            query = query.filter(
                TherapistProfile.specializations.ilike(
                    f"%{normalized_specialization}%"
                )
            )

    if online_available is not None:
        query = query.filter(
            TherapistProfile.online_available
            == online_available
        )

    therapists = (
        query
        .order_by(
            TherapistProfile.created_at.desc(),
            TherapistProfile.id.desc(),
        )
        .all()
    )

    favorite_profile_ids = (
        get_user_favorite_profile_ids(
            current_user=current_user,
            db=db,
        )
    )

    return [
        build_public_therapist_response(
            therapist_profile=therapist,
            is_favorite=(
                therapist.id
                in favorite_profile_ids
            ),
        )
        for therapist in therapists
    ]


@router.get(
    "/favorites",
    response_model=List[
        PublicTherapistProfileResponse
    ],
)
def get_favorite_therapists(
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    """
    Возвращает все одобренные профили,
    добавленные текущим пользователем в закладки.
    """

    user = require_regular_user(
        current_user,
    )

    therapists = (
        db.query(TherapistProfile)
        .join(
            TherapistFavorite,
            TherapistFavorite.therapist_profile_id
            == TherapistProfile.id,
        )
        .filter(
            TherapistFavorite.user_id == user.id,
            TherapistProfile.status == "approved",
        )
        .order_by(
            TherapistFavorite.created_at.desc(),
            TherapistProfile.id.desc(),
        )
        .all()
    )

    return [
        build_public_therapist_response(
            therapist_profile=therapist,
            is_favorite=True,
        )
        for therapist in therapists
    ]


@router.post(
    "/{profile_id}/favorite",
    response_model=TherapistFavoriteActionResponse,
    status_code=status.HTTP_200_OK,
)
def add_therapist_to_favorites(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    """
    Добавляет одобренного терапевта
    в закладки текущего пользователя.

    Endpoint идемпотентный:
    повторный запрос не создаёт дубликат.
    """

    user = require_regular_user(
        current_user,
    )

    get_approved_therapist_or_404(
        profile_id=profile_id,
        db=db,
    )

    existing_favorite = (
        db.query(TherapistFavorite)
        .filter(
            TherapistFavorite.user_id
            == user.id,
            TherapistFavorite.therapist_profile_id
            == profile_id,
        )
        .first()
    )

    if existing_favorite:
        return {
            "message": (
                "Терапевт уже добавлен в закладки"
            ),
            "therapist_profile_id": profile_id,
            "is_favorite": True,
        }

    favorite = TherapistFavorite(
        user_id=user.id,
        therapist_profile_id=profile_id,
    )

    db.add(favorite)

    try:
        db.commit()

    except IntegrityError:
        db.rollback()

        # Возможна параллельная повторная отправка.
        # Уникальное ограничение не даст создать дубликат.
        existing_favorite = (
            db.query(TherapistFavorite)
            .filter(
                TherapistFavorite.user_id
                == user.id,
                TherapistFavorite.therapist_profile_id
                == profile_id,
            )
            .first()
        )

        if existing_favorite:
            return {
                "message": (
                    "Терапевт уже добавлен "
                    "в закладки"
                ),
                "therapist_profile_id": (
                    profile_id
                ),
                "is_favorite": True,
            }

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Не удалось добавить терапевта "
                "в закладки"
            ),
        )

    return {
        "message": (
            "Терапевт добавлен в закладки"
        ),
        "therapist_profile_id": profile_id,
        "is_favorite": True,
    }


@router.delete(
    "/{profile_id}/favorite",
    response_model=TherapistFavoriteActionResponse,
)
def remove_therapist_from_favorites(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    """
    Удаляет терапевта из закладок.

    Endpoint идемпотентный:
    если закладки уже нет, возвращает успешный ответ.
    """

    user = require_regular_user(
        current_user,
    )

    favorite = (
        db.query(TherapistFavorite)
        .filter(
            TherapistFavorite.user_id
            == user.id,
            TherapistFavorite.therapist_profile_id
            == profile_id,
        )
        .first()
    )

    if favorite is None:
        return {
            "message": (
                "Терапевт уже удалён из закладок"
            ),
            "therapist_profile_id": profile_id,
            "is_favorite": False,
        }

    db.delete(favorite)
    db.commit()

    return {
        "message": (
            "Терапевт удалён из закладок"
        ),
        "therapist_profile_id": profile_id,
        "is_favorite": False,
    }


@router.get(
    "/{profile_id}",
    response_model=PublicTherapistProfileResponse,
)
def get_approved_therapist_by_id(
    profile_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    therapist_profile = (
        get_approved_therapist_or_404(
            profile_id=profile_id,
            db=db,
        )
    )

    is_favorite = False

    if (
        current_user is not None
        and current_user.role == "user"
    ):
        favorite_exists = (
            db.query(TherapistFavorite.id)
            .filter(
                TherapistFavorite.user_id
                == current_user.id,
                TherapistFavorite.therapist_profile_id
                == therapist_profile.id,
            )
            .first()
            is not None
        )

        is_favorite = favorite_exists

    return build_public_therapist_response(
        therapist_profile=therapist_profile,
        is_favorite=is_favorite,
    )
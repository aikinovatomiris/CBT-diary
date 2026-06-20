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
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import (
    Conversation,
    TherapistFavorite,
    TherapistProfile,
    TherapistRating,
    User,
)
from app.schemas import (
    PublicTherapistProfileResponse,
    TherapistFavoriteActionResponse,
    TherapistRatingActionResponse,
    TherapistRatingRequest,
    TherapistRatingStatusResponse,
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
    
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Для выполнения действия "
                "необходимо войти в аккаунт"
            ),
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Действие доступно только "
                "обычным пользователям"
            ),
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


# ============================================================
# FAVORITES HELPERS
# ============================================================

def get_user_favorite_profile_ids(
    current_user: Optional[User],
    db: Session,
) -> set[int]:
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


def get_is_favorite(
    profile_id: int,
    current_user: Optional[User],
    db: Session,
) -> bool:
    if (
        current_user is None
        or current_user.role != "user"
    ):
        return False

    return (
        db.query(TherapistFavorite.id)
        .filter(
            TherapistFavorite.user_id
            == current_user.id,
            TherapistFavorite.therapist_profile_id
            == profile_id,
        )
        .first()
        is not None
    )


# ============================================================
# RATING HELPERS
# ============================================================

def get_rating_summary(
    profile_id: int,
    db: Session,
) -> tuple[Optional[float], int]:
    row = (
        db.query(
            func.avg(TherapistRating.rating),
            func.count(TherapistRating.id),
        )
        .filter(
            TherapistRating.therapist_profile_id
            == profile_id,
        )
        .first()
    )

    if row is None:
        return None, 0

    average_value = row[0]
    ratings_count = int(
        row[1] or 0
    )

    if average_value is None:
        return None, ratings_count

    return round(
        float(average_value),
        1,
    ), ratings_count


def get_rating_summaries(
    profile_ids: list[int],
    db: Session,
) -> dict[int, tuple[Optional[float], int]]:
    if not profile_ids:
        return {}

    rows = (
        db.query(
            TherapistRating.therapist_profile_id,
            func.avg(TherapistRating.rating),
            func.count(TherapistRating.id),
        )
        .filter(
            TherapistRating.therapist_profile_id.in_(
                profile_ids
            )
        )
        .group_by(
            TherapistRating.therapist_profile_id
        )
        .all()
    )

    summaries: dict[
        int,
        tuple[Optional[float], int],
    ] = {}

    for (
        profile_id,
        average_value,
        ratings_count,
    ) in rows:
        summaries[profile_id] = (
            round(
                float(average_value),
                1,
            )
            if average_value is not None
            else None,
            int(ratings_count or 0),
        )

    return summaries


def get_current_user_rating(
    profile_id: int,
    current_user: Optional[User],
    db: Session,
) -> Optional[int]:
    if (
        current_user is None
        or current_user.role != "user"
    ):
        return None

    row = (
        db.query(TherapistRating.rating)
        .filter(
            TherapistRating.user_id
            == current_user.id,
            TherapistRating.therapist_profile_id
            == profile_id,
        )
        .first()
    )

    if row is None:
        return None

    return int(row[0])


def can_user_rate_therapist(
    therapist_profile: TherapistProfile,
    current_user: Optional[User],
    db: Session,
) -> bool:
    if (
        current_user is None
        or current_user.role != "user"
    ):
        return False

    return (
        db.query(Conversation.id)
        .filter(
            Conversation.user_id
            == current_user.id,
            Conversation.therapist_user_id
            == therapist_profile.user_id,
        )
        .first()
        is not None
    )


# ============================================================
# RESPONSE BUILDER
# ============================================================

def build_public_therapist_response(
    therapist_profile: TherapistProfile,
    is_favorite: bool,
    average_rating: Optional[float] = None,
    ratings_count: int = 0,
    current_user_rating: Optional[int] = None,
    can_rate: bool = False,
) -> dict:
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
        "average_rating": average_rating,
        "ratings_count": ratings_count,
        "current_user_rating": current_user_rating,
        "can_rate": can_rate,
    }


# ============================================================
# GET /therapists
# ============================================================

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

    profile_ids = [
        therapist.id
        for therapist in therapists
    ]

    rating_summaries = get_rating_summaries(
        profile_ids=profile_ids,
        db=db,
    )

    return [
        build_public_therapist_response(
            therapist_profile=therapist,
            is_favorite=(
                therapist.id
                in favorite_profile_ids
            ),
            average_rating=(
                rating_summaries.get(
                    therapist.id,
                    (None, 0),
                )[0]
            ),
            ratings_count=(
                rating_summaries.get(
                    therapist.id,
                    (None, 0),
                )[1]
            ),
        )
        for therapist in therapists
    ]


# ============================================================
# GET /therapists/favorites
# ============================================================

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

    profile_ids = [
        therapist.id
        for therapist in therapists
    ]

    rating_summaries = get_rating_summaries(
        profile_ids=profile_ids,
        db=db,
    )

    return [
        build_public_therapist_response(
            therapist_profile=therapist,
            is_favorite=True,
            average_rating=(
                rating_summaries.get(
                    therapist.id,
                    (None, 0),
                )[0]
            ),
            ratings_count=(
                rating_summaries.get(
                    therapist.id,
                    (None, 0),
                )[1]
            ),
        )
        for therapist in therapists
    ]


# ============================================================
# POST /therapists/{profile_id}/favorite
# ============================================================

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


# ============================================================
# DELETE /therapists/{profile_id}/favorite
# ============================================================

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


# ============================================================
# GET /therapists/{profile_id}/rating-status
# ============================================================

@router.get(
    "/{profile_id}/rating-status",
    response_model=TherapistRatingStatusResponse,
)
def get_therapist_rating_status(
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

    average_rating, ratings_count = (
        get_rating_summary(
            profile_id=profile_id,
            db=db,
        )
    )

    current_user_rating = (
        get_current_user_rating(
            profile_id=profile_id,
            current_user=current_user,
            db=db,
        )
    )

    can_rate = can_user_rate_therapist(
        therapist_profile=therapist_profile,
        current_user=current_user,
        db=db,
    )

    return {
        "therapist_profile_id": profile_id,
        "average_rating": average_rating,
        "ratings_count": ratings_count,
        "current_user_rating": (
            current_user_rating
        ),
        "can_rate": can_rate,
    }


# ============================================================
# PUT /therapists/{profile_id}/rating
# ============================================================

@router.put(
    "/{profile_id}/rating",
    response_model=TherapistRatingActionResponse,
)
def create_or_update_therapist_rating(
    profile_id: int,
    rating_data: TherapistRatingRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(
        get_optional_current_user,
    ),
):
    user = require_regular_user(
        current_user,
    )

    therapist_profile = (
        get_approved_therapist_or_404(
            profile_id=profile_id,
            db=db,
        )
    )

    can_rate = can_user_rate_therapist(
        therapist_profile=therapist_profile,
        current_user=user,
        db=db,
    )

    if not can_rate:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Оценить терапевта можно только "
                "после создания переписки с ним"
            ),
        )

    existing_rating = (
        db.query(TherapistRating)
        .filter(
            TherapistRating.user_id == user.id,
            TherapistRating.therapist_profile_id
            == profile_id,
        )
        .first()
    )

    is_new_rating = existing_rating is None

    if existing_rating is None:
        rating = TherapistRating(
            user_id=user.id,
            therapist_profile_id=profile_id,
            rating=rating_data.rating,
        )

        db.add(rating)

    else:
        existing_rating.rating = (
            rating_data.rating
        )

        existing_rating.updated_at = (
            datetime.now(timezone.utc)
        )

    try:
        db.commit()

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Не удалось сохранить оценку. "
                "Попробуйте ещё раз"
            ),
        )

    average_rating, ratings_count = (
        get_rating_summary(
            profile_id=profile_id,
            db=db,
        )
    )

    return {
        "message": (
            "Оценка сохранена"
            if is_new_rating
            else "Оценка обновлена"
        ),
        "therapist_profile_id": profile_id,
        "rating": rating_data.rating,
        "average_rating": average_rating,
        "ratings_count": ratings_count,
        "current_user_rating": (
            rating_data.rating
        ),
        "can_rate": True,
    }


# ============================================================
# GET /therapists/{profile_id}
# ============================================================

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

    average_rating, ratings_count = (
        get_rating_summary(
            profile_id=profile_id,
            db=db,
        )
    )

    current_user_rating = (
        get_current_user_rating(
            profile_id=profile_id,
            current_user=current_user,
            db=db,
        )
    )

    can_rate = can_user_rate_therapist(
        therapist_profile=therapist_profile,
        current_user=current_user,
        db=db,
    )

    return build_public_therapist_response(
        therapist_profile=therapist_profile,
        is_favorite=get_is_favorite(
            profile_id=profile_id,
            current_user=current_user,
            db=db,
        ),
        average_rating=average_rating,
        ratings_count=ratings_count,
        current_user_rating=current_user_rating,
        can_rate=can_rate,
    )
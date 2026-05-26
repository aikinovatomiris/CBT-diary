from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy.orm import Session
from fastapi import Depends

from app.database import get_db
from app.models import TherapistProfile
from app.schemas import PublicTherapistProfileResponse


router = APIRouter(
    prefix="/therapists",
    tags=["Public Therapists"],
)


@router.get(
    "",
    response_model=List[PublicTherapistProfileResponse],
)
def get_approved_therapists(
    city: Optional[str] = Query(default=None),
    specialization: Optional[str] = Query(default=None),
    online_available: Optional[bool] = Query(default=None),
    db: Session = Depends(get_db),
):
    query = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.status == "approved")
    )

    if city:
        query = query.filter(
            TherapistProfile.city.ilike(f"%{city}%")
        )

    if specialization:
        query = query.filter(
            TherapistProfile.specializations.ilike(f"%{specialization}%")
        )

    if online_available is not None:
        query = query.filter(
            TherapistProfile.online_available == online_available
        )

    therapists = (
        query
        .order_by(TherapistProfile.created_at.desc())
        .all()
    )

    return therapists


@router.get(
    "/{profile_id}",
    response_model=PublicTherapistProfileResponse,
)
def get_approved_therapist_by_id(
    profile_id: int,
    db: Session = Depends(get_db),
):
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
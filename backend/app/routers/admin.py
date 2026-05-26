from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.models import CBTSession, DiaryEntry, TherapistProfile, User
from app.schemas import (
    AdminRejectTherapistRequest,
    AdminSummaryResponse,
    AdminTherapistProfileDetail,
    AdminTherapistProfileListItem,
)
from app.security import require_admin


router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
)


def get_therapist_profile_or_404(
    profile_id: int,
    db: Session,
) -> TherapistProfile:
    profile = (
        db.query(TherapistProfile)
        .options(selectinload(TherapistProfile.certificates))
        .filter(TherapistProfile.id == profile_id)
        .first()
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Анкета терапевта не найдена",
        )

    return profile


@router.get(
    "/therapists/pending",
    response_model=List[AdminTherapistProfileListItem],
)
def get_pending_therapists(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    profiles = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.status == "pending")
        .order_by(TherapistProfile.updated_at.desc())
        .all()
    )

    return profiles


@router.get(
    "/therapists/{profile_id}",
    response_model=AdminTherapistProfileDetail,
)
def get_therapist_profile_for_admin(
    profile_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    profile = get_therapist_profile_or_404(
        profile_id=profile_id,
        db=db,
    )

    return profile


@router.patch(
    "/therapists/{profile_id}/approve",
    response_model=AdminTherapistProfileDetail,
)
def approve_therapist_profile(
    profile_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    profile = get_therapist_profile_or_404(
        profile_id=profile_id,
        db=db,
    )

    profile.status = "approved"
    profile.rejection_reason = None

    db.commit()
    db.refresh(profile)

    return profile


@router.patch(
    "/therapists/{profile_id}/reject",
    response_model=AdminTherapistProfileDetail,
)
def reject_therapist_profile(
    profile_id: int,
    reject_data: AdminRejectTherapistRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    profile = get_therapist_profile_or_404(
        profile_id=profile_id,
        db=db,
    )

    profile.status = "rejected"
    profile.rejection_reason = reject_data.reason

    db.commit()
    db.refresh(profile)

    return profile


@router.get(
    "/summary",
    response_model=AdminSummaryResponse,
)
def get_admin_summary(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    total_users = (
        db.query(User)
        .filter(User.role == "user")
        .count()
    )

    total_therapists = (
        db.query(User)
        .filter(User.role == "therapist")
        .count()
    )

    pending_therapists = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.status == "pending")
        .count()
    )

    approved_therapists = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.status == "approved")
        .count()
    )

    rejected_therapists = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.status == "rejected")
        .count()
    )

    total_diary_entries = (
        db.query(DiaryEntry)
        .count()
    )

    total_cbt_sessions = (
        db.query(CBTSession)
        .count()
    )

    return {
        "total_users": total_users,
        "total_therapists": total_therapists,
        "pending_therapists": pending_therapists,
        "approved_therapists": approved_therapists,
        "rejected_therapists": rejected_therapists,
        "total_diary_entries": total_diary_entries,
        "total_cbt_sessions": total_cbt_sessions,
    }
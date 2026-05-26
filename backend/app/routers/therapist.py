import shutil
import uuid
from pathlib import Path
from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import TherapistCertificate, TherapistProfile, User
from app.schemas import (
    TherapistCertificateResponse,
    TherapistProfileResponse,
    TherapistProfileSubmitResponse,
    TherapistProfileUpdate,
)
from app.security import require_therapist


router = APIRouter(
    prefix="/therapist",
    tags=["Therapist"],
)


CERTIFICATES_UPLOAD_DIR = Path("uploads/certificates")
THERAPIST_PHOTOS_UPLOAD_DIR = Path("uploads/therapist_photos")

ALLOWED_CERTIFICATE_EXTENSIONS = {"pdf", "jpg", "jpeg", "png"}
ALLOWED_PHOTO_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}


def get_file_extension(filename: str) -> str:
    return filename.rsplit(".", 1)[-1].lower().strip() if "." in filename else ""


def validate_certificate_file(file: UploadFile):
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен иметь имя",
        )

    extension = get_file_extension(file.filename)

    if extension not in ALLOWED_CERTIFICATE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Можно загружать только файлы pdf, jpg, jpeg или png",
        )


def validate_photo_file(file: UploadFile):
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Файл должен иметь имя",
        )

    extension = get_file_extension(file.filename)

    if extension not in ALLOWED_PHOTO_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Можно загружать только изображения jpg, jpeg, png или webp",
        )


def save_certificate_file(file: UploadFile) -> str:
    validate_certificate_file(file)

    CERTIFICATES_UPLOAD_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    extension = get_file_extension(file.filename)
    unique_filename = f"{uuid.uuid4()}.{extension}"

    file_path = CERTIFICATES_UPLOAD_DIR / unique_filename

    with file_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return str(file_path).replace("\\", "/")


def save_therapist_photo_file(file: UploadFile) -> str:
    validate_photo_file(file)

    THERAPIST_PHOTOS_UPLOAD_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    extension = get_file_extension(file.filename)
    unique_filename = f"{uuid.uuid4()}.{extension}"

    file_path = THERAPIST_PHOTOS_UPLOAD_DIR / unique_filename

    with file_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return str(file_path).replace("\\", "/")


def get_my_therapist_profile_or_404(
    db: Session,
    current_user: User,
) -> TherapistProfile:
    profile = (
        db.query(TherapistProfile)
        .filter(TherapistProfile.user_id == current_user.id)
        .first()
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Анкета терапевта не найдена",
        )

    return profile


@router.get(
    "/profile",
    response_model=TherapistProfileResponse,
)
def get_my_therapist_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    return profile


@router.patch(
    "/profile",
    response_model=TherapistProfileResponse,
)
def update_my_therapist_profile(
    profile_data: TherapistProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    update_data = profile_data.model_dump(
        exclude_unset=True,
    )

    allowed_fields = {
        "full_name",
        "qualification",
        "therapy_approaches",
        "specializations",
        "description",
        "price",
        "contacts",
        "city",
        "online_available",
    }

    for field_name, field_value in update_data.items():
        if field_name in allowed_fields:
            setattr(profile, field_name, field_value)

    if profile.status == "rejected":
        profile.status = "draft"
        profile.rejection_reason = None

    db.commit()
    db.refresh(profile)

    return profile


@router.post(
    "/profile/photo",
    response_model=TherapistProfileResponse,
    status_code=status.HTTP_200_OK,
)
def upload_my_therapist_profile_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    saved_photo_path = save_therapist_photo_file(file)

    profile.photo_path = saved_photo_path

    db.commit()
    db.refresh(profile)

    return profile


@router.post(
    "/profile/certificates",
    response_model=TherapistCertificateResponse,
    status_code=status.HTTP_201_CREATED,
)
def upload_my_therapist_certificate(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    saved_file_path = save_certificate_file(file)

    certificate = TherapistCertificate(
        therapist_profile_id=profile.id,
        file_path=saved_file_path,
        original_filename=file.filename,
    )

    db.add(certificate)
    db.commit()
    db.refresh(certificate)

    return certificate


@router.get(
    "/profile/certificates",
    response_model=List[TherapistCertificateResponse],
)
def get_my_therapist_certificates(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    certificates = (
        db.query(TherapistCertificate)
        .filter(TherapistCertificate.therapist_profile_id == profile.id)
        .order_by(TherapistCertificate.uploaded_at.desc())
        .all()
    )

    return certificates


@router.post(
    "/profile/submit",
    response_model=TherapistProfileSubmitResponse,
)
def submit_my_therapist_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_therapist),
):
    profile = get_my_therapist_profile_or_404(
        db=db,
        current_user=current_user,
    )

    if not profile.full_name or not profile.full_name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для отправки анкеты нужно заполнить ФИО",
        )

    if not profile.qualification or not profile.qualification.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для отправки анкеты нужно заполнить квалификацию",
        )

    certificates_count = (
        db.query(TherapistCertificate)
        .filter(TherapistCertificate.therapist_profile_id == profile.id)
        .count()
    )

    if certificates_count == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для отправки анкеты нужно загрузить хотя бы один сертификат",
        )

    profile.status = "pending"
    profile.rejection_reason = None

    db.commit()
    db.refresh(profile)

    return {
        "message": "Анкета отправлена на модерацию",
        "status": profile.status,
        "therapist_profile_id": profile.id,
    }
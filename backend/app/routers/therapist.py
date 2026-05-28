import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, List

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

EDITABLE_PROFILE_FIELDS = {
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


def validate_contacts_format(contacts: Any):
    """
    contacts хранится в PostgreSQL JSON.
    Чтобы потом на Flutter не получать странные строки,
    разрешаем только JSON-object или null.

    Правильно:
    {
        "telegram": "@therapist",
        "phone": "+77000000000",
        "instagram": "@profile"
    }

    Неправильно:
    "telegram: @therapist, phone: 123"
    """

    if contacts is None:
        return

    if not isinstance(contacts, dict):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="contacts должен быть JSON-объектом, например {'telegram': '@name', 'phone': '+77000000000'}",
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


def validate_profile_ready_for_moderation(
    profile: TherapistProfile,
    db: Session,
):
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


def move_profile_to_pending_after_edit_if_needed(profile: TherapistProfile):
    """
    Правило модерации:

    draft:
    - терапевт просто заполняет и сохраняет анкету;
    - в pending она перейдет через POST /therapist/profile/submit.

    pending:
    - если терапевт редактирует анкету, она остается pending;
    - админ увидит обновленную версию.

    approved:
    - любое редактирование публичных данных снова отправляет анкету на модерацию.

    rejected:
    - если терапевт исправляет анкету после отказа, она снова уходит на модерацию.
    """

    if profile.status in ["approved", "rejected"]:
        profile.status = "pending"
        profile.rejection_reason = None

    elif profile.status == "pending":
        profile.rejection_reason = None


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

    if not update_data:
        return profile

    if "contacts" in update_data:
        validate_contacts_format(update_data["contacts"])

    has_real_changes = False

    for field_name, field_value in update_data.items():
        if field_name not in EDITABLE_PROFILE_FIELDS:
            continue

        old_value = getattr(profile, field_name)

        if old_value != field_value:
            setattr(profile, field_name, field_value)
            has_real_changes = True

    if has_real_changes:
        move_profile_to_pending_after_edit_if_needed(profile)
        profile.updated_at = datetime.utcnow()

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
    profile.updated_at = datetime.utcnow()

    # Фото профиля видно в публичном каталоге,
    # поэтому если анкета уже была approved/rejected,
    # после замены фото она должна снова попасть на модерацию.
    move_profile_to_pending_after_edit_if_needed(profile)

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

    profile.updated_at = datetime.utcnow()

    # Сертификаты видит админ при модерации,
    # поэтому если approved/rejected терапевт добавил новый сертификат,
    # анкета снова должна стать pending.
    move_profile_to_pending_after_edit_if_needed(profile)

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

    if profile.status == "pending":
        return {
            "message": "Анкета уже находится на модерации",
            "status": profile.status,
            "therapist_profile_id": profile.id,
        }

    if profile.status == "approved":
        return {
            "message": "Анкета уже одобрена. Если вы измените данные анкеты, она снова будет отправлена на модерацию.",
            "status": profile.status,
            "therapist_profile_id": profile.id,
        }

    validate_profile_ready_for_moderation(
        profile=profile,
        db=db,
    )

    profile.status = "pending"
    profile.rejection_reason = None
    profile.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(profile)

    return {
        "message": "Анкета отправлена на модерацию",
        "status": profile.status,
        "therapist_profile_id": profile.id,
    }
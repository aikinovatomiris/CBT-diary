from typing import Any, List

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import PlainTextResponse
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import DiaryEntry, User
from app.schemas import (
    DeleteDiaryEntryResponse,
    DiaryEntryResponse,
    DiaryEntryUpdate,
)
from app.security import get_current_user


router = APIRouter(
    prefix="/diary",
    tags=["Diary"],
)


def format_json_field(value: Any) -> str:
    """
    Преобразует JSON-поля DiaryEntry в красивый текст.

    Поддерживает:
    - None
    - пустой dict {}
    - пустой list []
    - {"raw_text": "..."}
    - {"items": [...]}
    - обычный dict
    - обычный list
    - обычную строку
    """

    if value is None:
        return "Не заполнено"

    if value == {} or value == []:
        return "Не заполнено"

    if isinstance(value, dict):
        raw_text = value.get("raw_text")

        if raw_text:
            return str(raw_text)

        items = value.get("items")

        if isinstance(items, list):
            if len(items) == 0:
                return "Не заполнено"

            formatted_items = []

            for item in items:
                if isinstance(item, dict):
                    name = item.get("name") or item.get("title") or item.get("type")
                    description = item.get("description") or item.get("explanation")

                    if name and description:
                        formatted_items.append(f"- {name}: {description}")
                    elif name:
                        formatted_items.append(f"- {name}")
                    elif description:
                        formatted_items.append(f"- {description}")

                elif isinstance(item, str):
                    formatted_items.append(f"- {item}")

            if formatted_items:
                return "\n".join(formatted_items)

            return "Не заполнено"

        formatted_parts = []

        for key, item_value in value.items():
            if item_value is None or item_value == "" or item_value == [] or item_value == {}:
                continue

            formatted_parts.append(f"{key}: {item_value}")

        if formatted_parts:
            return "\n".join(formatted_parts)

        return "Не заполнено"

    if isinstance(value, list):
        if len(value) == 0:
            return "Не заполнено"

        formatted_items = []

        for item in value:
            if isinstance(item, dict):
                name = item.get("name") or item.get("title") or item.get("type")
                description = item.get("description") or item.get("explanation")

                if name and description:
                    formatted_items.append(f"- {name}: {description}")
                elif name:
                    formatted_items.append(f"- {name}")
                elif description:
                    formatted_items.append(f"- {description}")

            elif isinstance(item, str):
                formatted_items.append(f"- {item}")

            else:
                formatted_items.append(f"- {item}")

        if formatted_items:
            return "\n".join(formatted_items)

        return "Не заполнено"

    if isinstance(value, str):
        if value.strip() == "":
            return "Не заполнено"

        return value

    return str(value)


def format_text_field(value: Any) -> str:
    if value is None:
        return "Не заполнено"

    if isinstance(value, str) and value.strip() == "":
        return "Не заполнено"

    return str(value)


def format_date(value: Any) -> str:
    if value is None:
        return "Не заполнено"

    return value.strftime("%d.%m.%Y %H:%M")


def build_diary_export_text(entry: DiaryEntry) -> str:
    return f"""КПТ-запись

Дата:
{format_date(entry.created_at)}

Ситуация:
{format_text_field(entry.situation)}

Автоматическая мысль:
{format_text_field(entry.automatic_thought)}

Эмоции до:
{format_json_field(entry.emotions_before)}

Доказательства за автоматическую мысль:
{format_text_field(entry.evidence_for)}

Доказательства против автоматической мысли:
{format_text_field(entry.evidence_against)}

Рациональная альтернативная мысль:
{format_text_field(entry.alternative_thought)}

Эмоции после:
{format_json_field(entry.emotions_after)}

Когнитивные искажения:
{format_json_field(entry.cognitive_distortions)}

Вывод:
{format_text_field(entry.conclusion)}
"""


def normalize_editable_json_field(value: Any) -> Any:
    """
    Подготавливает значение для сохранения в JSON-колонку PostgreSQL.

    Если frontend отправляет текст из TextField, он сохраняется в формате:

        {"raw_text": "текст пользователя"}

    Такой формат уже поддерживается функцией format_json_field().

    Если frontend отправляет существующий dict или list без изменений,
    структура сохраняется как есть.

    None очищает JSON-поле.
    """

    if value is None:
        return None

    if isinstance(value, str):
        return {
            "raw_text": value,
        }

    return value


def get_user_diary_entry_or_404(
    entry_id: int,
    db: Session,
    current_user: User,
) -> DiaryEntry:
    entry = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.id == entry_id,
            DiaryEntry.user_id == current_user.id,
        )
        .first()
    )

    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Запись дневника не найдена",
        )

    return entry


@router.get(
    "",
    response_model=List[DiaryEntryResponse],
)
def get_my_diary_entries(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entries = (
        db.query(DiaryEntry)
        .filter(DiaryEntry.user_id == current_user.id)
        .order_by(DiaryEntry.created_at.desc())
        .all()
    )

    return entries


@router.get(
    "/{entry_id}/export-text",
    response_class=PlainTextResponse,
)
def export_diary_entry_as_text(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = get_user_diary_entry_or_404(
        entry_id=entry_id,
        db=db,
        current_user=current_user,
    )

    export_text = build_diary_export_text(entry)

    return PlainTextResponse(
        content=export_text,
        media_type="text/plain; charset=utf-8",
    )


@router.get(
    "/{entry_id}",
    response_model=DiaryEntryResponse,
)
def get_diary_entry_by_id(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = get_user_diary_entry_or_404(
        entry_id=entry_id,
        db=db,
        current_user=current_user,
    )

    return entry


@router.patch(
    "/{entry_id}",
    response_model=DiaryEntryResponse,
)
def update_diary_entry(
    entry_id: int,
    update_data: DiaryEntryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Редактирует существующую запись КПТ-дневника.

    Пользователь может изменить только свою запись.

    Поля id, user_id, session_id и created_at изменить нельзя.

    Переданные поля перезаписывают данные в PostgreSQL.
    Поля, которые frontend не передал, остаются без изменений.
    """

    entry = get_user_diary_entry_or_404(
        entry_id=entry_id,
        db=db,
        current_user=current_user,
    )

    fields_to_update = update_data.model_dump(
        exclude_unset=True,
    )

    if "situation" in fields_to_update and fields_to_update["situation"] is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Поле situation не может быть null. Для очистки передайте пустую строку.",
        )

    if (
        "automatic_thought" in fields_to_update
        and fields_to_update["automatic_thought"] is None
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Поле automatic_thought не может быть null. "
                "Для очистки передайте пустую строку."
            ),
        )

    json_fields = {
        "emotions_before",
        "emotions_after",
        "cognitive_distortions",
    }

    for field_name, field_value in fields_to_update.items():
        if field_name in json_fields:
            field_value = normalize_editable_json_field(field_value)

        setattr(
            entry,
            field_name,
            field_value,
        )

    try:
        db.commit()
        db.refresh(entry)

    except SQLAlchemyError:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Не удалось сохранить изменения записи дневника",
        )

    return entry


@router.delete(
    "/{entry_id}",
    response_model=DeleteDiaryEntryResponse,
)
def delete_diary_entry(
    entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = get_user_diary_entry_or_404(
        entry_id=entry_id,
        db=db,
        current_user=current_user,
    )

    deleted_entry_id = entry.id

    db.delete(entry)
    db.commit()

    return {
        "message": "Запись дневника удалена",
        "deleted_entry_id": deleted_entry_id,
    }
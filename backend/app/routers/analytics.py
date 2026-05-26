from collections import Counter
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import CBTMessage, CBTSession, DiaryEntry, User
from app.schemas import (
    AnalyticsDistortionItem,
    AnalyticsDistortionsResponse,
    AnalyticsSummaryResponse,
    AnalyticsTechniqueItem,
    AnalyticsTechniquesResponse,
)
from app.security import get_current_user


router = APIRouter(
    prefix="/analytics",
    tags=["Analytics"],
)


def extract_distortion_names(cognitive_distortions: Any) -> list[str]:
    """
    Достает названия когнитивных искажений из diary_entries.cognitive_distortions.

    Поддерживает варианты:
    - None
    - {}
    - []
    - {"items": []}
    - {"items": ["катастрофизация", "чтение мыслей"]}
    - {"items": [{"name": "катастрофизация"}, {"title": "чтение мыслей"}]}
    """

    if not cognitive_distortions:
        return []

    names = []

    if isinstance(cognitive_distortions, dict):
        items = cognitive_distortions.get("items")

        if not items:
            return []

        if isinstance(items, list):
            for item in items:
                if isinstance(item, str):
                    cleaned_name = item.strip()

                    if cleaned_name:
                        names.append(cleaned_name)

                elif isinstance(item, dict):
                    name = (
                        item.get("name")
                        or item.get("title")
                        or item.get("type")
                    )

                    if name and isinstance(name, str):
                        cleaned_name = name.strip()

                        if cleaned_name:
                            names.append(cleaned_name)

    elif isinstance(cognitive_distortions, list):
        for item in cognitive_distortions:
            if isinstance(item, str):
                cleaned_name = item.strip()

                if cleaned_name:
                    names.append(cleaned_name)

            elif isinstance(item, dict):
                name = (
                    item.get("name")
                    or item.get("title")
                    or item.get("type")
                )

                if name and isinstance(name, str):
                    cleaned_name = name.strip()

                    if cleaned_name:
                        names.append(cleaned_name)

    return names


@router.get(
    "/summary",
    response_model=AnalyticsSummaryResponse,
)
def get_analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    total_sessions = (
        db.query(CBTSession)
        .filter(CBTSession.user_id == current_user.id)
        .count()
    )

    finished_sessions = (
        db.query(CBTSession)
        .filter(
            CBTSession.user_id == current_user.id,
            CBTSession.status == "finished",
        )
        .count()
    )

    total_diary_entries = (
        db.query(DiaryEntry)
        .filter(DiaryEntry.user_id == current_user.id)
        .count()
    )

    latest_entry_date = (
        db.query(func.max(DiaryEntry.created_at))
        .filter(DiaryEntry.user_id == current_user.id)
        .scalar()
    )

    return {
        "total_sessions": total_sessions,
        "finished_sessions": finished_sessions,
        "total_diary_entries": total_diary_entries,
        "latest_entry_date": latest_entry_date,
    }


@router.get(
    "/distortions",
    response_model=AnalyticsDistortionsResponse,
)
def get_distortions_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    diary_entries = (
        db.query(DiaryEntry)
        .filter(DiaryEntry.user_id == current_user.id)
        .all()
    )

    counter = Counter()

    for entry in diary_entries:
        distortion_names = extract_distortion_names(entry.cognitive_distortions)

        for name in distortion_names:
            normalized_name = name.lower()
            counter[normalized_name] += 1

    items = [
        AnalyticsDistortionItem(
            name=name,
            count=count,
        )
        for name, count in counter.most_common()
    ]

    return {
        "items": items
    }


@router.get(
    "/techniques",
    response_model=AnalyticsTechniquesResponse,
)
def get_techniques_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        db.query(CBTMessage.used_technique, func.count(CBTMessage.id))
        .join(CBTSession, CBTMessage.session_id == CBTSession.id)
        .filter(
            CBTSession.user_id == current_user.id,
            CBTMessage.role == "assistant",
            CBTMessage.used_technique.isnot(None),
            CBTMessage.used_technique != "NONE",
        )
        .group_by(CBTMessage.used_technique)
        .order_by(func.count(CBTMessage.id).desc())
        .all()
    )

    items = [
        AnalyticsTechniqueItem(
            technique=technique,
            count=count,
        )
        for technique, count in rows
    ]

    return {
        "items": items
    }
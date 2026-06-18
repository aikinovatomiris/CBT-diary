from collections import Counter, defaultdict
from datetime import datetime, time, timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import (
    CBTMessage,
    CBTSession,
    DiaryEntry,
    User,
)
from app.schemas import (
    AnalyticsDistortionItem,
    AnalyticsDistortionsResponse,
    AnalyticsResilienceResponse,
    AnalyticsSummaryResponse,
    AnalyticsTechniqueItem,
    AnalyticsTechniquesResponse,
    AnalyticsWellbeingDayItem,
    AnalyticsWellbeingWeekResponse,
)
from app.security import get_current_user


router = APIRouter(
    prefix="/analytics",
    tags=["Analytics"],
)


WEEKDAY_LABELS = [
    "Пн",
    "Вт",
    "Ср",
    "Чт",
    "Пт",
    "Сб",
    "Вс",
]


def extract_distortion_names(
    cognitive_distortions: Any,
) -> list[str]:

    if not cognitive_distortions:
        return []

    names: list[str] = []

    if isinstance(
        cognitive_distortions,
        dict,
    ):
        items = cognitive_distortions.get(
            "items"
        )

        if not items:
            return []

        if isinstance(items, list):
            for item in items:
                if isinstance(item, str):
                    cleaned_name = (
                        item.strip()
                    )

                    if cleaned_name:
                        names.append(
                            cleaned_name
                        )

                elif isinstance(item, dict):
                    name = (
                        item.get("name")
                        or item.get("title")
                        or item.get("type")
                    )

                    if (
                        name
                        and isinstance(name, str)
                    ):
                        cleaned_name = (
                            name.strip()
                        )

                        if cleaned_name:
                            names.append(
                                cleaned_name
                            )

    elif isinstance(
        cognitive_distortions,
        list,
    ):
        for item in cognitive_distortions:
            if isinstance(item, str):
                cleaned_name = (
                    item.strip()
                )

                if cleaned_name:
                    names.append(
                        cleaned_name
                    )

            elif isinstance(item, dict):
                name = (
                    item.get("name")
                    or item.get("title")
                    or item.get("type")
                )

                if (
                    name
                    and isinstance(name, str)
                ):
                    cleaned_name = (
                        name.strip()
                    )

                    if cleaned_name:
                        names.append(
                            cleaned_name
                        )

    return names


def normalize_wellbeing_score(
    value: Any,
) -> Optional[float]:
    """
    Безопасно преобразует значение общей оценки
    состояния в число от 0 до 100.

    Значения за пределами диапазона игнорируются.
    """

    if value is None:
        return None

    if isinstance(value, bool):
        return None

    try:
        score = float(value)
    except (TypeError, ValueError):
        return None

    if score < 0 or score > 100:
        return None

    return score


def determine_wellbeing_trend(
    scores: list[float],
) -> str:

    if len(scores) < 2:
        return "insufficient_data"

    difference = scores[-1] - scores[0]

    if difference >= 5:
        return "improving"

    if difference <= -5:
        return "declining"

    return "stable"


def calculate_average(
    values: list[float],
) -> Optional[float]:
    if not values:
        return None

    return round(
        sum(values) / len(values),
        1,
    )


@router.get(
    "/summary",
    response_model=AnalyticsSummaryResponse,
)
def get_analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    total_sessions = (
        db.query(CBTSession)
        .filter(
            CBTSession.user_id
            == current_user.id
        )
        .count()
    )

    finished_sessions = (
        db.query(CBTSession)
        .filter(
            CBTSession.user_id
            == current_user.id,
            CBTSession.status == "finished",
        )
        .count()
    )

    total_diary_entries = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.user_id
            == current_user.id
        )
        .count()
    )

    latest_entry_date = (
        db.query(
            func.max(
                DiaryEntry.created_at
            )
        )
        .filter(
            DiaryEntry.user_id
            == current_user.id
        )
        .scalar()
    )

    return {
        "total_sessions": total_sessions,
        "finished_sessions": (
            finished_sessions
        ),
        "total_diary_entries": (
            total_diary_entries
        ),
        "latest_entry_date": (
            latest_entry_date
        ),
    }


@router.get(
    "/distortions",
    response_model=AnalyticsDistortionsResponse,
)
def get_distortions_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    diary_entries = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.user_id
            == current_user.id
        )
        .all()
    )

    counter = Counter()

    for entry in diary_entries:
        distortion_names = (
            extract_distortion_names(
                entry.cognitive_distortions
            )
        )

        for name in distortion_names:
            normalized_name = name.lower()
            counter[normalized_name] += 1

    items = [
        AnalyticsDistortionItem(
            name=name,
            count=count,
        )
        for name, count
        in counter.most_common()
    ]

    return {
        "items": items,
    }


@router.get(
    "/techniques",
    response_model=AnalyticsTechniquesResponse,
)
def get_techniques_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    rows = (
        db.query(
            CBTMessage.used_technique,
            func.count(CBTMessage.id),
        )
        .join(
            CBTSession,
            CBTMessage.session_id
            == CBTSession.id,
        )
        .filter(
            CBTSession.user_id
            == current_user.id,
            CBTMessage.role == "assistant",
            CBTMessage.used_technique
            .isnot(None),
            CBTMessage.used_technique
            != "NONE",
        )
        .group_by(
            CBTMessage.used_technique
        )
        .order_by(
            func.count(
                CBTMessage.id
            ).desc()
        )
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
        "items": items,
    }


@router.get(
    "/wellbeing-week",
    response_model=AnalyticsWellbeingWeekResponse,
)
def get_weekly_wellbeing_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):


    period_end = datetime.utcnow().date()

    period_start = (
        period_end
        - timedelta(days=6)
    )

    query_start = datetime.combine(
        period_start,
        time.min,
    )

    query_end = datetime.combine(
        period_end + timedelta(days=1),
        time.min,
    )

    diary_entries = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.user_id
            == current_user.id,
            DiaryEntry.created_at
            >= query_start,
            DiaryEntry.created_at
            < query_end,
            DiaryEntry.wellbeing_score_after
            .isnot(None),
        )
        .order_by(
            DiaryEntry.created_at.asc()
        )
        .all()
    )

    scores_by_date: dict[
        Any,
        list[float],
    ] = defaultdict(list)

    for entry in diary_entries:
        score = normalize_wellbeing_score(
            entry.wellbeing_score_after
        )

        if score is None:
            continue

        entry_date = (
            entry.created_at.date()
        )

        scores_by_date[
            entry_date
        ].append(score)

    items = []

    available_daily_scores: list[
        float
    ] = []

    all_week_scores: list[float] = []

    for day_offset in range(7):
        current_date = (
            period_start
            + timedelta(days=day_offset)
        )

        day_scores = scores_by_date.get(
            current_date,
            [],
        )

        day_average = calculate_average(
            day_scores
        )

        if day_average is not None:
            available_daily_scores.append(
                day_average
            )

            all_week_scores.extend(
                day_scores
            )

        items.append(
            AnalyticsWellbeingDayItem(
                date=current_date,
                day_label=(
                    WEEKDAY_LABELS[
                        current_date.weekday()
                    ]
                ),
                score=day_average,
                entries_count=len(
                    day_scores
                ),
            )
        )

    average_score = calculate_average(
        all_week_scores
    )

    trend = determine_wellbeing_trend(
        available_daily_scores
    )

    return {
        "period_start": period_start,
        "period_end": period_end,
        "average_score": average_score,
        "trend": trend,
        "items": items,
    }


@router.get(
    "/resilience",
    response_model=AnalyticsResilienceResponse,
)
def get_resilience_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    """
    Рассчитывает внутренний показатель прогресса
    устойчивости приложения.

    Формула:
        50% — доля завершённых сессий;
        50% — средняя итоговая оценка состояния.

    Это не медицинская и не диагностическая оценка.
    """

    total_sessions = (
        db.query(CBTSession)
        .filter(
            CBTSession.user_id
            == current_user.id
        )
        .count()
    )

    finished_sessions = (
        db.query(CBTSession)
        .filter(
            CBTSession.user_id
            == current_user.id,
            CBTSession.status == "finished",
        )
        .count()
    )

    if total_sessions > 0:
        completion_score = round(
            (
                finished_sessions
                / total_sessions
            )
            * 100,
            1,
        )
    else:
        completion_score = 0.0

    wellbeing_rows = (
        db.query(
            DiaryEntry.wellbeing_score_after
        )
        .filter(
            DiaryEntry.user_id
            == current_user.id,
            DiaryEntry.wellbeing_score_after
            .isnot(None),
        )
        .all()
    )

    wellbeing_scores: list[float] = []

    for row in wellbeing_rows:
        raw_score = row[0]

        score = normalize_wellbeing_score(
            raw_score
        )

        if score is not None:
            wellbeing_scores.append(score)

    sessions_with_wellbeing_data = len(
        wellbeing_scores
    )

    average_wellbeing_score = (
        calculate_average(
            wellbeing_scores
        )
    )

    if sessions_with_wellbeing_data == 0:
        data_status = "no_data"
        resilience_score = None

    else:
        if sessions_with_wellbeing_data < 3:
            data_status = "limited"
        else:
            data_status = "enough"

        resilience_raw = (
            completion_score * 0.5
            + average_wellbeing_score * 0.5
        )

        resilience_score = round(
            max(
                0,
                min(
                    100,
                    resilience_raw,
                ),
            )
        )

    return {
        "score": resilience_score,
        "completion_score": (
            completion_score
        ),
        "average_wellbeing_score": (
            average_wellbeing_score
        ),
        "total_sessions": total_sessions,
        "finished_sessions": (
            finished_sessions
        ),
        "sessions_with_wellbeing_data": (
            sessions_with_wellbeing_data
        ),
        "data_status": data_status,
    }
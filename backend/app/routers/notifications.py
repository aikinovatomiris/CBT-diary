from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AppNotification, User
from app.schemas import (
    AppNotificationReadResponse,
    AppNotificationResponse,
    DeleteAllAppNotificationsResponse,
    DeleteAppNotificationResponse,
)
from app.security import (
    decode_access_token_user_id,
    get_current_user,
)
from app.websocket_manager import (
    notification_connection_manager,
)


router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
)


# ============================================================
# HELPERS
# ============================================================

def ensure_utc_datetime(
    value: datetime | None,
) -> datetime | None:
    if value is None:
        return None

    if value.tzinfo is None:
        return value.replace(
            tzinfo=timezone.utc,
        )

    return value.astimezone(
        timezone.utc,
    )


def datetime_to_epoch_ms(
    value: datetime | None,
) -> int | None:
    utc_value = ensure_utc_datetime(
        value
    )

    if utc_value is None:
        return None

    return int(
        utc_value.timestamp() * 1000
    )


def build_notification_response(
    notification: AppNotification,
) -> Dict[str, Any]:
    created_at = ensure_utc_datetime(
        notification.created_at
    )

    created_at_epoch_ms = (
        datetime_to_epoch_ms(
            notification.created_at
        )
    )

    if created_at is None:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "У уведомления отсутствует дата создания"
            ),
        )

    if created_at_epoch_ms is None:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Не удалось преобразовать дату уведомления"
            ),
        )

    return {
        "id": notification.id,
        "user_id": notification.user_id,
        "conversation_id": (
            notification.conversation_id
        ),
        "sender_id": notification.sender_id,
        "sender_name": notification.sender_name,
        "title": notification.title,
        "is_read": notification.is_read,
        "created_at": created_at,
        "created_at_epoch_ms": (
            created_at_epoch_ms
        ),
    }


def get_user_notification_or_404(
    notification_id: int,
    current_user: User,
    db: Session,
) -> AppNotification:
    notification = (
        db.query(AppNotification)
        .filter(
            AppNotification.id == notification_id,
            AppNotification.user_id
            == current_user.id,
        )
        .first()
    )

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Уведомление не найдено",
        )

    return notification


def ensure_notifications_role(
    current_user: User,
) -> None:
    if current_user.role not in {
        "user",
        "therapist",
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Уведомления доступны только "
                "пользователям и терапевтам"
            ),
        )


# ============================================================
# WEBSOCKET /notifications/ws
# ============================================================

@router.websocket("/ws")
async def notifications_websocket(
    websocket: WebSocket,
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    user_id = decode_access_token_user_id(
        token
    )

    if user_id is None:
        await websocket.close(
            code=1008,
            reason="Недействительный токен",
        )
        return

    current_user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if current_user is None:
        await websocket.close(
            code=1008,
            reason="Пользователь не найден",
        )
        return

    if current_user.role not in {
        "user",
        "therapist",
    }:
        await websocket.close(
            code=1008,
            reason="Нет доступа к уведомлениям",
        )
        return

    await notification_connection_manager.connect(
        user_id=current_user.id,
        websocket=websocket,
    )

    try:
        await websocket.send_json(
            {
                "type": "connected",
                "user_id": current_user.id,
            }
        )

        while True:
            client_data = (
                await websocket.receive_text()
            )

            if client_data.strip().lower() == "ping":
                await websocket.send_json(
                    {
                        "type": "pong",
                        "user_id": current_user.id,
                    }
                )

    except WebSocketDisconnect:
        notification_connection_manager.disconnect(
            user_id=current_user.id,
            websocket=websocket,
        )

    except Exception:
        notification_connection_manager.disconnect(
            user_id=current_user.id,
            websocket=websocket,
        )

        try:
            await websocket.close(
                code=1011,
                reason=(
                    "Ошибка WebSocket-соединения"
                ),
            )
        except Exception:
            pass


# ============================================================
# GET /notifications
# ============================================================

@router.get(
    "",
    response_model=List[
        AppNotificationResponse
    ],
)
def get_my_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    ensure_notifications_role(
        current_user
    )

    notifications = (
        db.query(AppNotification)
        .filter(
            AppNotification.user_id
            == current_user.id,
        )
        .order_by(
            AppNotification.created_at.desc(),
            AppNotification.id.desc(),
        )
        .all()
    )

    return [
        build_notification_response(
            notification
        )
        for notification in notifications
    ]


# ============================================================
# PATCH /notifications/{notification_id}/read
# ============================================================

@router.patch(
    "/{notification_id}/read",
    response_model=AppNotificationReadResponse,
)
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    ensure_notifications_role(
        current_user
    )

    notification = get_user_notification_or_404(
        notification_id=notification_id,
        current_user=current_user,
        db=db,
    )

    notification.is_read = True

    db.commit()
    db.refresh(notification)

    return {
        "notification_id": notification.id,
        "is_read": notification.is_read,
    }


# ============================================================
# DELETE /notifications/{notification_id}
# ============================================================

@router.delete(
    "/{notification_id}",
    response_model=DeleteAppNotificationResponse,
)
def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    ensure_notifications_role(
        current_user
    )

    notification = get_user_notification_or_404(
        notification_id=notification_id,
        current_user=current_user,
        db=db,
    )

    deleted_notification_id = notification.id

    db.delete(notification)
    db.commit()

    return {
        "message": "Уведомление удалено",
        "deleted_notification_id": (
            deleted_notification_id
        ),
    }


# ============================================================
# DELETE /notifications
# ============================================================

@router.delete(
    "",
    response_model=DeleteAllAppNotificationsResponse,
)
def delete_all_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    ensure_notifications_role(
        current_user
    )

    deleted_count = (
        db.query(AppNotification)
        .filter(
            AppNotification.user_id
            == current_user.id,
        )
        .delete(
            synchronize_session=False,
        )
    )

    db.commit()

    return {
        "message": "Все уведомления удалены",
        "deleted_count": deleted_count,
    }
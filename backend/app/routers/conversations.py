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
from sqlalchemy.orm import (
    Session,
    selectinload,
)

from app.database import get_db
from app.models import (
    Conversation,
    ConversationMessage,
    DiaryEntry,
    TherapistProfile,
    User,
)
from app.schemas import (
    ConversationCreate,
    ConversationMessageCreate,
    ConversationMessageResponse,
    ConversationReadResponse,
    ConversationResponse,
    DiaryEntryResponse,
    ShareDiaryEntryRequest,
)
from app.security import (
    decode_access_token_user_id,
    get_current_user,
)
from app.websocket_manager import (
    conversation_connection_manager,
)


router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"],
)


SHARED_DIARY_MESSAGE_CONTENT = (
    "Пользователь поделился КПТ-записью"
)


# ============================================================
# DATETIME HELPERS
# ============================================================

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

def ensure_utc_datetime(
    value: datetime | None,
) -> datetime | None:
    """
    В базе проекта DateTime хранится как naive UTC.

    Перед отправкой клиенту значение явно помечается
    часовым поясом UTC.
    """

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
    """
    Возвращает Unix timestamp в миллисекундах.

    Unix timestamp описывает абсолютный момент времени
    и не зависит от часового пояса клиента или сервера.
    """

    utc_value = ensure_utc_datetime(value)

    if utc_value is None:
        return None

    return int(
        utc_value.timestamp() * 1000
    )


def build_message_response(
    message: ConversationMessage,
) -> Dict[str, Any]:
    created_at = ensure_utc_datetime(
        message.created_at
    )

    created_at_epoch_ms = (
        datetime_to_epoch_ms(
            message.created_at
        )
    )

    if created_at is None:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "У сообщения отсутствует дата создания"
            ),
        )

    if created_at_epoch_ms is None:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Не удалось преобразовать дату сообщения"
            ),
        )

    return {
        "id": message.id,
        "conversation_id": (
            message.conversation_id
        ),
        "sender_id": message.sender_id,
        "content": message.content,
        "shared_diary_entry_id": (
            message.shared_diary_entry_id
        ),
        "created_at": created_at,
        "created_at_epoch_ms": (
            created_at_epoch_ms
        ),
    }


# ============================================================
# CONVERSATION HELPERS
# ============================================================

def get_conversation_or_404(
    conversation_id: int,
    db: Session,
) -> Conversation:
    conversation = (
        db.query(Conversation)
        .options(
            selectinload(Conversation.user),
            selectinload(Conversation.therapist),
        )
        .filter(
            Conversation.id == conversation_id,
        )
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Переписка не найдена",
        )

    return conversation


def get_conversation_with_participants_or_404(
    conversation_id: int,
    db: Session,
) -> Conversation:
    conversation = (
        db.query(Conversation)
        .options(
            selectinload(Conversation.user),
            selectinload(Conversation.therapist),
        )
        .filter(
            Conversation.id == conversation_id,
        )
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Переписка не найдена",
        )

    return conversation


def ensure_conversation_participant(
    conversation: Conversation,
    current_user: User,
) -> None:
    if current_user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin не участвует в переписках",
        )

    is_user_participant = (
        current_user.id == conversation.user_id
    )

    is_therapist_participant = (
        current_user.id
        == conversation.therapist_user_id
    )

    if (
        not is_user_participant
        and not is_therapist_participant
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Нет доступа к этой переписке",
        )


def is_conversation_participant(
    conversation: Conversation,
    user: User,
) -> bool:
    """
    Версия проверки без HTTPException.
    """

    if user.role == "admin":
        return False

    return user.id in {
        conversation.user_id,
        conversation.therapist_user_id,
    }


def get_approved_therapist_profile_or_400(
    therapist_user_id: int,
    db: Session,
) -> TherapistProfile:
    therapist_profile = (
        db.query(TherapistProfile)
        .filter(
            TherapistProfile.user_id
            == therapist_user_id,
            TherapistProfile.status == "approved",
        )
        .first()
    )

    if not therapist_profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Можно писать только "
                "одобренному терапевту"
            ),
        )

    return therapist_profile


def get_user_diary_entry_or_404(
    diary_entry_id: int,
    current_user: User,
    db: Session,
) -> DiaryEntry:
    diary_entry = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.id == diary_entry_id,
            DiaryEntry.user_id == current_user.id,
        )
        .first()
    )

    if not diary_entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Дневниковая запись не найдена",
        )

    return diary_entry


def ensure_diary_entry_was_shared_in_conversation(
    conversation: Conversation,
    diary_entry_id: int,
    db: Session,
) -> None:
    shared_message = (
        db.query(ConversationMessage)
        .filter(
            ConversationMessage.conversation_id
            == conversation.id,
            ConversationMessage.shared_diary_entry_id
            == diary_entry_id,
        )
        .first()
    )

    if not shared_message:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Эта дневниковая запись не была "
                "расшарена в данной переписке"
            ),
        )


def get_last_message(
    conversation_id: int,
    db: Session,
) -> ConversationMessage | None:
    return (
        db.query(ConversationMessage)
        .filter(
            ConversationMessage.conversation_id
            == conversation_id,
        )
        .order_by(
            ConversationMessage.created_at.desc(),
            ConversationMessage.id.desc(),
        )
        .first()
    )


def get_last_read_at(
    conversation: Conversation,
    current_user: User,
) -> datetime | None:
    if current_user.id == conversation.user_id:
        return conversation.user_last_read_at

    if (
        current_user.id
        == conversation.therapist_user_id
    ):
        return conversation.therapist_last_read_at

    return None


def get_unread_count(
    conversation: Conversation,
    current_user: User,
    db: Session,
) -> int:
    last_read_at = get_last_read_at(
        conversation=conversation,
        current_user=current_user,
    )

    query = (
        db.query(ConversationMessage)
        .filter(
            ConversationMessage.conversation_id
            == conversation.id,
            ConversationMessage.sender_id
            != current_user.id,
        )
    )

    if last_read_at is not None:
        query = query.filter(
            ConversationMessage.created_at
            > last_read_at,
        )

    return query.count()


def build_conversation_response(
    conversation: Conversation,
    current_user: User,
    db: Session,
) -> Dict[str, Any]:
    last_message = get_last_message(
        conversation_id=conversation.id,
        db=db,
    )

    unread_count = get_unread_count(
        conversation=conversation,
        current_user=current_user,
        db=db,
    )

    return {
        "id": conversation.id,
        "user_id": conversation.user_id,
        "therapist_user_id": (
            conversation.therapist_user_id
        ),
        "created_at": ensure_utc_datetime(
            conversation.created_at
        ),
        "last_message_at": ensure_utc_datetime(
            conversation.last_message_at
        ),
        "user_last_read_at": ensure_utc_datetime(
            conversation.user_last_read_at
        ),
        "therapist_last_read_at": ensure_utc_datetime(
            conversation.therapist_last_read_at
        ),
        "user_name": conversation.user_name,
        "therapist_name": (
            conversation.therapist_name
        ),
        "last_message_text": (
            last_message.content
            if last_message is not None
            else None
        ),
        "last_message_sender_id": (
            last_message.sender_id
            if last_message is not None
            else None
        ),
        "unread_count": unread_count,
        "has_unread": unread_count > 0,
    }


def mark_conversation_as_read(
    conversation: Conversation,
    current_user: User,
    read_at: datetime,
) -> None:
    if current_user.id == conversation.user_id:
        conversation.user_last_read_at = read_at
        return

    if (
        current_user.id
        == conversation.therapist_user_id
    ):
        conversation.therapist_last_read_at = read_at
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Нет доступа к этой переписке",
    )


def update_conversation_after_new_message(
    conversation: Conversation,
    message: ConversationMessage,
    current_user: User,
) -> None:
    message_created_at = (
        message.created_at
        or utc_now()
    )

    conversation.last_message_at = (
        message_created_at
    )

    mark_conversation_as_read(
        conversation=conversation,
        current_user=current_user,
        read_at=message_created_at,
    )


# ============================================================
# WEBSOCKET HELPERS
# ============================================================

def build_message_websocket_payload(
    message: ConversationMessage,
) -> Dict[str, Any]:
    message_data = build_message_response(
        message
    )

    created_at = message_data.get(
        "created_at"
    )

    if isinstance(created_at, datetime):
        message_data["created_at"] = (
            created_at.isoformat()
        )

    return {
        "type": "new_message",
        "conversation_id": (
            message.conversation_id
        ),
        "message": message_data,
    }


async def broadcast_new_message(
    message: ConversationMessage,
    sender_user_id: int,
) -> None:

    payload = build_message_websocket_payload(
        message
    )

    await (
        conversation_connection_manager
        .broadcast_to_conversation(
            conversation_id=(
                message.conversation_id
            ),
            payload=payload,
            exclude_user_id=sender_user_id,
        )
    )


# ============================================================
# WEBSOCKET
# ============================================================

@router.websocket(
    "/{conversation_id}/ws",
)
async def conversation_websocket(
    websocket: WebSocket,
    conversation_id: int,
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

    conversation = (
        db.query(Conversation)
        .filter(
            Conversation.id == conversation_id,
        )
        .first()
    )

    if conversation is None:
        await websocket.close(
            code=1008,
            reason="Переписка не найдена",
        )
        return

    if not is_conversation_participant(
        conversation=conversation,
        user=current_user,
    ):
        await websocket.close(
            code=1008,
            reason="Нет доступа к переписке",
        )
        return

    await (
        conversation_connection_manager.connect(
            conversation_id=conversation_id,
            user_id=current_user.id,
            websocket=websocket,
        )
    )

    try:
        await websocket.send_json(
            {
                "type": "connected",
                "conversation_id": (
                    conversation_id
                ),
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
                        "conversation_id": (
                            conversation_id
                        ),
                    }
                )

    except WebSocketDisconnect:
        conversation_connection_manager.disconnect(
            conversation_id=conversation_id,
            user_id=current_user.id,
            websocket=websocket,
        )

    except Exception:
        conversation_connection_manager.disconnect(
            conversation_id=conversation_id,
            user_id=current_user.id,
            websocket=websocket,
        )

        try:
            await websocket.close(
                code=1011,
                reason="Ошибка WebSocket-соединения",
            )
        except Exception:
            pass


# ============================================================
# POST /conversations
# ============================================================

@router.post(
    "",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_or_get_conversation(
    conversation_data: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Создавать переписку может "
                "только обычный пользователь"
            ),
        )

    therapist = (
        db.query(User)
        .filter(
            User.id
            == conversation_data.therapist_user_id,
            User.role == "therapist",
        )
        .first()
    )

    if not therapist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Терапевт не найден",
        )

    get_approved_therapist_profile_or_400(
        therapist_user_id=therapist.id,
        db=db,
    )

    existing_conversation = (
        db.query(Conversation)
        .options(
            selectinload(Conversation.user),
            selectinload(Conversation.therapist),
        )
        .filter(
            Conversation.user_id
            == current_user.id,
            Conversation.therapist_user_id
            == therapist.id,
        )
        .first()
    )

    if existing_conversation:
        return build_conversation_response(
            conversation=existing_conversation,
            current_user=current_user,
            db=db,
        )

    now = utc_now()

    conversation = Conversation(
        user_id=current_user.id,
        therapist_user_id=therapist.id,
        created_at=now,
        last_message_at=now,
        user_last_read_at=now,
        therapist_last_read_at=None,
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    conversation = (
        get_conversation_with_participants_or_404(
            conversation_id=conversation.id,
            db=db,
        )
    )

    return build_conversation_response(
        conversation=conversation,
        current_user=current_user,
        db=db,
    )


# ============================================================
# GET /conversations
# ============================================================

@router.get(
    "",
    response_model=List[ConversationResponse],
)
def get_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    base_query = (
        db.query(Conversation)
        .options(
            selectinload(Conversation.user),
            selectinload(Conversation.therapist),
        )
    )

    if current_user.role == "user":
        conversations = (
            base_query
            .filter(
                Conversation.user_id
                == current_user.id,
            )
            .order_by(
                Conversation.last_message_at.desc(),
                Conversation.id.desc(),
            )
            .all()
        )

    elif current_user.role == "therapist":
        conversations = (
            base_query
            .filter(
                Conversation.therapist_user_id
                == current_user.id,
            )
            .order_by(
                Conversation.last_message_at.desc(),
                Conversation.id.desc(),
            )
            .all()
        )

    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Admin не участвует "
                "в переписках"
            ),
        )

    return [
        build_conversation_response(
            conversation=conversation,
            current_user=current_user,
            db=db,
        )
        for conversation in conversations
    ]


# ============================================================
# GET /conversations/{conversation_id}/messages
# ============================================================

@router.get(
    "/{conversation_id}/messages",
    response_model=List[
        ConversationMessageResponse
    ],
)
def get_conversation_messages(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    ensure_conversation_participant(
        conversation=conversation,
        current_user=current_user,
    )

    messages = (
        db.query(ConversationMessage)
        .filter(
            ConversationMessage.conversation_id
            == conversation.id,
        )
        .order_by(
            ConversationMessage.created_at.asc(),
            ConversationMessage.id.asc(),
        )
        .all()
    )

    return [
        build_message_response(message)
        for message in messages
    ]


# ============================================================
# POST /conversations/{conversation_id}/messages
# ============================================================

@router.post(
    "/{conversation_id}/messages",
    response_model=ConversationMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_conversation_message(
    conversation_id: int,
    message_data: ConversationMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    ensure_conversation_participant(
        conversation=conversation,
        current_user=current_user,
    )

    if current_user.role == "user":
        get_approved_therapist_profile_or_400(
            therapist_user_id=(
                conversation.therapist_user_id
            ),
            db=db,
        )

    message = ConversationMessage(
        conversation_id=conversation.id,
        sender_id=current_user.id,
        content=message_data.content,
        shared_diary_entry_id=None,
        created_at=utc_now(),
    )

    db.add(message)
    db.flush()

    update_conversation_after_new_message(
        conversation=conversation,
        message=message,
        current_user=current_user,
    )

    db.commit()
    db.refresh(message)

    await broadcast_new_message(
        message=message,
        sender_user_id=current_user.id,
    )

    return build_message_response(
        message
    )


# ============================================================
# PATCH /conversations/{conversation_id}/read
# ============================================================

@router.patch(
    "/{conversation_id}/read",
    response_model=ConversationReadResponse,
)
def mark_conversation_read(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    ensure_conversation_participant(
        conversation=conversation,
        current_user=current_user,
    )

    read_at = utc_now()
    
    mark_conversation_as_read(
        conversation=conversation,
        current_user=current_user,
        read_at=read_at,
    )

    db.commit()
    db.refresh(conversation)

    return {
        "conversation_id": conversation.id,
        "read_at": ensure_utc_datetime(
            read_at
        ),
        "unread_count": 0,
        "has_unread": False,
    }


# ============================================================
# POST /conversations/{conversation_id}/share-diary-entry
# ============================================================

@router.post(
    "/{conversation_id}/share-diary-entry",
    response_model=ConversationMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def share_diary_entry_in_conversation(
    conversation_id: int,
    share_data: ShareDiaryEntryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Дневниковой записью может "
                "делиться только обычный пользователь"
            ),
        )

    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    if conversation.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Можно делиться дневниковой "
                "записью только в своей переписке"
            ),
        )

    get_approved_therapist_profile_or_400(
        therapist_user_id=(
            conversation.therapist_user_id
        ),
        db=db,
    )

    diary_entry = get_user_diary_entry_or_404(
        diary_entry_id=(
            share_data.diary_entry_id
        ),
        current_user=current_user,
        db=db,
    )

    message = ConversationMessage(
        conversation_id=conversation.id,
        sender_id=current_user.id,
        content=SHARED_DIARY_MESSAGE_CONTENT,
        shared_diary_entry_id=diary_entry.id,
        created_at=utc_now(),
    )

    db.add(message)
    db.flush()

    update_conversation_after_new_message(
        conversation=conversation,
        message=message,
        current_user=current_user,
    )

    db.commit()
    db.refresh(message)

    await broadcast_new_message(
        message=message,
        sender_user_id=current_user.id,
    )

    return build_message_response(
        message
    )


# ============================================================
# GET SHARED DIARY ENTRY
# ============================================================

@router.get(
    (
        "/{conversation_id}/shared-diary/"
        "{diary_entry_id}"
    ),
    response_model=DiaryEntryResponse,
)
def get_shared_diary_entry_in_conversation(
    conversation_id: int,
    diary_entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    ensure_conversation_participant(
        conversation=conversation,
        current_user=current_user,
    )

    ensure_diary_entry_was_shared_in_conversation(
        conversation=conversation,
        diary_entry_id=diary_entry_id,
        db=db,
    )

    diary_entry = (
        db.query(DiaryEntry)
        .filter(
            DiaryEntry.id == diary_entry_id,
            DiaryEntry.user_id
            == conversation.user_id,
        )
        .first()
    )

    if not diary_entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Дневниковая запись не найдена",
        )

    return diary_entry
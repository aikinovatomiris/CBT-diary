from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, selectinload

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
    ConversationResponse,
    DiaryEntryResponse,
    ShareDiaryEntryRequest,
)
from app.security import get_current_user


router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"],
)


SHARED_DIARY_MESSAGE_CONTENT = "Пользователь поделился КПТ-записью"


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
        .filter(Conversation.id == conversation_id)
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
        .filter(Conversation.id == conversation_id)
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
):
    if current_user.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin не участвует в переписках",
        )

    is_user_participant = current_user.id == conversation.user_id
    is_therapist_participant = current_user.id == conversation.therapist_user_id

    if not is_user_participant and not is_therapist_participant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Нет доступа к этой переписке",
        )


def get_approved_therapist_profile_or_400(
    therapist_user_id: int,
    db: Session,
) -> TherapistProfile:
    therapist_profile = (
        db.query(TherapistProfile)
        .filter(
            TherapistProfile.user_id == therapist_user_id,
            TherapistProfile.status == "approved",
        )
        .first()
    )

    if not therapist_profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Можно писать только одобренному терапевту",
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
):
    shared_message = (
        db.query(ConversationMessage)
        .filter(
            ConversationMessage.conversation_id == conversation.id,
            ConversationMessage.shared_diary_entry_id == diary_entry_id,
        )
        .first()
    )

    if not shared_message:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Эта дневниковая запись не была расшарена в данной переписке",
        )


@router.post(
    "",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_or_get_conversation(
    conversation_data: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Создавать переписку может только обычный пользователь",
        )

    therapist = (
        db.query(User)
        .filter(
            User.id == conversation_data.therapist_user_id,
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
            Conversation.user_id == current_user.id,
            Conversation.therapist_user_id == therapist.id,
        )
        .first()
    )

    if existing_conversation:
        return existing_conversation

    conversation = Conversation(
        user_id=current_user.id,
        therapist_user_id=therapist.id,
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return get_conversation_with_participants_or_404(
        conversation_id=conversation.id,
        db=db,
    )


@router.get(
    "",
    response_model=List[ConversationResponse],
)
def get_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
            .filter(Conversation.user_id == current_user.id)
            .order_by(Conversation.created_at.desc())
            .all()
        )

        return conversations

    if current_user.role == "therapist":
        conversations = (
            base_query
            .filter(Conversation.therapist_user_id == current_user.id)
            .order_by(Conversation.created_at.desc())
            .all()
        )

        return conversations

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Admin не участвует в переписках",
    )


@router.get(
    "/{conversation_id}/messages",
    response_model=List[ConversationMessageResponse],
)
def get_conversation_messages(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
        .filter(ConversationMessage.conversation_id == conversation.id)
        .order_by(ConversationMessage.created_at.asc())
        .all()
    )

    return messages


@router.post(
    "/{conversation_id}/messages",
    response_model=ConversationMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def send_conversation_message(
    conversation_id: int,
    message_data: ConversationMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
            therapist_user_id=conversation.therapist_user_id,
            db=db,
        )

    message = ConversationMessage(
        conversation_id=conversation.id,
        sender_id=current_user.id,
        content=message_data.content,
        shared_diary_entry_id=None,
    )

    db.add(message)
    db.commit()
    db.refresh(message)

    return message


@router.post(
    "/{conversation_id}/share-diary-entry",
    response_model=ConversationMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def share_diary_entry_in_conversation(
    conversation_id: int,
    share_data: ShareDiaryEntryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Дневниковой записью может делиться только обычный пользователь",
        )

    conversation = get_conversation_or_404(
        conversation_id=conversation_id,
        db=db,
    )

    if conversation.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Можно делиться дневниковой записью только в своей переписке",
        )

    get_approved_therapist_profile_or_400(
        therapist_user_id=conversation.therapist_user_id,
        db=db,
    )

    diary_entry = get_user_diary_entry_or_404(
        diary_entry_id=share_data.diary_entry_id,
        current_user=current_user,
        db=db,
    )

    message = ConversationMessage(
        conversation_id=conversation.id,
        sender_id=current_user.id,
        content=SHARED_DIARY_MESSAGE_CONTENT,
        shared_diary_entry_id=diary_entry.id,
    )

    db.add(message)
    db.commit()
    db.refresh(message)

    return message


@router.get(
    "/{conversation_id}/shared-diary/{diary_entry_id}",
    response_model=DiaryEntryResponse,
)
def get_shared_diary_entry_in_conversation(
    conversation_id: int,
    diary_entry_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
            DiaryEntry.user_id == conversation.user_id,
        )
        .first()
    )

    if not diary_entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Дневниковая запись не найдена",
        )

    return diary_entry
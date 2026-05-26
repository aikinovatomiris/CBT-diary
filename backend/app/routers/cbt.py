from datetime import datetime
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.ai.cbt_assistant import (
    detect_cognitive_distortions,
    generate_cbt_reply,
    generate_diary_conclusion,
)
from app.ai.guardrails import is_crisis_message, is_off_topic
from app.database import get_db
from app.models import CBTMessage, CBTSession, DiaryEntry, User
from app.schemas import (
    CBTMessageCreate,
    CBTMessageResponse,
    CBTMessageSendResponse,
    CBTSessionResponse,
    DiaryEntryResponse,
)
from app.security import get_current_user


router = APIRouter(
    prefix="/cbt",
    tags=["CBT Sessions"],
)


CBT_STEPS = [
    "SITUATION",
    "AUTOMATIC_THOUGHT",
    "EMOTIONS",
    "EVIDENCE_FOR",
    "EVIDENCE_AGAINST",
    "ALTERNATIVE_THOUGHT",
    "RESULT",
    "FINISHED",
]


STEP_TO_PHASE = {
    "SITUATION": "SITUATION_ANALYSIS",
    "AUTOMATIC_THOUGHT": "THOUGHT_IDENTIFICATION",
    "EMOTIONS": "EMOTION_ASSESSMENT",
    "EVIDENCE_FOR": "COGNITIVE_RESTRUCTURING",
    "EVIDENCE_AGAINST": "COGNITIVE_RESTRUCTURING",
    "ALTERNATIVE_THOUGHT": "ALTERNATIVE_FORMULATION",
    "RESULT": "SUMMARY",
    "FINISHED": "FINISHED",
}


VALID_PHASES = {
    "OPENING",
    "SITUATION_ANALYSIS",
    "THOUGHT_IDENTIFICATION",
    "EMOTION_ASSESSMENT",
    "COGNITIVE_RESTRUCTURING",
    "ALTERNATIVE_FORMULATION",
    "SUMMARY",
    "FINISHED",
    "STABILIZATION",
}


FULL_SESSION_CONCLUSION = "Запись создана автоматически после КПТ-сессии"
PARTIAL_SESSION_CONCLUSION = "Запись создана на основе частично завершенной КПТ-сессии"

OFF_TOPIC_REPLY = (
    "Я могу помогать только в рамках КПТ-дневника: с ситуациями, мыслями, "
    "эмоциями и их анализом. Давай вернемся к текущей ситуации."
)

CRISIS_REPLY = (
    "Мне очень жаль, что тебе сейчас так тяжело. Я не могу заменить экстренную помощь. "
    "Пожалуйста, обратись к человеку рядом, которому доверяешь, или в экстренные службы. "
    "Телефоны доверия Казахстана - 111 и 150. Помни, что ты не один."
)

STABILIZATION_REPLY = (
    "Сейчас важнее не продолжать разбор, а немного стабилизироваться. "
    "Попробуй опереться стопами в пол или почувствовать поверхность под собой. "
    "Назови один предмет рядом, который ты видишь прямо сейчас."
)


def ensure_cbt_available_for_user(current_user: User):
    """
    КПТ-дневник и ИИ-ассистент доступны только обычным пользователям.

    therapist/admin не должны пользоваться CBT-сессиями:
    - therapist имеет отдельный рабочий кабинет;
    - admin занимается модерацией и управлением.
    """

    if current_user.role != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="КПТ-сессии доступны только обычным пользователям",
        )


def get_next_step(current_step: str) -> str:
    if current_step not in CBT_STEPS:
        return "SITUATION"

    current_index = CBT_STEPS.index(current_step)

    if current_index >= len(CBT_STEPS) - 1:
        return "FINISHED"

    return CBT_STEPS[current_index + 1]


def get_phase_for_step(step: str) -> str:
    return STEP_TO_PHASE.get(step, "SITUATION_ANALYSIS")


def needs_stabilization(message: str) -> bool:
    """
    Проверяет, нужно ли временно остановить КПТ-разбор
    и перейти в стабилизацию.

    Важно:
    Не каждое упоминание тревоги, страха или паники должно останавливать сессию.
    Для КПТ-дневника пользователь может описывать сильные эмоции — это нормально.

    Стабилизацию включаем только если пользователь явно сообщает,
    что сейчас не может продолжать, думать, дышать или удерживаться в диалоге.
    """

    normalized = message.lower().strip()

    strong_stabilization_markers = [
        "меня трясет",
        "меня всю трясет",
        "меня сильно трясет",
        "трясет",
        "трясло",
        "дрожу",
        "дрожь",
        "не могу продолжать",
        "не могу дальше",
        "не могу думать",
        "не могу мыслить",
        "не могу сосредоточиться",
        "не могу сконцентрироваться",
        "не могу успокоиться",
        "не могу дышать",
        "тяжело дышать",
        "задыхаюсь",
        "меня накрывает",
        "накрывает так, что не могу",
        "я не могу ответить",
        "не могу ответить",
        "не могу сейчас отвечать",
    ]

    return any(marker in normalized for marker in strong_stabilization_markers)


def is_session_in_stabilization(session: CBTSession) -> bool:
    return session.current_phase == "STABILIZATION"


def get_return_from_stabilization_reply(session: CBTSession) -> tuple[str, str, str]:
    """
    Возвращает пользователя из временной стабилизации обратно к КПТ-шагу.

    Важно:
    Ответ на grounding-вопрос, например "Кровать", НЕ сохраняется
    как situation / emotions / evidence / alternative_thought.
    """

    if session.current_step == "SITUATION":
        if session.situation:
            return (
                "Хорошо. Ситуацию мы уже зафиксировали. Какая мысль появилась у тебя в тот момент?",
                "AUTOMATIC_THOUGHT",
                "THOUGHT_IDENTIFICATION",
            )

        return (
            "Хорошо. Давай очень мягко вернемся к ситуации. Что именно сейчас произошло?",
            "SITUATION",
            "SITUATION_ANALYSIS",
        )

    if session.current_step == "AUTOMATIC_THOUGHT":
        return (
            "Хорошо. Теперь попробуем очень коротко: какая мысль появилась в этот момент?",
            "AUTOMATIC_THOUGHT",
            "THOUGHT_IDENTIFICATION",
        )

    if session.current_step == "EMOTIONS":
        if session.emotions_before:
            return (
                "Хорошо. Эмоции мы уже зафиксировали. Теперь мягко перейдем к следующему шагу: какие факты подтверждают эту мысль?",
                "EVIDENCE_FOR",
                "COGNITIVE_RESTRUCTURING",
            )

        return (
            "Хорошо. Теперь попробуй назвать эмоции и оценить их интенсивность от 0 до 100.",
            "EMOTIONS",
            "EMOTION_ASSESSMENT",
        )

    if session.current_step == "EVIDENCE_FOR":
        return (
            "Хорошо. Давай не торопиться. Какие факты подтверждают эту автоматическую мысль?",
            "EVIDENCE_FOR",
            "COGNITIVE_RESTRUCTURING",
        )

    if session.current_step == "EVIDENCE_AGAINST":
        return (
            "Хорошо. Вернемся очень мягко: есть ли хотя бы один факт, который говорит против этой мысли или делает ситуацию не такой однозначной?",
            "EVIDENCE_AGAINST",
            "COGNITIVE_RESTRUCTURING",
        )

    if session.current_step == "ALTERNATIVE_THOUGHT":
        return (
            "Хорошо. Попробуем очень бережно: какая более сбалансированная мысль могла бы звучать сейчас?",
            "ALTERNATIVE_THOUGHT",
            "ALTERNATIVE_FORMULATION",
        )

    if session.current_step == "RESULT":
        return (
            "Хорошо. Теперь можно коротко оценить состояние: как изменилась интенсивность эмоций от 0 до 100?",
            "RESULT",
            "SUMMARY",
        )

    return (
        "Хорошо. Давай продолжим спокойно и по шагам.",
        session.current_step,
        get_phase_for_step(session.current_step),
    )


def build_session_data(
    session: CBTSession,
    current_user: Optional[User] = None,
) -> dict:
    assistant_style = "supportive"

    if current_user and current_user.assistant_style:
        assistant_style = current_user.assistant_style

    return {
        "id": session.id,
        "user_id": session.user_id,
        "status": session.status,
        "current_step": session.current_step,
        "current_phase": session.current_phase,
        "assistant_style": assistant_style,
        "situation": session.situation,
        "automatic_thought": session.automatic_thought,
        "emotions_before": session.emotions_before,
        "evidence_for": session.evidence_for,
        "evidence_against": session.evidence_against,
        "user_alternative_thought": session.user_alternative_thought,
        "assistant_alternative_thought": session.assistant_alternative_thought,
        "final_alternative_thought": session.final_alternative_thought,
        "emotions_after": session.emotions_after,
    }


def save_user_answer_to_session(
    session: CBTSession,
    step: str,
    user_answer: str,
):
    if step == "SITUATION":
        session.situation = user_answer

    elif step == "AUTOMATIC_THOUGHT":
        session.automatic_thought = user_answer

    elif step == "EMOTIONS":
        session.emotions_before = {
            "raw_text": user_answer
        }

    elif step == "EVIDENCE_FOR":
        session.evidence_for = user_answer

    elif step == "EVIDENCE_AGAINST":
        session.evidence_against = user_answer

    elif step == "ALTERNATIVE_THOUGHT":
        session.user_alternative_thought = user_answer

    elif step == "RESULT":
        session.emotions_after = {
            "raw_text": user_answer
        }


def save_session_update_to_session(
    session: CBTSession,
    session_update: dict[str, Any],
):
    if not session_update:
        return

    if session_update.get("situation"):
        session.situation = session_update["situation"]

    if session_update.get("automatic_thought"):
        session.automatic_thought = session_update["automatic_thought"]

    if session_update.get("emotions_before"):
        session.emotions_before = session_update["emotions_before"]

    if session_update.get("evidence_for"):
        session.evidence_for = session_update["evidence_for"]

    if session_update.get("evidence_against"):
        session.evidence_against = session_update["evidence_against"]

    if session_update.get("user_alternative_thought"):
        session.user_alternative_thought = session_update["user_alternative_thought"]

    if session_update.get("assistant_alternative_thought"):
        session.assistant_alternative_thought = session_update["assistant_alternative_thought"]

    if session_update.get("final_alternative_thought"):
        session.final_alternative_thought = session_update["final_alternative_thought"]

    if session_update.get("emotions_after"):
        session.emotions_after = session_update["emotions_after"]


def save_ai_extracted_data_to_session(
    session: CBTSession,
    assistant_result: dict,
):
    session_update = assistant_result.get("extracted_data", {})

    save_session_update_to_session(
        session=session,
        session_update=session_update,
    )

    assistant_alternative_thought = assistant_result.get(
        "assistant_alternative_thought"
    )
    final_alternative_thought = assistant_result.get(
        "final_alternative_thought"
    )

    if assistant_alternative_thought:
        session.assistant_alternative_thought = assistant_alternative_thought

    if final_alternative_thought:
        session.final_alternative_thought = final_alternative_thought

    llm_phase = assistant_result.get("current_phase")

    if llm_phase in VALID_PHASES:
        session.current_phase = llm_phase


def choose_alternative_thought(session: CBTSession) -> Optional[str]:
    if session.final_alternative_thought:
        return session.final_alternative_thought

    if session.assistant_alternative_thought:
        return session.assistant_alternative_thought

    return session.user_alternative_thought


def create_diary_entry_if_not_exists(
    db: Session,
    session: CBTSession,
    conclusion: str,
) -> DiaryEntry:
    existing_entry = (
        db.query(DiaryEntry)
        .filter(DiaryEntry.session_id == session.id)
        .first()
    )

    if existing_entry:
        return existing_entry

    session_data = build_session_data(session)

    cognitive_distortions = detect_cognitive_distortions(
        session_data=session_data,
    )

    generated_conclusion = generate_diary_conclusion(
        session_data=session_data,
    )

    diary_entry = DiaryEntry(
        user_id=session.user_id,
        session_id=session.id,
        situation=session.situation or "",
        automatic_thought=session.automatic_thought or "",
        emotions_before=session.emotions_before,
        emotions_after=session.emotions_after,
        cognitive_distortions=cognitive_distortions,
        evidence_for=session.evidence_for,
        evidence_against=session.evidence_against,
        alternative_thought=choose_alternative_thought(session),
        conclusion=generated_conclusion or conclusion,
    )

    db.add(diary_entry)

    return diary_entry


def finish_session(
    session: CBTSession,
):
    session.status = "finished"
    session.current_step = "FINISHED"
    session.current_phase = "FINISHED"
    session.finished_at = datetime.utcnow()


def has_minimum_diary_data(session: CBTSession) -> bool:
    alternative_thought = (
        session.final_alternative_thought
        or session.assistant_alternative_thought
        or session.user_alternative_thought
    )

    return all(
        [
            session.situation,
            session.automatic_thought,
            session.emotions_before,
            alternative_thought,
            session.emotions_after,
        ]
    )


def assistant_reply_asks_question(assistant_reply: str) -> bool:
    if not assistant_reply:
        return False

    normalized_reply = assistant_reply.lower()

    question_markers = [
        "?",
        "хочешь",
        "хочется ли",
        "готова ли",
        "готов ли",
        "можем завершить",
        "завершить работу",
        "подвести итог",
        "что думаешь",
        "как тебе",
        "хотела бы",
        "хотел бы",
    ]

    return any(marker in normalized_reply for marker in question_markers)


def should_finish_session_from_ai(
    session: CBTSession,
    assistant_result: dict,
) -> bool:
    should_finish = assistant_result.get("should_finish", False)
    diary_readiness_score = assistant_result.get("diary_readiness_score", 0)
    assistant_reply = assistant_result.get("assistant_reply", "")

    if session.current_step not in ["RESULT", "FINISHED"]:
        return False

    if not has_minimum_diary_data(session):
        return False

    # Если ассистент задал вопрос, сессию нельзя закрывать.
    # Пользователь должен иметь возможность ответить.
    if assistant_reply_asks_question(assistant_reply):
        return False

    if should_finish:
        return True

    if diary_readiness_score >= 90 and session.current_phase == "SUMMARY":
        return True

    return False


def get_user_session_or_404(
    session_id: int,
    db: Session,
    current_user: User,
) -> CBTSession:
    session = (
        db.query(CBTSession)
        .filter(
            CBTSession.id == session_id,
            CBTSession.user_id == current_user.id,
        )
        .first()
    )

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="КПТ-сессия не найдена",
        )

    return session


@router.post(
    "/sessions",
    response_model=CBTSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_cbt_session(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    new_session = CBTSession(
        user_id=current_user.id,
        status="active",
        current_step="SITUATION",
        current_phase="SITUATION_ANALYSIS",
    )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    return new_session


@router.get(
    "/sessions",
    response_model=List[CBTSessionResponse],
)
def get_my_cbt_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    sessions = (
        db.query(CBTSession)
        .filter(CBTSession.user_id == current_user.id)
        .order_by(CBTSession.created_at.desc())
        .all()
    )

    return sessions


@router.get(
    "/sessions/{session_id}",
    response_model=CBTSessionResponse,
)
def get_cbt_session_by_id(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    session = get_user_session_or_404(
        session_id=session_id,
        db=db,
        current_user=current_user,
    )

    return session


@router.get(
    "/sessions/{session_id}/messages",
    response_model=List[CBTMessageResponse],
)
def get_cbt_session_messages(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    get_user_session_or_404(
        session_id=session_id,
        db=db,
        current_user=current_user,
    )

    messages = (
        db.query(CBTMessage)
        .filter(CBTMessage.session_id == session_id)
        .order_by(CBTMessage.created_at.asc())
        .all()
    )

    return messages


@router.post(
    "/sessions/{session_id}/message",
    response_model=CBTMessageSendResponse,
    status_code=status.HTTP_201_CREATED,
)
def send_message_to_cbt_session(
    session_id: int,
    message_data: CBTMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    session = get_user_session_or_404(
        session_id=session_id,
        db=db,
        current_user=current_user,
    )

    if session.status == "finished" or session.current_step == "FINISHED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Эта КПТ-сессия уже завершена",
        )

    # 1. Crisis check — самый первый.
    # Нельзя вызывать LLM и нельзя продолжать обычную КПТ-логику.
    if is_crisis_message(message_data.content):
        session.current_phase = "STABILIZATION"

        user_message = CBTMessage(
            session_id=session.id,
            role="user",
            content=message_data.content,
            used_technique=None,
        )

        assistant_message = CBTMessage(
            session_id=session.id,
            role="assistant",
            content=CRISIS_REPLY,
            used_technique="GROUNDING",
        )

        db.add(user_message)
        db.add(assistant_message)
        db.commit()

        db.refresh(user_message)
        db.refresh(assistant_message)
        db.refresh(session)

        return {
            "user_message": user_message,
            "assistant_message": assistant_message,
            "current_step": session.current_step,
            "current_phase": session.current_phase,
            "session_status": session.status,
        }

    # 2. Off-topic check — до LLM.
    if is_off_topic(message_data.content):
        user_message = CBTMessage(
            session_id=session.id,
            role="user",
            content=message_data.content,
            used_technique=None,
        )

        assistant_message = CBTMessage(
            session_id=session.id,
            role="assistant",
            content=OFF_TOPIC_REPLY,
            used_technique="NONE",
        )

        db.add(user_message)
        db.add(assistant_message)
        db.commit()

        db.refresh(user_message)
        db.refresh(assistant_message)
        db.refresh(session)

        return {
            "user_message": user_message,
            "assistant_message": assistant_message,
            "current_step": session.current_step,
            "current_phase": session.current_phase,
            "session_status": session.status,
        }

    # 3. Если сессия уже в STABILIZATION,
    # ответ пользователя считается ответом на grounding-вопрос.
    # Его нельзя сохранять как emotions/evidence/alternative_thought.
    if is_session_in_stabilization(session):
        assistant_reply, next_step, next_phase = get_return_from_stabilization_reply(
            session=session,
        )

        user_message = CBTMessage(
            session_id=session.id,
            role="user",
            content=message_data.content,
            used_technique=None,
        )

        assistant_message = CBTMessage(
            session_id=session.id,
            role="assistant",
            content=assistant_reply,
            used_technique="GROUNDING",
        )

        session.current_step = next_step
        session.current_phase = next_phase

        db.add(user_message)
        db.add(assistant_message)
        db.commit()

        db.refresh(user_message)
        db.refresh(assistant_message)
        db.refresh(session)

        return {
            "user_message": user_message,
            "assistant_message": assistant_message,
            "current_step": session.current_step,
            "current_phase": session.current_phase,
            "session_status": session.status,
        }

    # 4. Если пользователь явно перегружен,
    # не сохраняем его сообщение в поля КПТ и не вызываем LLM.
    # Исключение: если это шаг EMOTIONS, и сообщение содержит эмоции,
    # мы можем сохранить его как emotions_before и затем стабилизировать.
    if needs_stabilization(message_data.content):
        if session.current_step == "EMOTIONS":
            session.emotions_before = {
                "raw_text": message_data.content
            }

        user_message = CBTMessage(
            session_id=session.id,
            role="user",
            content=message_data.content,
            used_technique=None,
        )

        assistant_message = CBTMessage(
            session_id=session.id,
            role="assistant",
            content=STABILIZATION_REPLY,
            used_technique="GROUNDING",
        )

        session.current_phase = "STABILIZATION"

        db.add(user_message)
        db.add(assistant_message)
        db.commit()

        db.refresh(user_message)
        db.refresh(assistant_message)
        db.refresh(session)

        return {
            "user_message": user_message,
            "assistant_message": assistant_message,
            "current_step": session.current_step,
            "current_phase": session.current_phase,
            "session_status": session.status,
        }

    current_step = session.current_step

    save_user_answer_to_session(
        session=session,
        step=current_step,
        user_answer=message_data.content,
    )

    session_data = build_session_data(
        session=session,
        current_user=current_user,
    )

    assistant_result = generate_cbt_reply(
        current_step=current_step,
        user_message=message_data.content,
        session_data=session_data,
    )

    save_ai_extracted_data_to_session(
        session=session,
        assistant_result=assistant_result,
    )

    user_message = CBTMessage(
        session_id=session.id,
        role="user",
        content=message_data.content,
        used_technique=None,
    )

    assistant_message = CBTMessage(
        session_id=session.id,
        role="assistant",
        content=assistant_result["assistant_reply"],
        used_technique=assistant_result["used_technique"],
    )

    db.add(user_message)
    db.add(assistant_message)

    if should_finish_session_from_ai(
        session=session,
        assistant_result=assistant_result,
    ):
        finish_session(session)

        create_diary_entry_if_not_exists(
            db=db,
            session=session,
            conclusion=FULL_SESSION_CONCLUSION,
        )

    elif assistant_result["should_advance"]:
        # RESULT — особый шаг.
        # На этом этапе LLM может задавать уточняющий вопрос:
        # "Хочешь ли завершить запись?"
        # В таком случае нельзя автоматически закрывать сессию.
        if current_step == "RESULT":
            session.current_step = "RESULT"
            session.current_phase = "SUMMARY"

        else:
            next_step = get_next_step(current_step)

            session.current_step = next_step
            session.current_phase = get_phase_for_step(next_step)

            if next_step == "FINISHED":
                finish_session(session)

                create_diary_entry_if_not_exists(
                    db=db,
                    session=session,
                    conclusion=FULL_SESSION_CONCLUSION,
                )

    db.commit()

    db.refresh(user_message)
    db.refresh(assistant_message)
    db.refresh(session)

    return {
        "user_message": user_message,
        "assistant_message": assistant_message,
        "current_step": session.current_step,
        "current_phase": session.current_phase,
        "session_status": session.status,
    }


@router.post(
    "/sessions/{session_id}/finish",
    response_model=DiaryEntryResponse,
)
def finish_cbt_session_manually(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ensure_cbt_available_for_user(current_user)

    session = get_user_session_or_404(
        session_id=session_id,
        db=db,
        current_user=current_user,
    )

    existing_entry = (
        db.query(DiaryEntry)
        .filter(DiaryEntry.session_id == session.id)
        .first()
    )

    if session.status == "finished" or session.current_step == "FINISHED":
        if existing_entry:
            return existing_entry

        finish_session(session)

        diary_entry = create_diary_entry_if_not_exists(
            db=db,
            session=session,
            conclusion=FULL_SESSION_CONCLUSION,
        )

        db.commit()
        db.refresh(diary_entry)

        return diary_entry

    finish_session(session)

    diary_entry = create_diary_entry_if_not_exists(
        db=db,
        session=session,
        conclusion=PARTIAL_SESSION_CONCLUSION,
    )

    db.commit()

    db.refresh(session)
    db.refresh(diary_entry)

    return diary_entry
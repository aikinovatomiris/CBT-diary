import re
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

WELLBEING_SCORE_QUESTION = (
    "Теперь оцени своё общее состояние от 0 до 100, "
    "где 0 — сейчас очень тяжело, а 100 — спокойно и хорошо."
)


WELLBEING_SCORE_INVALID_REPLY = (
    "Нужна одна общая оценка от 0 до 100. "
    "Какое число лучше всего описывает твоё состояние сейчас?"
)


WELLBEING_SCORE_FINISH_REPLY = (
    "Сессия завершена. Я сохраню запись в дневник, "
    "чтобы ты могла вернуться к ней позже."
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

def has_emotion_intensity(message: str) -> bool:

    if not message:
        return False

    numbers = re.findall(r"\b\d{1,3}\b", message)

    for number in numbers:
        try:
            value = int(number)
        except ValueError:
            continue

        if 0 <= value <= 100:
            return True

    return False

def extract_wellbeing_score(message: str) -> Optional[int]:

    if not message:
        return None

    numbers = re.findall(
        r"(?<!\d)(100|\d{1,2})(?!\d)",
        message,
    )

    valid_values = []

    for raw_value in numbers:
        try:
            value = int(raw_value)
        except ValueError:
            continue

        if 0 <= value <= 100:
            valid_values.append(value)

    if not valid_values:
        return None

    normalized = message.lower().replace("ё", "е")

    # Формат: "70 из 100"
    if (
        len(valid_values) >= 2
        and valid_values[-1] == 100
        and "из 100" in normalized
    ):
        return valid_values[0]

    unique_values = list(dict.fromkeys(valid_values))

    if len(unique_values) == 1:
        return unique_values[0]

    return None


def is_wellbeing_uncertainty_message(message: str) -> bool:

    if not message:
        return False

    normalized = (
        message.lower()
        .strip()
        .replace("ё", "е")
    )

    uncertainty_phrases = [
        "не знаю",
        "не могу оценить",
        "не получается оценить",
        "сложно оценить",
        "не понимаю сколько",
        "не понимаю какое число",
        "не могу выбрать число",
        "затрудняюсь",
        "не уверена",
        "не уверен",
    ]

    return any(
        phrase == normalized
        or phrase in normalized
        for phrase in uncertainty_phrases
    )


def extract_emotion_values(value: Any) -> list[int]:
    
    values: list[int] = []

    def collect(item: Any):
        if item is None:
            return

        if isinstance(item, bool):
            return

        if isinstance(item, int):
            if 0 <= item <= 100:
                values.append(item)
            return

        if isinstance(item, float):
            if 0 <= item <= 100:
                values.append(round(item))
            return

        if isinstance(item, str):
            numbers = re.findall(
                r"(?<!\d)(100|\d{1,2})(?!\d)",
                item,
            )

            for number in numbers:
                try:
                    parsed = int(number)
                except ValueError:
                    continue

                if 0 <= parsed <= 100:
                    values.append(parsed)

            return

        if isinstance(item, dict):
            for nested_value in item.values():
                collect(nested_value)
            return

        if isinstance(item, list):
            for nested_value in item:
                collect(nested_value)

    collect(value)

    return values


def build_wellbeing_help_reply(
    emotions_after: Any,
) -> str:

    values = extract_emotion_values(
        emotions_after
    )

    raw_text = ""

    if isinstance(emotions_after, dict):
        raw_value = emotions_after.get(
            "raw_text"
        )

        if isinstance(raw_value, str):
            raw_text = raw_value

    elif isinstance(emotions_after, str):
        raw_text = emotions_after

    normalized = (
        raw_text.lower()
        .replace("ё", "е")
    )

    positive_markers = [
        "радость",
        "спокойствие",
        "облегчение",
        "надежда",
        "уверенность",
        "удовлетворение",
        "интерес",
        "воодушевление",
        "тепло",
        "счастье",
    ]

    negative_markers = [
        "тревога",
        "страх",
        "злость",
        "грусть",
        "вина",
        "стыд",
        "обида",
        "паника",
        "раздражение",
        "беспомощность",
        "бессилие",
        "одиночество",
        "растерянность",
        "усталость",
        "разочарование",
        "отчаяние",
    ]

    has_positive = any(
        marker in normalized
        for marker in positive_markers
    )

    has_negative = any(
        marker in normalized
        for marker in negative_markers
    )

    if values and has_negative and not has_positive:
        average_intensity = (
            sum(values) / len(values)
        )

        suggested_score = round(
            100 - average_intensity
        )

        suggested_score = max(
            0,
            min(100, suggested_score),
        )

        return (
            f"Можно взять ориентир около {suggested_score}: "
            "чем слабее неприятные эмоции, тем выше общая оценка. "
            "Какое одно число от 0 до 100 подходит тебе сейчас?"
        )

    if values and has_positive and not has_negative:
        suggested_score = round(
            sum(values) / len(values)
        )

        suggested_score = max(
            0,
            min(100, suggested_score),
        )

        return (
            f"Можно взять ориентир около {suggested_score}, "
            "опираясь на интенсивность положительных эмоций. "
            "Какое одно число от 0 до 100 подходит тебе сейчас?"
        )

    return (
        "Попробуй не искать идеальную точность: "
        "0 означает, что сейчас очень тяжело, "
        "50 — нейтральное или смешанное состояние, "
        "100 — спокойно и хорошо. "
        "Какое одно число ближе всего?"
    )

def looks_like_emotion_words_without_intensity(message: str) -> bool:
    """
    Проверяет, что пользователь назвал эмоции,
    но не указал интенсивность.

    Это нужно, чтобы не сохранять "Тревога и страх" как полноценный emotions_before.
    """

    if not message:
        return False

    normalized = message.lower().replace("ё", "е")

    emotion_words = [
        "тревога",
        "тревожно",
        "страх",
        "страшно",
        "стыд",
        "стыдно",
        "вина",
        "виноват",
        "виновата",
        "грусть",
        "грустно",
        "злость",
        "злюсь",
        "обида",
        "обидно",
        "растерянность",
        "растеряна",
        "растерян",
        "беспомощность",
        "бессилие",
        "одиночество",
        "одиноко",
        "паника",
        "раздражение",
        "раздражена",
        "раздражен",
    ]

    has_emotion_word = any(word in normalized for word in emotion_words)

    return has_emotion_word and not has_emotion_intensity(message)


def build_ask_emotion_intensity_reply(message: str) -> str:
    """
    Ответ, когда эмоции названы, но нет оценки 0–100.
    """

    return (
        "Ты уже назвала эмоции. Теперь оцени каждую примерно от 0 до 100, "
        "например: тревога — 80, страх — 60."
    )


def needs_stabilization(message: str) -> bool:
    """
    Проверяет, нужно ли временно остановить КПТ-разбор
    и перейти в стабилизацию.

    Важно:
    Стабилизация НЕ должна включаться просто из-за слов:
    - тревога
    - страх
    - паника
    - мне плохо
    - я не знаю
    - не могу думать о других

    Эти фразы часто являются обычным материалом для КПТ-дневника.

    Стабилизацию включаем только если пользователь явно сообщает,
    что прямо сейчас не может продолжать диалог, отвечать, дышать
    или удерживаться в контакте.
    """

    if not message:
        return False

    normalized = message.lower().strip()
    normalized = normalized.replace("ё", "е")

    safe_context_phrases = [
        "не могу думать о других",
        "не могу думать об этом человеке",
        "не могу думать о нем",
        "не могу думать о ней",
        "не могу думать о них",
        "не могу думать о работе",
        "не могу думать об учебе",
        "не могу думать о будущем",
        "не могу думать ни о чем хорошем",
        "не могу думать позитивно",
    ]

    if any(phrase in normalized for phrase in safe_context_phrases):
        return False

    direct_shutdown_markers = [
        "не могу продолжать",
        "я не могу продолжать",
        "не могу дальше",
        "я не могу дальше",
        "не могу сейчас отвечать",
        "я не могу сейчас отвечать",
        "не могу ответить",
        "я не могу ответить",
        "не могу говорить",
        "я не могу говорить",
        "не могу писать",
        "я не могу писать",
        "мне нужно остановиться",
        "давай остановимся",
        "останови сессию",
        "остановись",
    ]

    if any(marker in normalized for marker in direct_shutdown_markers):
        return True

    body_overload_markers = [
        "меня трясет",
        "меня всю трясет",
        "меня сильно трясет",
        "я вся трясусь",
        "я весь трясусь",
        "дрожу",
        "дрожь",
        "не могу дышать",
        "тяжело дышать",
        "задыхаюсь",
        "не хватает воздуха",
        "сейчас упаду",
        "я сейчас упаду",
        "теряю контроль",
        "я теряю контроль",
        "меня накрывает так, что не могу",
    ]

    if any(marker in normalized for marker in body_overload_markers):
        return True

    thinking_shutdown_patterns = [
        "не могу думать сейчас",
        "я не могу думать сейчас",
        "не могу сейчас думать",
        "я не могу сейчас думать",
        "не могу думать, меня",
        "не могу думать и отвечать",
        "не могу думать и продолжать",
        "не могу думать, не могу продолжать",
    ]

    if any(pattern in normalized for pattern in thinking_shutdown_patterns):
        return True

    return False

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
        "wellbeing_score_after": (
            session.wellbeing_score_after
        ),
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
        wellbeing_score_after=(
            session.wellbeing_score_after
        ),
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
            session.wellbeing_score_after
            is not None,
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
        
    if session.current_step == "EMOTIONS" and looks_like_emotion_words_without_intensity(
        message_data.content
    ):
        user_message = CBTMessage(
            session_id=session.id,
            role="user",
            content=message_data.content,
            used_technique=None,
        )

        assistant_message = CBTMessage(
            session_id=session.id,
            role="assistant",
            content=build_ask_emotion_intensity_reply(message_data.content),
            used_technique="NONE",
        )

        session.current_step = "EMOTIONS"
        session.current_phase = "EMOTION_ASSESSMENT"

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

    if session.current_step == "RESULT":
        # Первый ответ на RESULT — это эмоции после разбора.
        if not session.emotions_after:
            session.emotions_after = {
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
                content=WELLBEING_SCORE_QUESTION,
                used_technique="SUMMARY",
            )

            session.current_step = "RESULT"
            session.current_phase = "SUMMARY"

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

        wellbeing_score = extract_wellbeing_score(
            message_data.content
        )

        if wellbeing_score is None:
            if is_wellbeing_uncertainty_message(
                message_data.content
            ):
                assistant_reply = (
                    build_wellbeing_help_reply(
                        session.emotions_after
                    )
                )
            else:
                assistant_reply = (
                    WELLBEING_SCORE_INVALID_REPLY
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
                used_technique="SUMMARY",
            )

            session.current_step = "RESULT"
            session.current_phase = "SUMMARY"

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

        session.wellbeing_score_after = (
            wellbeing_score
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
            content=WELLBEING_SCORE_FINISH_REPLY,
            used_technique="SUMMARY",
        )

        db.add(user_message)
        db.add(assistant_message)

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
    
    if (
        session.current_step == "RESULT"
        and session.emotions_after
        and session.wellbeing_score_after is None
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Перед завершением оцени общее "
                "состояние от 0 до 100"
            ),
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
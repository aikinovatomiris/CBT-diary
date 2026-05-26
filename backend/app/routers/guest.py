from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.ai.cbt_assistant import generate_cbt_reply
from app.ai.guardrails import is_crisis_message, is_off_topic


router = APIRouter(
    prefix="/guest",
    tags=["Guest CBT"],
)


GuestCBTStep = Literal[
    "SITUATION",
    "AUTOMATIC_THOUGHT",
    "EMOTIONS",
    "EVIDENCE_FOR",
    "EVIDENCE_AGAINST",
    "ALTERNATIVE_THOUGHT",
    "RESULT",
    "FINISHED",
]


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


GUEST_NOTICE = (
    "Гостевой режим не сохраняет данные. "
    "Зарегистрируйтесь, чтобы вести дневник."
)

OFF_TOPIC_REPLY = (
    "Я могу помогать только в рамках КПТ-дневника: с ситуациями, мыслями, "
    "эмоциями и их анализом. Давай вернемся к текущей ситуации."
)

CRISIS_REPLY = (
    "Мне очень жаль, что тебе сейчас так тяжело. Я не могу заменить экстренную помощь. "
    "Пожалуйста, обратись к человеку рядом, которому доверяешь, или в экстренные службы. "
    "Телефоны доверия Казахстана - 111 и 150. Помни, что ты не один."
)


class GuestCBTMessageRequest(BaseModel):
    message: str = Field(min_length=1)
    current_step: GuestCBTStep = "SITUATION"


class GuestCBTMessageResponse(BaseModel):
    assistant_reply: str
    current_step: str
    notice: str


def get_next_step(current_step: str) -> str:
    if current_step not in CBT_STEPS:
        return "SITUATION"

    current_index = CBT_STEPS.index(current_step)

    if current_index >= len(CBT_STEPS) - 1:
        return "FINISHED"

    return CBT_STEPS[current_index + 1]


def get_phase_for_step(step: str) -> str:
    return STEP_TO_PHASE.get(step, "SITUATION_ANALYSIS")


def build_guest_session_data(current_step: str) -> dict:
    """
    Guest-режим не хранит историю и не создает CBTSession.
    Поэтому передаем в AI минимальный session_data, похожий на обычную сессию.
    """

    return {
        "id": None,
        "user_id": None,
        "status": "guest",
        "current_step": current_step,
        "current_phase": get_phase_for_step(current_step),
        "assistant_style": "supportive",

        "situation": None,
        "automatic_thought": None,
        "emotions_before": None,
        "evidence_for": None,
        "evidence_against": None,
        "user_alternative_thought": None,
        "assistant_alternative_thought": None,
        "final_alternative_thought": None,
        "emotions_after": None,
    }


@router.post(
    "/cbt/message",
    response_model=GuestCBTMessageResponse,
)
def send_guest_cbt_message(
    message_data: GuestCBTMessageRequest,
):
    current_step = message_data.current_step
    user_message = message_data.message

    if current_step == "FINISHED":
        return {
            "assistant_reply": (
                "Гостевая КПТ-сессия уже дошла до завершения. "
                "Чтобы сохранить запись и вернуться к ней позже, лучше зарегистрироваться."
            ),
            "current_step": "FINISHED",
            "notice": GUEST_NOTICE,
        }

    # 1. Crisis check — до LLM и до off-topic.
    # В гостевом режиме ничего не сохраняем и шаг не продвигаем.
    if is_crisis_message(user_message):
        return {
            "assistant_reply": CRISIS_REPLY,
            "current_step": current_step,
            "notice": GUEST_NOTICE,
        }

    # 2. Off-topic check — тоже до LLM.
    # Не сохраняем и не продвигаем шаг.
    if is_off_topic(user_message):
        return {
            "assistant_reply": OFF_TOPIC_REPLY,
            "current_step": current_step,
            "notice": GUEST_NOTICE,
        }

    session_data = build_guest_session_data(
        current_step=current_step,
    )

    assistant_result = generate_cbt_reply(
        current_step=current_step,
        user_message=user_message,
        session_data=session_data,
    )

    next_step = current_step

    if assistant_result.get("should_advance"):
        next_step = get_next_step(current_step)

    if assistant_result.get("should_finish"):
        next_step = "FINISHED"

    return {
        "assistant_reply": assistant_result["assistant_reply"],
        "current_step": next_step,
        "notice": GUEST_NOTICE,
    }
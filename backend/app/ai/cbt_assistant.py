import json
import logging
import re
from typing import Any

from app.ai.llm_client import call_llm
from app.ai.prompts import (
    build_json_instruction,
    build_session_prompt,
    build_system_prompt,
)
from app.ai.types import CBTAssistantResult, parse_llm_json_response


logger = logging.getLogger(__name__)


DEFAULT_DIARY_CONCLUSION = "Запись создана автоматически после КПТ-сессии"


VALID_TECHNIQUES = {
    "NONE",
    "GROUNDING",
    "SOCRATIC_DIALOGUE",
    "DOWNWARD_ARROW",
    "REFRAMING",
    "SUMMARY",
}


STEP_TO_DEFAULT_PHASE = {
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


REPEATED_OPENINGS = [
    "Спасибо, что поделились. ",
    "Спасибо, что поделилась. ",
    "Спасибо, что рассказали. ",
    "Спасибо, что рассказала. ",
    "Спасибо за то, что поделились. ",
    "Спасибо за то, что поделилась. ",
    "Благодарю, что поделились. ",
    "Понимаю. ",
    "Понимаю, что это непросто. ",
]


ALLOWED_COGNITIVE_DISTORTIONS = {
    "катастрофизация",
    "черно-белое мышление",
    "чрезмерное обобщение",
    "чтение мыслей",
    "персонализация",
    "обесценивание положительного",
    "долженствование",
    "эмоциональное обоснование",
    "навешивание ярлыков",
}


def clean_assistant_reply(text: str) -> str:
    if not text:
        return "Давай продолжим разбирать ситуацию спокойно и по шагам."

    cleaned = text.strip()

    for opening in REPEATED_OPENINGS:
        if cleaned.startswith(opening):
            cleaned = cleaned.replace(opening, "", 1).strip()
            break

    if not cleaned:
        return "Давай продолжим разбирать ситуацию спокойно и по шагам."

    return cleaned


def has_high_emotion_intensity(user_message: str) -> bool:
    """
    Определяет высокую интенсивность эмоций.

    Важно:
    Высокая интенсивность сама по себе НЕ равна необходимости grounding.
    Например "тревога 90, страх 80" — это нормальный ответ для шага EMOTIONS.
    В таком случае нужно сохранить эмоции и продолжить КПТ бережно.
    """

    numbers = re.findall(r"\b\d{1,3}\b", user_message)

    for number in numbers:
        try:
            value = int(number)
        except ValueError:
            continue

        if 90 <= value <= 100:
            return True

    intense_words = [
        "очень сильно",
        "очень сильная тревога",
        "очень сильный страх",
        "сильная тревога",
        "сильный страх",
        "паника",
        "паникую",
        "ужас",
        "ужасно",
    ]

    normalized = user_message.lower()

    return any(word in normalized for word in intense_words)


def is_vague_message(user_message: str) -> bool:
    normalized = user_message.lower().strip()

    vague_messages = {
        "мне плохо",
        "плохо",
        "не знаю",
        "не понимаю",
        "сложно сказать",
        "не могу ответить",
        "не хочу говорить",
        "ничего",
    }

    if normalized in vague_messages:
        return True

    if len(normalized.split()) <= 2:
        return True

    return False

def is_emotion_uncertainty_message(user_message: str) -> bool:
    normalized = user_message.lower().strip().replace("ё", "е")

    uncertainty_phrases = [
        "не знаю что чувствую",
        "не знаю, что чувствую",
        "не знаю что испытываю",
        "не знаю, что испытываю",
        "не понимаю что чувствую",
        "не понимаю, что чувствую",
        "не могу понять что чувствую",
        "не могу понять, что чувствую",
        "сложно понять что чувствую",
        "сложно сказать что чувствую",
        "я не знаю",
        "не знаю",
        "не понимаю",
    ]

    return any(phrase == normalized or phrase in normalized for phrase in uncertainty_phrases)

def has_emotion_intensity(user_message: str) -> bool:
    numbers = re.findall(r"\b\d{1,3}\b", user_message)

    for number in numbers:
        try:
            value = int(number)
        except ValueError:
            continue

        if 0 <= value <= 100:
            return True

    return False


def has_emotion_words(user_message: str) -> bool:
    normalized = user_message.lower().replace("ё", "е")

    emotion_words = [
        "тревога",
        "тревожно",
        "страх",
        "страшно",
        "стыд",
        "стыдно",
        "вина",
        "грусть",
        "грустно",
        "злость",
        "обида",
        "растерянность",
        "беспомощность",
        "бессилие",
        "паника",
        "раздражение",
    ]

    return any(word in normalized for word in emotion_words)


def is_alternative_thought_uncertainty_message(user_message: str) -> bool:
    normalized = user_message.lower().strip().replace("ё", "е")

    uncertainty_phrases = [
        "не знаю",
        "не получается",
        "не могу сформулировать",
        "не могу придумать",
        "не понимаю как",
        "не знаю как",
        "никак",
        "сложно",
        "сложно сформулировать",
        "не выходит",
    ]

    return any(phrase == normalized or phrase in normalized for phrase in uncertainty_phrases)


def should_use_grounding_for_message(user_message: str) -> bool:
    """
    Grounding нужен не при любой тревоге и не при любой оценке 90/100.
    Он нужен, когда пользователь явно не может продолжать диалог
    или описывает сильную телесную перегрузку прямо сейчас.
    """

    normalized = user_message.lower().strip().replace("ё", "е")

    safe_context_phrases = [
        "не могу думать о других",
        "не могу думать о работе",
        "не могу думать об учебе",
        "не могу думать о будущем",
        "не могу думать ни о чем хорошем",
    ]

    if any(phrase in normalized for phrase in safe_context_phrases):
        return False

    grounding_markers = [
        "меня трясет",
        "меня всю трясет",
        "я вся трясусь",
        "я весь трясусь",
        "дрожу",
        "дрожь",
        "не могу продолжать",
        "не могу дальше",
        "не могу сейчас отвечать",
        "не могу ответить",
        "не могу говорить",
        "не могу писать",
        "не могу дышать",
        "тяжело дышать",
        "задыхаюсь",
        "не хватает воздуха",
        "сейчас упаду",
        "теряю контроль",
        "меня накрывает так, что не могу",
    ]

    return any(marker in normalized for marker in grounding_markers)


def looks_like_situation(user_message: str) -> bool:
    """
    Проверяет, похоже ли сообщение на достаточно понятную ситуацию.

    Нам не нужно идеально определять ситуацию.
    Важно лишь не заставлять пользователя повторять то, что он уже сказал.
    """

    if is_vague_message(user_message):
        return False

    normalized = user_message.lower()

    situation_markers = [
        "поссор",
        "сказал",
        "сказала",
        "накрич",
        "произош",
        "случил",
        "забыла",
        "забыл",
        "не выполнила",
        "не выполнил",
        "мама",
        "папа",
        "подруга",
        "друг",
        "парень",
        "учеб",
        "работ",
        "экзамен",
        "дома",
        "вчера",
        "сегодня",
    ]

    thought_markers = [
        "я подумала",
        "я подумал",
        "мне показалось",
        "я решила",
        "я решил",
        "что я",
        "будто я",
    ]

    has_situation_marker = any(marker in normalized for marker in situation_markers)
    has_thought_marker = any(marker in normalized for marker in thought_markers)

    return has_situation_marker or has_thought_marker or len(normalized.split()) >= 7


def choose_variant(variants: list[str], seed_text: str) -> str:
    """
    Детерминированно выбирает вариант ответа.
    Это делает fallback менее шаблонным, но не рандомным.
    """

    if not variants:
        return "Продолжим разбирать ситуацию спокойно и по шагам."

    seed = sum(ord(char) for char in seed_text)
    index = seed % len(variants)

    return variants[index]


def normalize_used_technique(
    current_step: str,
    llm_technique: str | None,
    user_message: str = "",
    should_advance: bool = True,
) -> str:
    """
    Нормализует технику.

    Главное правило:
    GROUNDING разрешаем только если сообщение реально похоже
    на невозможность продолжать диалог или телесную перегрузку.
    Просто тревога, страх, паника или оценка 90/100 — недостаточная причина.
    """

    if current_step == "SITUATION":
        default_technique = "DOWNWARD_ARROW" if should_advance else "NONE"

    elif current_step == "AUTOMATIC_THOUGHT":
        default_technique = "NONE"

    elif current_step == "EMOTIONS":
        default_technique = "SOCRATIC_DIALOGUE" if should_advance else "NONE"

    elif current_step == "EVIDENCE_FOR":
        default_technique = "SOCRATIC_DIALOGUE"

    elif current_step == "EVIDENCE_AGAINST":
        default_technique = "REFRAMING"

    elif current_step == "ALTERNATIVE_THOUGHT":
        default_technique = "SUMMARY"

    elif current_step == "RESULT":
        default_technique = "SUMMARY"

    else:
        default_technique = "NONE"

    if not llm_technique:
        return default_technique

    if llm_technique not in VALID_TECHNIQUES:
        return default_technique

    if llm_technique == "GROUNDING":
        if should_use_grounding_for_message(user_message):
            return "GROUNDING"

        return default_technique

    if llm_technique == "NONE" and default_technique != "NONE":
        return default_technique

    return llm_technique


def normalize_current_phase(
    current_step: str,
    llm_phase: str | None,
    user_message: str = "",
) -> str:
    if llm_phase == "STABILIZATION":
        if should_use_grounding_for_message(user_message):
            return "STABILIZATION"

        return STEP_TO_DEFAULT_PHASE.get(current_step, "SITUATION_ANALYSIS")

    if llm_phase in VALID_PHASES:
        return llm_phase

    return STEP_TO_DEFAULT_PHASE.get(current_step, "SITUATION_ANALYSIS")


def should_use_llm_result(parsed_result) -> bool:
    if parsed_result.diary_readiness_score == 0 and not parsed_result.should_advance:
        if parsed_result.used_technique == "NONE":
            return False

    return True


def generate_fake_cbt_reply(
    current_step: str,
    user_message: str = "",
    session_data: dict | None = None,
) -> CBTAssistantResult:
    """
    Умный fallback без LLM.

    Он не должен заменять LLM, но должен вести сессию безопасно и логично:
    - не включать grounding без причины;
    - помогать, если пользователь не знает эмоции;
    - помогать с альтернативной мыслью, если пользователь не может сформулировать;
    - задавать только один вопрос.
    """

    session_data = session_data or {}

    if current_step == "SITUATION":
        if looks_like_situation(user_message):
            variants = [
                "Какая мысль появилась у тебя в тот момент?",
                "Что эта ситуация будто сказала о тебе?",
                "Если закончить фразу «это значит, что...», что получится?",
                "Какая первая болезненная мысль возникла, когда это произошло?",
            ]

            assistant_reply = choose_variant(
                variants=variants,
                seed_text=user_message,
            )

            used_technique = "DOWNWARD_ARROW"
            should_advance = True
            current_phase = "THOUGHT_IDENTIFICATION"

        else:
            variants = [
                "Давай выберем один конкретный момент. Что именно произошло?",
                "Чтобы не разбирать всё сразу, опиши один эпизод: что случилось?",
                "Попробуй назвать конкретную ситуацию, которую хочешь разобрать.",
            ]

            assistant_reply = choose_variant(
                variants=variants,
                seed_text=user_message,
            )

            used_technique = "NONE"
            should_advance = False
            current_phase = "SITUATION_ANALYSIS"

    elif current_step == "AUTOMATIC_THOUGHT":
        variants = [
            "Какие эмоции появились после этой мысли? Оцени каждую примерно от 0 до 100.",
            "Что ты почувствовала в тот момент? Можно написать так: тревога — 80, вина — 60.",
            "Давай зафиксируем эмоции: какие чувства были и насколько сильные от 0 до 100?",
        ]

        assistant_reply = choose_variant(
            variants=variants,
            seed_text=user_message,
        )
        used_technique = "NONE"
        should_advance = True
        current_phase = "EMOTION_ASSESSMENT"

    elif current_step == "EMOTIONS":
        if should_use_grounding_for_message(user_message):
            variants = [
                "Сейчас важнее немного стабилизироваться. Почувствуй опору под собой и назови один предмет рядом, который видишь.",
                "Давай на секунду остановимся. Сделай медленный выдох и назови один звук, который слышишь сейчас.",
            ]

            assistant_reply = choose_variant(
                variants=variants,
                seed_text=user_message,
            )
            used_technique = "GROUNDING"
            should_advance = False
            current_phase = "STABILIZATION"

        elif is_emotion_uncertainty_message(user_message):
            assistant_reply = (
                "Можно начать с простого выбора. Что ближе к твоему состоянию сейчас: "
                "тревога, страх, вина, стыд, злость, грусть или растерянность?"
            )
            used_technique = "NONE"
            should_advance = False
            current_phase = "EMOTION_ASSESSMENT"

        elif has_emotion_words(user_message) and not has_emotion_intensity(user_message):
            assistant_reply = (
                "Ты уже назвала эмоции. Теперь оцени каждую примерно от 0 до 100, "
                "например: тревога — 80, страх — 60."
            )
            used_technique = "NONE"
            should_advance = False
            current_phase = "EMOTION_ASSESSMENT"

        else:
            if has_high_emotion_intensity(user_message):
                assistant_reply = (
                    "Эмоции очень сильные, поэтому пойдем бережно. "
                    "Какие факты подтверждают эту автоматическую мысль?"
                )
            else:
                assistant_reply = "Какие факты подтверждают эту автоматическую мысль?"

            used_technique = "SOCRATIC_DIALOGUE"
            should_advance = True
            current_phase = "COGNITIVE_RESTRUCTURING"

    elif current_step == "EVIDENCE_FOR":
        if is_vague_message(user_message):
            assistant_reply = (
                "Можно назвать даже один небольшой факт. Что реально произошло, что будто подтверждает эту мысль?"
            )
            used_technique = "SOCRATIC_DIALOGUE"
            should_advance = False
            current_phase = "COGNITIVE_RESTRUCTURING"
        else:
            variants = [
                "А теперь посмотрим с другой стороны. Какие факты говорят против этой мысли?",
                "Что показывает, что эта мысль может быть не полностью точной?",
                "Есть ли хотя бы один факт, который делает ситуацию не такой однозначной?",
            ]

            assistant_reply = choose_variant(
                variants=variants,
                seed_text=user_message,
            )
            used_technique = "SOCRATIC_DIALOGUE"
            should_advance = True
            current_phase = "COGNITIVE_RESTRUCTURING"

    elif current_step == "EVIDENCE_AGAINST":
        if is_vague_message(user_message):
            assistant_reply = (
                "Если факты против сложно найти, попробуй мягче: что бы ты сказала близкому человеку в такой ситуации?"
            )
            used_technique = "SOCRATIC_DIALOGUE"
            should_advance = False
            current_phase = "COGNITIVE_RESTRUCTURING"
        else:
            variants = [
                "Теперь попробуем собрать более сбалансированную мысль. Как она могла бы звучать?",
                "Как можно сформулировать мысль мягче и реалистичнее, без ярлыка на себя?",
                "Если учесть и трудность ситуации, и факты против автоматической мысли, какая мысль будет справедливее?",
            ]

            assistant_reply = choose_variant(
                variants=variants,
                seed_text=user_message,
            )
            used_technique = "REFRAMING"
            should_advance = True
            current_phase = "ALTERNATIVE_FORMULATION"

    elif current_step == "ALTERNATIVE_THOUGHT":
        if is_alternative_thought_uncertainty_message(user_message):
            situation = session_data.get("situation")
            automatic_thought = session_data.get("automatic_thought")
            evidence_against = session_data.get("evidence_against")

            suggested_thought = "Сейчас мне трудно, но это не значит, что автоматическая мысль полностью верна. Я могу посмотреть на ситуацию более спокойно и опереться на факты."

            if automatic_thought and evidence_against:
                suggested_thought = (
                    "Мне сейчас тяжело, но моя автоматическая мысль может быть не всей правдой. "
                    "Есть факты, которые показывают, что ситуацию можно увидеть мягче и реалистичнее."
                )

            assistant_reply = (
                f"Можно взять мягкий черновик: «{suggested_thought}» "
                "Насколько эта мысль тебе подходит?"
            )

            used_technique = "REFRAMING"
            should_advance = False
            current_phase = "ALTERNATIVE_FORMULATION"

            return {
                "assistant_reply": clean_assistant_reply(assistant_reply),
                "should_advance": should_advance,
                "used_technique": used_technique,
                "extracted_data": {
                    "assistant_alternative_thought": suggested_thought
                },
                "current_phase": current_phase,
                "should_finish": False,
                "diary_readiness_score": 0,
                "assistant_alternative_thought": suggested_thought,
                "final_alternative_thought": None,
            }

        variants = [
            "Как теперь изменилась интенсивность эмоций от 0 до 100?",
            "Давай сравним состояние после разбора. Насколько сейчас сильны эмоции от 0 до 100?",
            "Что изменилось в эмоциях после этой более сбалансированной мысли?",
        ]

        assistant_reply = choose_variant(
            variants=variants,
            seed_text=user_message,
        )
        used_technique = "SUMMARY"
        should_advance = True
        current_phase = "SUMMARY"

    elif current_step == "RESULT":
        assistant_reply = "Сессия завершена. Я сохраню эту запись в дневник, чтобы ты могла вернуться к ней позже."
        used_technique = "SUMMARY"
        should_advance = True
        current_phase = "FINISHED"

    else:
        assistant_reply = "Давай продолжим разбирать ситуацию спокойно и по шагам."
        used_technique = "NONE"
        should_advance = False
        current_phase = "SITUATION_ANALYSIS"

    return {
        "assistant_reply": clean_assistant_reply(assistant_reply),
        "should_advance": should_advance,
        "used_technique": normalize_used_technique(
            current_step=current_step,
            llm_technique=used_technique,
            user_message=user_message,
            should_advance=should_advance,
        ),
        "extracted_data": {},
        "current_phase": current_phase,
        "should_finish": False,
        "diary_readiness_score": 0,
        "assistant_alternative_thought": None,
        "final_alternative_thought": None,
    }


def generate_cbt_reply(
    current_step: str,
    user_message: str,
    session_data: dict,
) -> CBTAssistantResult:
    current_phase = session_data.get("current_phase", "SITUATION_ANALYSIS")

    messages = [
        {
            "role": "system",
            "content": build_system_prompt(),
        },
        {
            "role": "user",
            "content": build_session_prompt(
                current_phase=current_phase,
                current_step=current_step,
                session_data=session_data,
                user_message=user_message,
            ),
        },
        {
            "role": "user",
            "content": build_json_instruction(),
        },
    ]

    raw_llm_response = call_llm(messages)

    if not raw_llm_response:
        return generate_fake_cbt_reply(
            current_step=current_step,
            user_message=user_message,
            session_data=session_data,
        )
    parsed_result = parse_llm_json_response(raw_llm_response)

    if not should_use_llm_result(parsed_result):
        return generate_fake_cbt_reply(
            current_step=current_step,
            user_message=user_message,
            session_data=session_data,
        )

    session_update = parsed_result.session_update.model_dump(exclude_none=True)

    assistant_reply = clean_assistant_reply(parsed_result.assistant_reply)

    used_technique = normalize_used_technique(
        current_step=current_step,
        llm_technique=parsed_result.used_technique,
        user_message=user_message,
        should_advance=parsed_result.should_advance,
    )
    if parsed_result.used_technique == "GROUNDING" and used_technique != "GROUNDING":
        return generate_fake_cbt_reply(
            current_step=current_step,
            user_message=user_message,
            session_data=session_data,
        )

    current_phase = normalize_current_phase(
        current_step=current_step,
        llm_phase=parsed_result.current_phase,
        user_message=user_message,
    )

    return {
        "assistant_reply": assistant_reply,
        "should_advance": parsed_result.should_advance,
        "used_technique": used_technique,
        "extracted_data": session_update,
        "current_phase": current_phase,
        "should_finish": parsed_result.should_finish,
        "diary_readiness_score": parsed_result.diary_readiness_score,
        "assistant_alternative_thought": session_update.get("assistant_alternative_thought"),
        "final_alternative_thought": session_update.get("final_alternative_thought"),
    }


def _clean_json_response(raw_response: str) -> str:
    cleaned_response = raw_response.strip()

    if cleaned_response.startswith("```json"):
        cleaned_response = cleaned_response.replace("```json", "", 1).strip()

    if cleaned_response.startswith("```"):
        cleaned_response = cleaned_response.replace("```", "", 1).strip()

    if cleaned_response.endswith("```"):
        cleaned_response = cleaned_response[:-3].strip()

    return cleaned_response


def _safe_empty_distortions() -> dict:
    return {
        "items": []
    }


def _validate_distortions_result(data: Any) -> dict:
    if not isinstance(data, dict):
        return _safe_empty_distortions()

    items = data.get("items")

    if not isinstance(items, list):
        return _safe_empty_distortions()

    validated_items = []

    for item in items:
        if not isinstance(item, dict):
            continue

        name = item.get("name")
        explanation = item.get("explanation")

        if not isinstance(name, str):
            continue

        normalized_name = name.strip().lower()

        if normalized_name not in ALLOWED_COGNITIVE_DISTORTIONS:
            continue

        if not isinstance(explanation, str) or not explanation.strip():
            explanation = "Искажение определено на основе автоматической мысли."

        validated_items.append(
            {
                "name": normalized_name,
                "explanation": explanation.strip(),
            }
        )

    return {
        "items": validated_items
    }


def detect_cognitive_distortions(session_data: dict) -> dict:
    automatic_thought = session_data.get("automatic_thought")
    situation = session_data.get("situation")
    evidence_for = session_data.get("evidence_for")
    evidence_against = session_data.get("evidence_against")

    thoughts = []

    if automatic_thought:
        thoughts.append(automatic_thought)

    if session_data.get("user_alternative_thought"):
        thoughts.append(session_data["user_alternative_thought"])

    prompt = f"""
Ты анализируешь КПТ-дневник и определяешь возможные когнитивные искажения.

Используй только этот список искажений:
- катастрофизация
- черно-белое мышление
- чрезмерное обобщение
- чтение мыслей
- персонализация
- обесценивание положительного
- долженствование
- эмоциональное обоснование
- навешивание ярлыков

Данные сессии:

Ситуация:
{situation or "Не заполнено"}

Автоматическая мысль:
{automatic_thought or "Не заполнено"}

Мысли:
{thoughts or "Не заполнено"}

Доказательства за автоматическую мысль:
{evidence_for or "Не заполнено"}

Доказательства против автоматической мысли:
{evidence_against or "Не заполнено"}

Задача:
Определи, какие когнитивные искажения можно уверенно увидеть в автоматической мысли и контексте.

Правила:
1. Не выдумывай искажения.
2. Если данных недостаточно, верни пустой список.
3. Используй только названия из списка.
4. explanation должен быть коротким, понятным и только на русском языке.
5. Не используй английские слова или английские фразы.
6. Верни только JSON.
7. Не добавляй markdown.
8. Не оборачивай JSON в ```.

Формат ответа:
{{
  "items": [
    {{
      "name": "катастрофизация",
      "explanation": "короткое объяснение"
    }}
  ]
}}
""".strip()

    messages = [
        {
            "role": "system",
            "content": (
                "Ты помощник для анализа КПТ-дневника. "
                "Твоя задача — определить когнитивные искажения строго по заданному списку. "
                "Не ставь диагнозы и не давай медицинских советов. "
                "Все названия и объяснения должны быть только на русском языке."
            ),
        },
        {
            "role": "user",
            "content": prompt,
        },
    ]

    try:
        raw_response = call_llm(messages)

        if not raw_response:
            return _safe_empty_distortions()

        cleaned_response = _clean_json_response(raw_response)
        parsed_data = json.loads(cleaned_response)

        return _validate_distortions_result(parsed_data)

    except json.JSONDecodeError:
        logger.warning("Invalid JSON from LLM while detecting cognitive distortions.")
        return _safe_empty_distortions()

    except Exception as error:
        logger.exception("Failed to detect cognitive distortions: %s", error)
        return _safe_empty_distortions()


def generate_diary_conclusion(session_data: dict) -> str:
    situation = session_data.get("situation")
    automatic_thought = session_data.get("automatic_thought")
    emotions_before = session_data.get("emotions_before")
    evidence_for = session_data.get("evidence_for")
    evidence_against = session_data.get("evidence_against")
    user_alternative_thought = session_data.get("user_alternative_thought")
    assistant_alternative_thought = session_data.get("assistant_alternative_thought")
    final_alternative_thought = session_data.get("final_alternative_thought")
    emotions_after = session_data.get("emotions_after")

    prompt = f"""
Составь короткий нейтральный вывод для записи КПТ-дневника.

Этот текст будет показан пользователю и может быть показан реальному специалисту.

Данные сессии:

Ситуация:
{situation or "Не заполнено"}

Автоматическая мысль:
{automatic_thought or "Не заполнено"}

Эмоции до:
{emotions_before or "Не заполнено"}

Доказательства за автоматическую мысль:
{evidence_for or "Не заполнено"}

Доказательства против автоматической мысли:
{evidence_against or "Не заполнено"}

Альтернативная мысль пользователя:
{user_alternative_thought or "Не заполнено"}

Альтернативная мысль ассистента:
{assistant_alternative_thought or "Не заполнено"}

Финальная альтернативная мысль:
{final_alternative_thought or "Не заполнено"}

Эмоции после:
{emotions_after or "Не заполнено"}

Правила:
1. Напиши максимум 4 предложения.
2. Тон нейтральный, спокойный, без оценок.
3. Не используй диагнозы.
4. Не пиши от имени психолога.
5. Не делай медицинских выводов.
6. Не используй фразы вроде "у пользователя депрессия", "тревожное расстройство".
7. Не добавляй советов и назначений.
8. Не выдумывай данные, которых нет.
9. Верни только JSON.
10. Не добавляй markdown.
11. Не оборачивай JSON в ```.

Формат ответа:
{{
  "conclusion": "короткий нейтральный вывод максимум в 4 предложения"
}}
""".strip()

    messages = [
        {
            "role": "system",
            "content": (
                "Ты помощник для структурирования КПТ-дневника. "
                "Твоя задача — сформулировать короткий нейтральный вывод по данным сессии. "
                "Не ставь диагнозы, не делай медицинских выводов и не пиши от имени психолога."
            ),
        },
        {
            "role": "user",
            "content": prompt,
        },
    ]

    try:
        raw_response = call_llm(messages)

        if not raw_response:
            return DEFAULT_DIARY_CONCLUSION

        cleaned_response = _clean_json_response(raw_response)
        parsed_data = json.loads(cleaned_response)

        conclusion = parsed_data.get("conclusion")

        if not isinstance(conclusion, str):
            return DEFAULT_DIARY_CONCLUSION

        conclusion = conclusion.strip()

        if not conclusion:
            return DEFAULT_DIARY_CONCLUSION

        sentences = [
            sentence.strip()
            for sentence in conclusion.replace("!", ".").replace("?", ".").split(".")
            if sentence.strip()
        ]

        if len(sentences) > 4:
            conclusion = ". ".join(sentences[:4]) + "."

        forbidden_markers = [
            "диагноз",
            "депрессия",
            "тревожное расстройство",
            "паническое расстройство",
            "птср",
            "биполяр",
            "лечение",
            "назначение",
            "медикамент",
            "препарат",
            "таблетк",
            "я психолог",
            "я терапевт",
        ]

        normalized_conclusion = conclusion.lower()

        if any(marker in normalized_conclusion for marker in forbidden_markers):
            return DEFAULT_DIARY_CONCLUSION

        return conclusion

    except json.JSONDecodeError:
        logger.warning("Invalid JSON from LLM while generating diary conclusion.")
        return DEFAULT_DIARY_CONCLUSION

    except Exception as error:
        logger.exception("Failed to generate diary conclusion: %s", error)
        return DEFAULT_DIARY_CONCLUSION
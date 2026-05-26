import logging
import os
from typing import Optional

from dotenv import load_dotenv


load_dotenv()

logger = logging.getLogger(__name__)

LLM_API_KEY = os.getenv("LLM_API_KEY")
LLM_MODEL = os.getenv("LLM_MODEL", "gemini-2.5-flash")


def _build_gemini_prompt(messages: list[dict]) -> str:
    prompt_parts = []

    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")

        prompt_parts.append(f"{role.upper()}:\n{content}")

    return "\n\n".join(prompt_parts)


def call_llm(messages: list[dict]) -> Optional[str]:
    """
    Безопасный вызов Gemini API.

    Если:
    - LLM_API_KEY отсутствует;
    - google-genai не установлен;
    - Gemini API недоступен;
    - произошла любая ошибка;

    функция возвращает None, а backend продолжает работать через fake fallback.
    """

    if not LLM_API_KEY:
        logger.info("LLM_API_KEY is not set. LLM call skipped.")
        return None

    try:
        from google import genai

        client = genai.Client(
            api_key=LLM_API_KEY,
        )

        prompt = _build_gemini_prompt(messages)

        response = client.models.generate_content(
            model=LLM_MODEL,
            contents=prompt,
        )

        if not response or not response.text:
            logger.warning("LLM returned empty response.")
            return None

        return response.text

    except ImportError as error:
        logger.exception(
            "google-genai package is not installed or cannot be imported: %s",
            error,
        )
        return None

    except Exception as error:
        logger.exception("LLM API call failed: %s", error)
        return None
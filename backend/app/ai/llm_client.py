import logging
import os
from typing import Optional

from dotenv import load_dotenv


load_dotenv()

logger = logging.getLogger(__name__)


LLM_PROVIDER_CHAIN = os.getenv("LLM_PROVIDER_CHAIN", "").strip()

OLD_LLM_API_KEY = os.getenv("LLM_API_KEY")
OLD_LLM_MODEL = os.getenv("LLM_MODEL", "gemini-2.5-flash")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or OLD_LLM_API_KEY
GEMINI_MODEL = os.getenv("GEMINI_MODEL") or OLD_LLM_MODEL

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")

def _get_provider_chain() -> list[str]:

    if LLM_PROVIDER_CHAIN:
        providers = [
            provider.strip().lower()
            for provider in LLM_PROVIDER_CHAIN.split(",")
            if provider.strip()
        ]

        if providers:
            return providers

    if GEMINI_API_KEY:
        return ["gemini"]

    return ["fake"]


def _build_gemini_prompt(messages: list[dict]) -> str:
    prompt_parts = []

    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")

        if content:
            prompt_parts.append(f"{role.upper()}:\n{content}")

    return "\n\n".join(prompt_parts)


def _is_quota_or_rate_limit_error(error: Exception) -> bool:
    error_text = str(error).lower()

    markers = [
        "429",
        "quota",
        "resource_exhausted",
        "rate limit",
        "rate_limit",
        "too many requests",
        "requests per day",
        "requests per minute",
        "tokens per minute",
    ]

    return any(marker in error_text for marker in markers)


def call_gemini(messages: list[dict]) -> Optional[str]:
    if not GEMINI_API_KEY:
        logger.info("GEMINI_API_KEY/LLM_API_KEY is not set. Gemini skipped.")
        return None

    try:
        from google import genai

        client = genai.Client(
            api_key=GEMINI_API_KEY,
        )

        prompt = _build_gemini_prompt(messages)

        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
        )

        if not response or not response.text:
            logger.warning("Gemini returned empty response.")
            return None

        logger.info("LLM provider used: gemini, model: %s", GEMINI_MODEL)

        return response.text

    except ImportError as error:
        logger.warning(
            "google-genai package is not installed or cannot be imported. Gemini skipped. Error: %s",
            error,
        )
        return None

    except Exception as error:
        if _is_quota_or_rate_limit_error(error):
            logger.warning("Gemini quota/rate limit reached. Trying next provider.")
        else:
            logger.warning("Gemini API call failed. Trying next provider. Error: %s", error)

        return None


def call_openai_compatible(
    provider_name: str,
    api_key: Optional[str],
    model: str,
    base_url: str,
    messages: list[dict],
) -> Optional[str]:
    if not api_key:
        logger.info("%s API key is not set. Provider skipped.", provider_name)
        return None

    try:
        from openai import OpenAI # type: ignore

        client = OpenAI(
            api_key=api_key,
            base_url=base_url,
        )

        response = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.3,
            max_tokens=900,
        )

        if not response.choices:
            logger.warning("%s returned empty choices.", provider_name)
            return None

        content = response.choices[0].message.content

        if not content:
            logger.warning("%s returned empty content.", provider_name)
            return None

        logger.info("LLM provider used: %s, model: %s", provider_name, model)

        return content

    except ImportError as error:
        logger.warning(
            "openai package is not installed. %s skipped. Error: %s",
            provider_name,
            error,
        )
        return None

    except Exception as error:
        if _is_quota_or_rate_limit_error(error):
            logger.warning("%s quota/rate limit reached. Trying next provider.", provider_name)
        else:
            logger.warning("%s API call failed. Trying next provider. Error: %s", provider_name, error)

        return None


def call_groq(messages: list[dict]) -> Optional[str]:
    return call_openai_compatible(
        provider_name="groq",
        api_key=GROQ_API_KEY,
        model=GROQ_MODEL,
        base_url="https://api.groq.com/openai/v1",
        messages=messages,
    )


def call_llm(messages: list[dict]) -> Optional[str]:

    providers = _get_provider_chain()

    for provider in providers:
        if provider == "fake":
            logger.info("LLM_PROVIDER_CHAIN contains fake. External LLM skipped.")
            return None

        if provider == "gemini":
            result = call_gemini(messages)

        elif provider == "groq":
            result = call_groq(messages)

        else:
            logger.warning(
                "Unknown LLM provider '%s'. Available: gemini, groq, openrouter, fake.",
                provider,
            )
            result = None

        if result:
            return result

    logger.warning("All LLM providers failed or exhausted. Using fake fallback.")

    return None
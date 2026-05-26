import json
from typing import Any, Optional, TypedDict

from pydantic import BaseModel, Field, ValidationError


# =========================
# Current assistant result for backend
# =========================

class CBTAssistantResult(TypedDict, total=False):
    assistant_reply: str
    should_advance: bool
    extracted_data: dict[str, Any]
    used_technique: str
    current_phase: str
    should_finish: bool
    diary_readiness_score: int
    assistant_alternative_thought: Optional[str]
    final_alternative_thought: Optional[str]


# =========================
# Future LLM JSON contract
# =========================

class LLMSessionUpdate(BaseModel):
    situation: Optional[str] = None
    automatic_thought: Optional[str] = None
    emotions_before: Optional[dict] = None

    thoughts: list[str] = Field(default_factory=list)
    emotions: list[dict] = Field(default_factory=list)
    reactions: list[str] = Field(default_factory=list)
    body_sensations: list[str] = Field(default_factory=list)
    cognitive_distortions: list[dict] = Field(default_factory=list)

    evidence_for: Optional[str] = None
    evidence_against: Optional[str] = None

    user_alternative_thought: Optional[str] = None
    assistant_alternative_thought: Optional[str] = None
    final_alternative_thought: Optional[str] = None

    emotions_after: Optional[dict] = None
    summary: Optional[str] = None


class LLMAssistantResult(BaseModel):
    assistant_reply: str
    current_phase: str
    used_technique: str
    should_advance: bool
    should_finish: bool
    diary_readiness_score: int = Field(ge=0, le=100)
    session_update: LLMSessionUpdate


def get_fallback_llm_result() -> LLMAssistantResult:
    return LLMAssistantResult(
        assistant_reply=(
            "Я рядом. Давай продолжим разбирать ситуацию спокойно и по шагам."
        ),
        current_phase="SITUATION_ANALYSIS",
        used_technique="NONE",
        should_advance=False,
        should_finish=False,
        diary_readiness_score=0,
        session_update=LLMSessionUpdate(),
    )


def parse_llm_json_response(raw_response: str) -> LLMAssistantResult:
    """
    Пытается распарсить сырой ответ LLM как JSON.

    Если LLM вернул:
    - не JSON;
    - markdown;
    - неполный JSON;
    - JSON не по контракту;

    возвращается безопасный fallback.
    """

    if not raw_response:
        return get_fallback_llm_result()

    cleaned_response = raw_response.strip()

    if cleaned_response.startswith("```json"):
        cleaned_response = cleaned_response.replace("```json", "", 1).strip()

    if cleaned_response.startswith("```"):
        cleaned_response = cleaned_response.replace("```", "", 1).strip()

    if cleaned_response.endswith("```"):
        cleaned_response = cleaned_response[:-3].strip()

    try:
        parsed_data = json.loads(cleaned_response)
        return LLMAssistantResult.model_validate(parsed_data)

    except json.JSONDecodeError:
        return get_fallback_llm_result()

    except ValidationError:
        return get_fallback_llm_result()

    except Exception:
        return get_fallback_llm_result()
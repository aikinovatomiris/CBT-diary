import pytest

from app.routers.cbt import (
    extract_wellbeing_score,
    get_next_step,
    get_phase_for_step,
    has_emotion_intensity,
)


@pytest.mark.parametrize(
    ("current_step", "expected_step"),
    [
        ("SITUATION", "AUTOMATIC_THOUGHT"),
        ("EMOTIONS", "EVIDENCE_FOR"),
        ("RESULT", "FINISHED"),
        ("FINISHED", "FINISHED"),
        ("UNKNOWN_STEP", "SITUATION"),
    ],
)
def test_get_next_step_follows_cbt_scenario(current_step, expected_step):
    assert get_next_step(current_step) == expected_step


def test_get_phase_for_step_returns_expected_phase():
    assert get_phase_for_step("EMOTIONS") == "EMOTION_ASSESSMENT"
    assert get_phase_for_step("UNKNOWN_STEP") == "SITUATION_ANALYSIS"


@pytest.mark.parametrize(
    ("message", "expected_score"),
    [
        ("70", 70),
        ("Сейчас моё состояние примерно 100", 100),
        ("Сегодня было 20, а сейчас 70", None),
        ("Не могу выбрать число", None),
        ("Оценка 101", None),
    ],
)
def test_extract_wellbeing_score_requires_one_valid_value(
    message,
    expected_score,
):
    assert extract_wellbeing_score(message) == expected_score


@pytest.mark.parametrize(
    ("message", "expected"),
    [
        ("Тревога 85", True),
        ("Спокойствие 0", True),
        ("Очень тревожно", False),
        ("Интенсивность 101", False),
    ],
)
def test_has_emotion_intensity_checks_zero_to_one_hundred(
    message,
    expected,
):
    assert has_emotion_intensity(message) is expected

import pytest
from pydantic import ValidationError

from app.schemas import CBTMessageCreate, TherapistRatingRequest, UserCreate


def test_cbt_message_accepts_non_empty_content():
    message = CBTMessageCreate(content="Мне тревожно перед встречей")

    assert message.content == "Мне тревожно перед встречей"


def test_cbt_message_rejects_empty_content():
    with pytest.raises(ValidationError):
        CBTMessageCreate(content="")


def test_user_registration_validates_email_and_password_length():
    user = UserCreate(
        email="user@example.com",
        password="secure-password",
        name="Тестовый пользователь",
    )

    assert user.email == "user@example.com"

    with pytest.raises(ValidationError):
        UserCreate(
            email="not-an-email",
            password="123",
            name="Пользователь",
        )


@pytest.mark.parametrize("rating", [1, 3, 5])
def test_therapist_rating_accepts_values_from_one_to_five(rating):
    assert TherapistRatingRequest(rating=rating).rating == rating


@pytest.mark.parametrize("rating", [0, 6])
def test_therapist_rating_rejects_values_outside_range(rating):
    with pytest.raises(ValidationError):
        TherapistRatingRequest(rating=rating)

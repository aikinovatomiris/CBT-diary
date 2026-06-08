from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=False)

    role = Column(String, default="user", nullable=False)
    auth_provider = Column(String, default="local", nullable=False)

    assistant_style = Column(String, default="supportive", nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    sessions = relationship(
        "CBTSession",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    diary_entries = relationship(
        "DiaryEntry",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    therapist_profile = relationship(
        "TherapistProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )

    user_conversations = relationship(
        "Conversation",
        foreign_keys="Conversation.user_id",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    therapist_conversations = relationship(
        "Conversation",
        foreign_keys="Conversation.therapist_user_id",
        back_populates="therapist",
        cascade="all, delete-orphan",
    )

    sent_conversation_messages = relationship(
        "ConversationMessage",
        foreign_keys="ConversationMessage.sender_id",
        back_populates="sender",
    )


class TherapistProfile(Base):
    __tablename__ = "therapist_profiles"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)

    full_name = Column(String, nullable=False)
    qualification = Column(String, nullable=False)

    therapy_approaches = Column(Text, nullable=True)
    specializations = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    price = Column(Text, nullable=True)

    contacts = Column(JSON, nullable=True)

    city = Column(Text, nullable=True)
    online_available = Column(Boolean, default=True, nullable=False)

    photo_path = Column(Text, nullable=True)

    status = Column(String, default="draft", nullable=False)
    rejection_reason = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    user = relationship(
        "User",
        back_populates="therapist_profile",
    )

    certificates = relationship(
        "TherapistCertificate",
        back_populates="therapist_profile",
        cascade="all, delete-orphan",
    )

    @property
    def photo_url(self) -> str | None:
        if not self.photo_path:
            return None

        normalized_path = self.photo_path.replace("\\", "/")

        if normalized_path.startswith("/"):
            return normalized_path

        return f"/{normalized_path}"


class TherapistCertificate(Base):
    __tablename__ = "therapist_certificates"

    id = Column(Integer, primary_key=True, index=True)

    therapist_profile_id = Column(
        Integer,
        ForeignKey("therapist_profiles.id"),
        nullable=False,
    )

    file_path = Column(Text, nullable=False)
    original_filename = Column(String, nullable=False)

    uploaded_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    therapist_profile = relationship(
        "TherapistProfile",
        back_populates="certificates",
    )


class CBTSession(Base):
    __tablename__ = "cbt_sessions"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    status = Column(String, default="active", nullable=False)

    current_step = Column(String, default="SITUATION", nullable=False)
    current_phase = Column(String, default="SITUATION_ANALYSIS", nullable=False)

    situation = Column(Text, nullable=True)
    automatic_thought = Column(Text, nullable=True)
    emotions_before = Column(JSON, nullable=True)

    evidence_for = Column(Text, nullable=True)
    evidence_against = Column(Text, nullable=True)

    user_alternative_thought = Column(Text, nullable=True)
    assistant_alternative_thought = Column(Text, nullable=True)
    final_alternative_thought = Column(Text, nullable=True)

    emotions_after = Column(JSON, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    finished_at = Column(DateTime, nullable=True)

    user = relationship(
        "User",
        back_populates="sessions",
    )

    messages = relationship(
        "CBTMessage",
        back_populates="session",
        cascade="all, delete-orphan",
    )

    diary_entry = relationship(
        "DiaryEntry",
        back_populates="session",
        uselist=False,
        cascade="all, delete-orphan",
    )


class CBTMessage(Base):
    __tablename__ = "cbt_messages"

    id = Column(Integer, primary_key=True, index=True)

    session_id = Column(Integer, ForeignKey("cbt_sessions.id"), nullable=False)

    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)

    used_technique = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    session = relationship(
        "CBTSession",
        back_populates="messages",
    )


class DiaryEntry(Base):
    __tablename__ = "diary_entries"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(Integer, ForeignKey("cbt_sessions.id"), unique=True, nullable=False)

    situation = Column(Text, nullable=False)
    automatic_thought = Column(Text, nullable=False)

    emotions_before = Column(JSON, nullable=True)
    emotions_after = Column(JSON, nullable=True)
    cognitive_distortions = Column(JSON, nullable=True)

    evidence_for = Column(Text, nullable=True)
    evidence_against = Column(Text, nullable=True)
    alternative_thought = Column(Text, nullable=True)
    conclusion = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship(
        "User",
        back_populates="diary_entries",
    )

    session = relationship(
        "CBTSession",
        back_populates="diary_entry",
    )

    shared_in_conversation_messages = relationship(
        "ConversationMessage",
        back_populates="shared_diary_entry",
    )


class Conversation(Base):
    __tablename__ = "conversations"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "therapist_user_id",
            name="uq_user_therapist_conversation",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    therapist_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship(
        "User",
        foreign_keys=[user_id],
        back_populates="user_conversations",
    )

    therapist = relationship(
        "User",
        foreign_keys=[therapist_user_id],
        back_populates="therapist_conversations",
    )

    messages = relationship(
        "ConversationMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
    )
    
    @property
    def user_name(self) -> str | None:
        if self.user:
            return self.user.name
        return None

    @property
    def therapist_name(self) -> str | None:
        if self.therapist:
            return self.therapist.name
        return None


class ConversationMessage(Base):
    __tablename__ = "conversation_messages"

    id = Column(Integer, primary_key=True, index=True)

    conversation_id = Column(
        Integer,
        ForeignKey("conversations.id"),
        nullable=False,
    )

    sender_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    content = Column(Text, nullable=False)

    shared_diary_entry_id = Column(
        Integer,
        ForeignKey("diary_entries.id"),
        nullable=True,
    )

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    conversation = relationship(
        "Conversation",
        back_populates="messages",
    )

    sender = relationship(
        "User",
        foreign_keys=[sender_id],
        back_populates="sent_conversation_messages",
    )

    shared_diary_entry = relationship(
        "DiaryEntry",
        back_populates="shared_in_conversation_messages",
    )
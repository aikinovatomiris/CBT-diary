from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


AssistantStyle = Literal[
    "supportive",
    "friendly",
    "structured",
    "concise",
]

UserRole = Literal[
    "user",
    "therapist",
    "admin",
]

TherapistProfileStatus = Literal[
    "draft",
    "pending",
    "approved",
    "rejected",
]


# =========================
# Auth / User schemas
# =========================

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    name: str = Field(min_length=1, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    
    
class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=10)


class TherapistRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    name: str = Field(min_length=1, max_length=100)
    full_name: str = Field(min_length=1, max_length=255)
    qualification: str = Field(min_length=1, max_length=255)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    name: str
    role: str
    assistant_style: Optional[str] = None
    auth_provider: str = "local"
    created_at: datetime


class TherapistRegisterResponse(BaseModel):
    user: UserResponse
    therapist_profile_id: int


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AssistantStyleUpdate(BaseModel):
    assistant_style: AssistantStyle


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(min_length=6, max_length=72)
    new_password: str = Field(min_length=6, max_length=72)


class ChangePasswordResponse(BaseModel):
    message: str

class UpdateUserNameRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)

# =========================
# Therapist profile schemas
# =========================

class TherapistContacts(BaseModel):
    phone: Optional[str] = None
    whatsapp: Optional[str] = None
    telegram: Optional[str] = None
    instagram: Optional[str] = None
    email: Optional[str] = None

class TherapistProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int

    full_name: str
    qualification: str

    therapy_approaches: Optional[str] = None
    specializations: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None

    contacts: Optional[TherapistContacts] = None
    city: Optional[str] = None
    online_available: bool

    photo_url: Optional[str] = None

    status: str
    rejection_reason: Optional[str] = None

    created_at: datetime
    updated_at: datetime


class TherapistProfileUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    qualification: Optional[str] = Field(default=None, min_length=1, max_length=255)

    therapy_approaches: Optional[str] = None
    specializations: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None

    contacts: Optional[TherapistContacts] = None
    city: Optional[str] = None
    online_available: Optional[bool] = None


class TherapistProfileSubmitResponse(BaseModel):
    message: str
    status: str
    therapist_profile_id: int


class TherapistCertificateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    therapist_profile_id: int
    file_path: str
    original_filename: str
    uploaded_at: datetime


class PublicTherapistProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    full_name: str
    qualification: str

    therapy_approaches: Optional[str] = None
    specializations: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None

    contacts: Optional[TherapistContacts] = None
    city: Optional[str] = None
    online_available: bool

    photo_url: Optional[str] = None

    created_at: datetime


# =========================
# Admin schemas
# =========================

class AdminTherapistCertificateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    original_filename: str
    file_path: str
    uploaded_at: datetime


class AdminTherapistProfileListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int

    full_name: str
    qualification: str

    therapy_approaches: Optional[str] = None
    specializations: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None

    contacts: Optional[TherapistContacts] = None
    city: Optional[str] = None
    online_available: bool
    
    photo_url: Optional[str] = None

    status: str
    rejection_reason: Optional[str] = None

    created_at: datetime
    updated_at: datetime


class AdminTherapistProfileDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int

    full_name: str
    qualification: str

    therapy_approaches: Optional[str] = None
    specializations: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None

    contacts: Optional[TherapistContacts] = None

    city: Optional[str] = None
    online_available: bool
    
    photo_url: Optional[str] = None

    status: str
    rejection_reason: Optional[str] = None

    created_at: datetime
    updated_at: datetime

    certificates: list[AdminTherapistCertificateResponse] = []


class AdminRejectTherapistRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=1000)


class AdminSummaryResponse(BaseModel):
    total_users: int
    total_therapists: int
    pending_therapists: int
    approved_therapists: int
    rejected_therapists: int
    total_diary_entries: int
    total_cbt_sessions: int


# =========================
# CBT schemas
# =========================

class CBTSessionCreate(BaseModel):
    pass


class CBTSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    status: str

    current_step: str
    current_phase: str

    situation: Optional[str] = None
    automatic_thought: Optional[str] = None
    emotions_before: Optional[Any] = None

    evidence_for: Optional[str] = None
    evidence_against: Optional[str] = None

    user_alternative_thought: Optional[str] = None
    assistant_alternative_thought: Optional[str] = None
    final_alternative_thought: Optional[str] = None

    emotions_after: Optional[Any] = None

    created_at: datetime
    finished_at: Optional[datetime] = None


class CBTMessageCreate(BaseModel):
    content: str = Field(min_length=1)


class CBTMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    session_id: int
    role: str
    content: str
    used_technique: Optional[str] = None
    created_at: datetime


class CBTMessageSendResponse(BaseModel):
    user_message: CBTMessageResponse
    assistant_message: CBTMessageResponse
    current_step: str
    current_phase: str
    session_status: str


# =========================
# Diary schemas
# =========================

class DiaryEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    session_id: int

    situation: str
    automatic_thought: str

    emotions_before: Optional[Any] = None
    emotions_after: Optional[Any] = None
    cognitive_distortions: Optional[Any] = None

    evidence_for: Optional[str] = None
    evidence_against: Optional[str] = None
    alternative_thought: Optional[str] = None
    conclusion: Optional[str] = None

    created_at: datetime


class DeleteDiaryEntryResponse(BaseModel):
    message: str
    deleted_entry_id: int


# =========================
# Analytics schemas
# =========================

class AnalyticsSummaryResponse(BaseModel):
    total_sessions: int
    finished_sessions: int
    total_diary_entries: int
    latest_entry_date: Optional[datetime] = None


class AnalyticsDistortionItem(BaseModel):
    name: str
    count: int


class AnalyticsDistortionsResponse(BaseModel):
    items: list[AnalyticsDistortionItem]


class AnalyticsTechniqueItem(BaseModel):
    technique: str
    count: int


class AnalyticsTechniquesResponse(BaseModel):
    items: list[AnalyticsTechniqueItem]
    
# =========================
# Conversation schemas
# =========================

class ConversationCreate(BaseModel):
    therapist_user_id: int


class ConversationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    therapist_user_id: int
    created_at: datetime

    user_name: Optional[str] = None
    therapist_name: Optional[str] = None

class ConversationMessageCreate(BaseModel):
    content: str = Field(min_length=1)


class ConversationMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    conversation_id: int
    sender_id: int
    content: str
    shared_diary_entry_id: Optional[int] = None
    created_at: datetime


class ShareDiaryEntryRequest(BaseModel):
    diary_entry_id: int
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app import models
from app.database import (
    Base,
    check_database_connection,
    engine,
)
from app.routers import (
    admin,
    analytics,
    auth,
    cbt,
    conversations,
    diary,
    guest,
    notifications,
    profile,
    therapist,
    therapists,
)


app = FastAPI(
    title="CBT Diary Backend",
    description=(
        "Backend для мобильного приложения "
        "КПТ-дневника с ИИ-помощником"
    ),
    version="1.0.0",
)


Base.metadata.create_all(
    bind=engine
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


uploads_dir = Path("uploads")
uploads_dir.mkdir(
    parents=True,
    exist_ok=True,
)

app.mount(
    "/uploads",
    StaticFiles(
        directory="uploads"
    ),
    name="uploads",
)


app.include_router(auth.router)
app.include_router(cbt.router)
app.include_router(diary.router)
app.include_router(analytics.router)
app.include_router(profile.router)
app.include_router(therapist.router)
app.include_router(therapists.router)
app.include_router(admin.router)
app.include_router(guest.router)
app.include_router(conversations.router)
app.include_router(notifications.router)


@app.get("/")
def root():
    return {
        "message": (
            "CBT Diary Backend is running"
        )
    }


@app.get("/health")
def health_check():
    return {
        "status": "ok"
    }


@app.get("/db-check")
def db_check():
    is_connected = (
        check_database_connection()
    )

    if is_connected:
        return {
            "status": "ok",
            "database": "connected",
        }

    return {
        "status": "error",
        "database": "not connected",
    }
import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault(
    "JWT_SECRET_KEY",
    "unit-tests-only-secret-key-that-is-not-used-in-production",
)
os.environ.setdefault("JWT_ALGORITHM", "HS256")

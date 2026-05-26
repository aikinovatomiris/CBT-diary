import os

from dotenv import load_dotenv

from app.database import SessionLocal
from app.models import User
from app.security import hash_password


load_dotenv()


def create_or_update_admin():
    admin_email = os.getenv("ADMIN_EMAIL")
    admin_password = os.getenv("ADMIN_PASSWORD")
    admin_name = os.getenv("ADMIN_NAME", "Admin")

    if not admin_email:
        raise ValueError("ADMIN_EMAIL is not set in .env file")

    if not admin_password:
        raise ValueError("ADMIN_PASSWORD is not set in .env file")

    db = SessionLocal()

    try:
        existing_user = (
            db.query(User)
            .filter(User.email == admin_email)
            .first()
        )

        if existing_user:
            existing_user.role = "admin"
            existing_user.name = admin_name
            existing_user.hashed_password = hash_password(admin_password)

            # admin не использует ИИ-ассистента, поэтому можно оставить None
            existing_user.assistant_style = None

            db.commit()
            db.refresh(existing_user)

            print("Admin user updated successfully")
            print(f"Email: {existing_user.email}")
            print(f"Role: {existing_user.role}")
            print(f"User ID: {existing_user.id}")

            return

        admin_user = User(
            email=admin_email,
            hashed_password=hash_password(admin_password),
            name=admin_name,
            role="admin",
            assistant_style=None,
        )

        db.add(admin_user)
        db.commit()
        db.refresh(admin_user)

        print("Admin user created successfully")
        print(f"Email: {admin_user.email}")
        print(f"Role: {admin_user.role}")
        print(f"User ID: {admin_user.id}")

    finally:
        db.close()


if __name__ == "__main__":
    create_or_update_admin()
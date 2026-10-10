"""Reset an existing account password locally: python -m scripts.reset_password."""
from getpass import getpass

from pydantic import ValidationError
from sqlalchemy import select

from app.database import SessionLocal
from app.models import User
from app.schemas import UserUpdate
from app.security import hash_password


def main():
    email = input("Account email: ").strip().lower()
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            raise SystemExit("Account not found. No changes made.")
        password = getpass("New password: ")
        confirmation = getpass("Confirm new password: ")
        if password != confirmation:
            raise SystemExit("Passwords do not match. No changes made.")
        try:
            UserUpdate(password=password)
        except ValidationError as error:
            messages = "; ".join(item["msg"] for item in error.errors(include_input=False))
            raise SystemExit(messages) from None
        user.password_hash = hash_password(password)
        db.commit()
    print("Password reset. You can now sign in with your new password.")


if __name__ == "__main__":
    main()
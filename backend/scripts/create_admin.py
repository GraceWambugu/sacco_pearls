"""Create (or promote) an admin account.
Run from the backend folder:
    python -m scripts.create_admin you@example.com "YourPassword1" "Your Name"
"""
import argparse

from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models import User
from app.security import hash_password


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("email")
    ap.add_argument("password")
    ap.add_argument("full_name", nargs="?", default="Administrator")
    a = ap.parse_args()

    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == a.email.lower()))
        if user:
            user.role = "admin"
            print(f"Promoted existing user {user.email} to admin")
        else:
            db.add(User(email=a.email.lower(), password_hash=hash_password(a.password),
                        full_name=a.full_name, role="admin"))
            print(f"Created admin {a.email.lower()}")
        db.commit()


if __name__ == "__main__":
    main()

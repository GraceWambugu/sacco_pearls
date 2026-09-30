"""Run with:  cd backend  then  pytest -v
Uses an in-memory SQLite database, so PostgreSQL is not needed for the tests."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import User
from app.utils import normalize_name

PW = "Str0ngPass1"


@pytest.fixture()
def client():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override
    c = TestClient(app)
    c.Session = Session
    yield c
    app.dependency_overrides.clear()


def register(client, email, pw=PW, name="Test User"):
    return client.post("/auth/register", json={"email": email, "password": pw, "full_name": name})


def login(client, email, pw=PW):
    return client.post("/auth/login", data={"username": email, "password": pw})


def auth_headers(client, email, pw=PW):
    register(client, email, pw)
    token = login(client, email, pw).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def admin_headers(client, email="admin@example.com"):
    h = auth_headers(client, email)
    with client.Session() as s:
        u = s.scalar(select(User).where(User.email == email))
        u.role = "admin"
        s.commit()
    return h


# ---------- hashing / auth ----------
def test_password_is_hashed_and_salted(client):
    register(client, "a@example.com")
    register(client, "b@example.com")  # same password on purpose
    with client.Session() as s:
        a = s.scalar(select(User).where(User.email == "a@example.com"))
        b = s.scalar(select(User).where(User.email == "b@example.com"))
        assert a.password_hash != PW
        assert a.password_hash.startswith("$argon2id$")
        assert a.password_hash != b.password_hash  # different salt each time


def test_register_response_never_contains_password(client):
    r = register(client, "a@example.com")
    assert r.status_code == 201
    assert "password" not in r.text.lower()


def test_duplicate_email_rejected(client):
    register(client, "a@example.com")
    assert register(client, "A@example.com").status_code == 409


def test_weak_password_rejected(client):
    assert register(client, "a@example.com", pw="short1").status_code == 422
    assert register(client, "b@example.com", pw="onlyletters").status_code == 422


def test_login_wrong_password_and_unknown_email_same_message(client):
    register(client, "a@example.com")
    r1 = login(client, "a@example.com", "WrongPass9")
    r2 = login(client, "nobody@example.com", "WrongPass9")
    assert r1.status_code == r2.status_code == 401
    assert r1.json() == r2.json()


def test_protected_route_needs_token(client):
    assert client.get("/users/me").status_code == 401
    assert client.get("/users/me", headers={"Authorization": "Bearer garbage"}).status_code == 401


def test_cannot_self_register_as_admin(client):
    r = client.post("/auth/register", json={"email": "x@example.com", "password": PW,
                                            "full_name": "X", "role": "admin"})
    assert r.json()["role"] == "member"


# ---------- users CRUD ----------
def test_user_read_update_delete(client):
    h = auth_headers(client, "a@example.com")
    assert client.get("/users/me", headers=h).json()["email"] == "a@example.com"
    r = client.put("/users/me", json={"full_name": "New Name", "password": "N3wPassword"}, headers=h)
    assert r.json()["full_name"] == "New Name"
    assert login(client, "a@example.com", "N3wPassword").status_code == 200
    assert login(client, "a@example.com", PW).status_code == 401
    assert client.delete("/users/me", headers=h).status_code == 204
    assert login(client, "a@example.com", "N3wPassword").status_code == 401


# ---------- SACCO CRUD + roles ----------
def test_member_cannot_write_saccos_but_anyone_can_read(client):
    member = auth_headers(client, "m@example.com")
    assert client.post("/saccos", json={"name": "STIMA DT."}, headers=member).status_code == 403
    assert client.post("/saccos", json={"name": "STIMA DT."}).status_code == 401
    assert client.get("/saccos").status_code == 200


def test_admin_sacco_crud(client):
    h = admin_headers(client)
    r = client.post("/saccos", json={"name": "STIMA DT.", "county": "Nairobi"}, headers=h)
    assert r.status_code == 201
    sid = r.json()["id"]
    assert client.post("/saccos", json={"name": "STIMA DT."}, headers=h).status_code == 409
    assert client.get(f"/saccos/{sid}").json()["county"] == "Nairobi"
    assert client.get("/saccos", params={"q": "stim"}).json()[0]["name"] == "STIMA DT."
    assert client.put(f"/saccos/{sid}", json={"county": "Kiambu"}, headers=h).json()["county"] == "Kiambu"
    assert client.delete(f"/saccos/{sid}", headers=h).status_code == 204
    assert client.get(f"/saccos/{sid}").status_code == 404


# ---------- metrics CRUD ----------
def test_metrics_crud_and_duplicate_year(client):
    h = admin_headers(client)
    sid = client.post("/saccos", json={"name": "TOWER"}, headers=h).json()["id"]
    body = {"data_year": 2024, "cca": 15.15, "npl_ratio": 4.24}
    r = client.post(f"/saccos/{sid}/metrics", json=body, headers=h)
    assert r.status_code == 201
    mid = r.json()["id"]
    assert client.post(f"/saccos/{sid}/metrics", json=body, headers=h).status_code == 409
    client.post(f"/saccos/{sid}/metrics", json={"data_year": 2023, "cca": 15.79}, headers=h)
    years = [m["data_year"] for m in client.get(f"/saccos/{sid}/metrics").json()]
    assert years == [2023, 2024]  # trend order
    assert client.put(f"/metrics/{mid}", json={"cca": 16.0}, headers=h).json()["cca"] == 16.0
    assert client.post(f"/saccos/{sid}/metrics", json={"data_year": 2022, "npl_ratio": -1},
                       headers=h).status_code == 422
    assert client.delete(f"/metrics/{mid}", headers=h).status_code == 204


def test_deleting_sacco_removes_its_metrics(client):
    h = admin_headers(client)
    sid = client.post("/saccos", json={"name": "TOWER"}, headers=h).json()["id"]
    client.post(f"/saccos/{sid}/metrics", json={"data_year": 2024}, headers=h)
    client.delete(f"/saccos/{sid}", headers=h)
    from app.models import FinancialMetric
    with client.Session() as s:
        assert s.scalars(select(FinancialMetric)).all() == []


# ---------- watchlists ----------
def _make_saccos(client, n):
    h = admin_headers(client, "boss@example.com")
    return [client.post("/saccos", json={"name": f"SACCO {i}"}, headers=h).json()["id"] for i in range(n)]


def test_watchlist_crud_and_limit_of_three(client):
    ids = _make_saccos(client, 4)
    h = auth_headers(client, "m@example.com")
    r = client.post("/watchlists", json={"name": "My picks", "sacco_ids": ids[:2]}, headers=h)
    assert r.status_code == 201 and len(r.json()["saccos"]) == 2
    wid = r.json()["id"]
    assert client.post("/watchlists", json={"name": "Too many", "sacco_ids": ids}, headers=h).status_code == 422
    assert client.post("/watchlists", json={"name": "My picks"}, headers=h).status_code == 409
    r = client.put(f"/watchlists/{wid}", json={"name": "Renamed", "sacco_ids": [ids[3]]}, headers=h)
    assert r.json()["name"] == "Renamed" and r.json()["saccos"][0]["id"] == ids[3]
    assert client.post("/watchlists", json={"name": "Bad", "sacco_ids": [9999]}, headers=h).status_code == 404
    assert client.delete(f"/watchlists/{wid}", headers=h).status_code == 204
    assert client.get("/watchlists", headers=h).json() == []


def test_user_cannot_see_someone_elses_watchlist(client):
    a = auth_headers(client, "a@example.com")
    b = auth_headers(client, "b@example.com")
    wid = client.post("/watchlists", json={"name": "Private"}, headers=a).json()["id"]
    assert client.get(f"/watchlists/{wid}", headers=b).status_code == 404
    assert client.delete(f"/watchlists/{wid}", headers=b).status_code == 404
    assert client.get(f"/watchlists/{wid}", headers=a).status_code == 200


# ---------- name matching ----------
def test_normalize_name_matches_report_spellings():
    assert normalize_name("STIMA DT.") == normalize_name("STIMA DT") == normalize_name("Stima DT-SACCO")
    assert normalize_name("INVEST & GROW (IG)") == normalize_name("INVEST AND GROW (IG)")
    assert normalize_name("THE KENYA BANKERS") == "KENYA BANKERS"

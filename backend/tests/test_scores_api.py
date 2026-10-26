"""API tests for /saccos/{id}/score and /compare.

Run:  pytest tests/test_scores_api.py -v
Uses an in-memory SQLite database, like the other API tests, so PostgreSQL is not needed.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import FinancialMetric, Sacco


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


def seed(client):
    """ALPHA: healthy, growing. BETA: weak capital, shrinking, very high NPL. GAMMA: only has 2023 data."""
    with client.Session() as s:
        alpha = Sacco(name="ALPHA", county="Nairobi")
        beta = Sacco(name="BETA")
        gamma = Sacco(name="GAMMA")
        s.add_all([alpha, beta, gamma])
        s.flush()
        healthy = dict(cca=15, ccd=20, ica=12, ext_borrowing=2, npl_ratio=3)
        weak = dict(cca=5, ccd=5, ica=4, ext_borrowing=30, npl_ratio=40)
        s.add_all([
            FinancialMetric(sacco_id=alpha.id, data_year=2023, total_assets=10, total_deposits=7,
                            gross_loans=6, total_income=1.2, **healthy),
            FinancialMetric(sacco_id=alpha.id, data_year=2024, total_assets=11, total_deposits=7.7,
                            gross_loans=6.6, total_income=1.5, **healthy),
            FinancialMetric(sacco_id=beta.id, data_year=2023, total_assets=10, total_deposits=7,
                            gross_loans=6, total_income=0.3, **weak),
            FinancialMetric(sacco_id=beta.id, data_year=2024, total_assets=9, total_deposits=6,
                            gross_loans=5, total_income=0.2, **weak),
            FinancialMetric(sacco_id=gamma.id, data_year=2023, total_assets=5, total_deposits=3,
                            gross_loans=2, total_income=0.5, **healthy),
        ])
        s.commit()
        return alpha.id, beta.id, gamma.id


def test_score_is_public_and_has_the_expected_shape(client):
    alpha, _, _ = seed(client)
    r = client.get(f"/saccos/{alpha}/score", params={"year": 2024})   # no login needed
    assert r.status_code == 200
    body = r.json()
    assert body["sacco"]["name"] == "ALPHA"
    assert body["year"] == 2024 and body["rating"] == "Green" and body["composite"] == 100.0
    assert body["dimensions_scored"] == 4 and body["dimensions_total"] == 6
    assert list(body["dimensions"]) == ["P", "E", "A", "R", "L", "S"]
    assert body["dimensions"]["P"]["scored"] is False


def test_score_defaults_to_the_latest_year(client):
    alpha, _, _ = seed(client)
    assert client.get(f"/saccos/{alpha}/score").json()["year"] == 2024


def test_score_without_prior_year_scores_three_dimensions(client):
    alpha, _, _ = seed(client)
    body = client.get(f"/saccos/{alpha}/score", params={"year": 2023}).json()
    assert body["dimensions_scored"] == 3 and "limited" in body["flags"]


def test_weak_sacco_is_red(client):
    _, beta, _ = seed(client)
    body = client.get(f"/saccos/{beta}/score", params={"year": 2024}).json()
    assert body["rating"] == "Red" and body["composite"] < 50
    assert body["dimensions"]["E"]["score"] == 0.0     # every capital ratio breaches its limit


def test_score_not_found_cases(client):
    alpha, _, _ = seed(client)
    assert client.get("/saccos/9999/score").status_code == 404                      # unknown SACCO
    assert client.get(f"/saccos/{alpha}/score", params={"year": 2019}).status_code == 404   # no data that year


def test_compare_two_saccos_ranks_the_healthier_first(client):
    alpha, beta, _ = seed(client)
    r = client.get("/compare", params={"ids": f"{beta},{alpha}", "year": 2024})
    assert r.status_code == 200
    body = r.json()
    assert body["year"] == 2024
    assert [x["sacco"]["name"] for x in body["results"]] == ["BETA", "ALPHA"]   # order as requested
    assert body["ranking"] == [alpha, beta]                                       # best first


def test_compare_defaults_to_the_latest_common_year(client):
    alpha, _, gamma = seed(client)     # GAMMA only has 2023
    assert client.get("/compare", params={"ids": f"{alpha},{gamma}"}).json()["year"] == 2023


def test_compare_validation(client):
    alpha, beta, gamma = seed(client)
    assert client.get("/compare", params={"ids": str(alpha)}).status_code == 422             # only one
    assert client.get("/compare", params={"ids": f"{alpha},{alpha}"}).status_code == 422     # duplicates collapse to one
    assert client.get("/compare", params={"ids": "1,2,3,4"}).status_code == 422              # too many
    assert client.get("/compare", params={"ids": "a,b"}).status_code == 422                  # not numbers
    assert client.get("/compare", params={"ids": f"{alpha},9999"}).status_code == 404        # unknown SACCO
    assert client.get("/compare", params={"ids": f"{alpha},{beta}", "year": 2019}).status_code == 404


def test_rankings_lists_best_first_for_the_latest_year(client):
    alpha, beta, _ = seed(client)      # GAMMA has no 2024 figures, so it is not ranked
    r = client.get("/rankings")        # public, no login
    assert r.status_code == 200
    body = r.json()
    assert [x["sacco"]["id"] for x in body] == [alpha, beta]
    assert body[0] == {"sacco": {"id": alpha, "name": "ALPHA", "county": "Nairobi"},
                       "composite": 100.0, "rating": "Green", "dimensions_scored": 4,
                       "total_assets": 11, "npl_ratio": 3, "cca": 15}


def test_rankings_respects_year_and_limit(client):
    alpha, _, gamma = seed(client)
    body = client.get("/rankings", params={"year": 2023, "limit": 2}).json()
    assert len(body) == 2
    assert {x["sacco"]["id"] for x in body} == {alpha, gamma}     # the two healthy SACCOs
    assert client.get("/rankings", params={"limit": 0}).status_code == 422
    assert client.get("/rankings", params={"limit": 200}).status_code == 200    # whole directory
    assert client.get("/rankings", params={"limit": 201}).status_code == 422
    assert client.get("/rankings", params={"year": 2019}).status_code == 404


def test_rankings_skip_unrated_and_archived_saccos(client):
    alpha, beta, _ = seed(client)
    with client.Session() as s:
        empty = Sacco(name="EMPTY")                  # a row with no figures cannot be rated
        s.add(empty)
        s.flush()
        s.add(FinancialMetric(sacco_id=empty.id, data_year=2024))
        s.get(Sacco, beta).is_archived = True
        s.commit()
    assert [x["sacco"]["id"] for x in client.get("/rankings").json()] == [alpha]


def test_trend_is_oldest_first_and_matches_the_score_endpoint(client):
    alpha, _, _ = seed(client)
    body = client.get(f"/saccos/{alpha}/trend").json()
    assert [p["year"] for p in body] == [2023, 2024]
    assert body[0]["dimension_scores"]["S"] is None             # 2023 has no prior year to grow from
    assert body[1]["dimension_scores"] == {"E": 100.0, "A": 100.0, "R": 100.0, "S": 100.0}
    assert body[1]["total_assets"] == 11 and body[1]["npl_ratio"] == 3
    for point in body:                                          # same answer as the Profile screen
        score = client.get(f"/saccos/{alpha}/score", params={"year": point["year"]}).json()
        assert (point["composite"], point["rating"]) == (score["composite"], score["rating"])


def test_trend_not_found_and_empty(client):
    seed(client)
    assert client.get("/saccos/9999/trend").status_code == 404
    with client.Session() as s:
        new = Sacco(name="NO FIGURES YET")
        s.add(new)
        s.commit()
        new_id = new.id
    assert client.get(f"/saccos/{new_id}/trend").json() == []

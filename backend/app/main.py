from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import DateTime, inspect, text

from .database import Base, engine
from .routers import auth, ingest, ingest_growth, metrics, saccos, scores, users, watchlists


def _migrate_timestamp_columns():
    with engine.begin() as connection:
        inspector = inspect(connection)
        existing_tables = set(inspector.get_table_names())
        for table in Base.metadata.sorted_tables:
            if table.name not in existing_tables:
                continue
            existing_columns = {column["name"] for column in inspector.get_columns(table.name)}
            quoted_table = connection.dialect.identifier_preparer.quote(table.name)
            for column_name in ("created_at", "updated_at"):
                if column_name in existing_columns:
                    continue
                quoted_column = connection.dialect.identifier_preparer.quote(column_name)
                column_type = DateTime(timezone=True).compile(dialect=connection.dialect)
                connection.execute(text(
                    f"ALTER TABLE {quoted_table} ADD COLUMN {quoted_column} {column_type}"
                ))
                connection.execute(text(
                    f"UPDATE {quoted_table} SET {quoted_column} = CURRENT_TIMESTAMP "
                    f"WHERE {quoted_column} IS NULL"
                ))
                if connection.dialect.name == "postgresql":
                    connection.execute(text(
                        f"ALTER TABLE {quoted_table} ALTER COLUMN {quoted_column} "
                        "SET DEFAULT CURRENT_TIMESTAMP"
                    ))
                    connection.execute(text(
                        f"ALTER TABLE {quoted_table} ALTER COLUMN {quoted_column} SET NOT NULL"
                    ))


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)  # creates any missing tables at startup
    columns = {column["name"] for column in inspect(engine).get_columns("saccos")}
    if "is_archived" not in columns:
        with engine.begin() as connection:
            connection.execute(text(
                "ALTER TABLE saccos ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE"
            ))
    _migrate_timestamp_columns()
    yield


app = FastAPI(
    title="SACCO PEARLS API",
    description="Prototype backend: auth (Argon2id + JWT), SACCOs, financial metrics, watchlists.",
    version="0.1.0",
    lifespan=lifespan,
)

# Allows the admin.html panel (opened as a local file, or from any dev origin)
# to call this API from the browser. Fine for a student prototype; a deployed
# production system would instead list only its real frontend's exact origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(saccos.router)
app.include_router(metrics.router)
app.include_router(watchlists.router)
app.include_router(ingest.router)
app.include_router(ingest_growth.router)
app.include_router(scores.router)


@app.get("/", tags=["Health"])
def health():
    return {"status": "ok", "service": "sacco-pearls-api"}

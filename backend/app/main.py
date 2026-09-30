from contextlib import asynccontextmanager

from fastapi import FastAPI

from .database import Base, engine
from .routers import auth, metrics, saccos, users, watchlists


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)  # creates any missing tables at startup
    yield


app = FastAPI(
    title="SACCO PEARLS API",
    description="Prototype backend: auth (Argon2id + JWT), SACCOs, financial metrics, watchlists.",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(saccos.router)
app.include_router(metrics.router)
app.include_router(watchlists.router)


@app.get("/", tags=["Health"])
def health():
    return {"status": "ok", "service": "sacco-pearls-api"}

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import auth, ingest, ingest_growth, metrics, saccos, users, watchlists


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


@app.get("/", tags=["Health"])
def health():
    return {"status": "ok", "service": "sacco-pearls-api"}

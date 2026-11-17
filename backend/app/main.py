"""Main FastAPI application entry point."""
from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.config import get_settings
from app.db import init_db
from app.routers import charts, images, library, playlists, search, songs

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("music_app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context: initialize DB tables on startup."""
    logger.info("Initializing database schema...")
    init_db()
    logger.info("Database initialized successfully.")
    yield
    logger.info("Application shutting down.")


settings = get_settings()

app = FastAPI(
    title="Personal Music Streaming Backend",
    description="Spotify-inspired personal ad-free music streaming backend using Audius & Jamendo.",
    version="0.1.0",
    lifespan=lifespan,
    debug=settings.DEBUG,
)

# Enable CORS for Flutter mobile / web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)
# GZip compression for fast payload transfers
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Include routers
app.include_router(charts.router)
app.include_router(search.router)
app.include_router(songs.router)
app.include_router(library.router)
app.include_router(playlists.router)
app.include_router(images.router)


@app.get("/", tags=["health"])
async def root():
    """Service status and quick info."""
    return {
        "status": "online",
        "app": "Personal Music Streaming Backend",
        "version": "0.1.0",
        "sources": {
            "audius": "active",
            "jamendo": "active" if bool(settings.JAMENDO_CLIENT_ID) else "unconfigured (optional)",
        },
    }


@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint."""
    return {"status": "ok"}

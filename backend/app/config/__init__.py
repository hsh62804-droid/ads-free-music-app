"""Application settings and configuration."""
from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration loaded from environment variables or .env file."""

    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "sqlite:///./music.db"

    # Audius API
    AUDIUS_APP_NAME: str = "SpotifyClonePersonal"

    # Jamendo API (Optional)
    JAMENDO_CLIENT_ID: Optional[str] = None

    # Official YouTube Data API v3 key (Optional)
    YOUTUBE_API_KEY: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


@lru_cache()
def get_settings() -> Settings:
    """Return a cached instance of Settings."""
    return Settings()

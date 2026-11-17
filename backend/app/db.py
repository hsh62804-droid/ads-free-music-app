"""Database connection and session setup."""
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session

from app.config import get_settings

settings = get_settings()

# For SQLite, check_same_thread=False allows FastAPI threads to share connections safely.
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {},
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def init_db() -> None:
    """Create all database tables and apply simple migrations."""
    Base.metadata.create_all(bind=engine)
    # Ensure is_preview column exists for existing sqlite databases
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE songs ADD COLUMN is_preview BOOLEAN DEFAULT 0"))
            conn.commit()
        except Exception:
            pass
        try:
            conn.execute(text("ALTER TABLE songs ADD COLUMN is_full BOOLEAN DEFAULT 1"))
            conn.commit()
        except Exception:
            pass


def get_db() -> Generator[Session, None, None]:
    """Yield a database session and ensure it closes after request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

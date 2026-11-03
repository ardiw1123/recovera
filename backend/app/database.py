from collections.abc import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session

from app.config import get_settings

settings = get_settings()

# For SQLite, check_same_thread is needed; for PostgreSQL it is omitted
# Supabase Transaction Pooler (PgBouncer port 6543) requires disabling prepared statements (prepare_threshold: None) in psycopg v3
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {"prepare_threshold": None}

engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    Base.metadata.create_all(bind=engine)

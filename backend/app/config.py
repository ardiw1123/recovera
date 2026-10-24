from functools import lru_cache
from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Recovera API"
    environment: str = "development"
    debug: bool = True
    port: int = 8000
    host: str = "0.0.0.0"

    secret_key: str = "recovera-super-secret-development-key-change-in-production-1234567890"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    database_url: str = Field(
        default="sqlite:///./recovera.db",
        validation_alias=AliasChoices("SUPABASE_DATABASE_URL", "DATABASE_URL"),
        description="Supabase PostgreSQL connection string for deployed environments",
    )
    cors_origins: str = "*"

    gemini_api_key: str = ""
    groq_api_key: str = ""
    cloudinary_url: str = ""
    fcm_server_key: str = ""
    web3_rpc_url: str = "https://rpc.bot-chain.testnet"

    # Feature flag: aktifkan ML (default True: load AI models on boot with rule-based fallback)
    use_ml_model: bool = True

    @model_validator(mode="after")
    def require_postgres_outside_local_development(self):
        if self.environment.lower() not in {"development", "test", "testing"} and self.database_url.startswith("sqlite"):
            raise ValueError("SUPABASE_DATABASE_URL must point to Supabase PostgreSQL outside local development")
        return self

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

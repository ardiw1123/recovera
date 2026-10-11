from functools import lru_cache
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

    database_url: str = "sqlite:///./recovera.db"
    cors_origins: str = "*"

    gemini_api_key: str = ""
    cloudinary_url: str = ""
    fcm_server_key: str = ""
    web3_rpc_url: str = "https://rpc.bot-chain.testnet"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

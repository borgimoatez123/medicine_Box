from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    FACE_SIMILARITY_THRESHOLD: float = 0.30

    HOST: str = "0.0.0.0"
    PORT: int = 8000

    FACE_MAX_IMAGE_BYTES: int = 8 * 1024 * 1024


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings

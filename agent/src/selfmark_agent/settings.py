"""Environment-bound settings placeholder for future Agent slices."""

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Settings:
    environment: str = os.getenv("SELFMARK_AGENT_ENV", "local")
    api_base_url: str = os.getenv(
        "SELFMARK_AGENT_API_BASE_URL", "http://localhost:8080"
    )


settings = Settings()

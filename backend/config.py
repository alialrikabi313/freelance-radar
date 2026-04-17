"""إعدادات الـ scraper وقراءة المتغيرات البيئية."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache
from typing import List

from dotenv import load_dotenv

load_dotenv()


@dataclass
class Settings:
    # Firebase — اختر طريقة واحدة فقط
    firebase_credentials_path: str = field(
        default_factory=lambda: os.getenv("FIREBASE_CREDENTIALS_PATH", "")
    )
    firebase_credentials_json: str = field(
        default_factory=lambda: os.getenv("FIREBASE_CREDENTIALS_JSON", "")
    )
    firestore_collection: str = field(
        default_factory=lambda: os.getenv("FIRESTORE_COLLECTION", "jobs")
    )

    # External APIs
    freelancer_api_key: str = field(
        default_factory=lambda: os.getenv("FREELANCER_API_KEY", "")
    )

    # Filtering
    min_relevance_score: float = field(
        default_factory=lambda: float(os.getenv("MIN_RELEVANCE_SCORE", "0.3"))
    )
    max_job_age_days: int = field(
        default_factory=lambda: int(os.getenv("MAX_JOB_AGE_DAYS", "30"))
    )

    # Scraping
    request_delay_min: int = field(
        default_factory=lambda: int(os.getenv("REQUEST_DELAY_MIN", "2"))
    )
    request_delay_max: int = field(
        default_factory=lambda: int(os.getenv("REQUEST_DELAY_MAX", "5"))
    )

    user_agents: List[str] = field(
        default_factory=lambda: [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:123.0) Gecko/20100101 Firefox/123.0",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
            "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ]
    )


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

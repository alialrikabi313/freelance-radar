"""الـ base class لجميع الـ scrapers."""
from __future__ import annotations

import asyncio
import logging
import random
import re
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Iterable, List, Optional, Sequence, Union

import httpx

from config import settings
from models.job import JobCreate

logger = logging.getLogger(__name__)


# كلمات مفتاحية للتأكد من أن المشروع متعلق بتطوير تطبيقات الموبايل
MOBILE_KEYWORDS = [
    # English
    "flutter", "dart", "react native", "react-native",
    "mobile app", "mobile application", "mobile development",
    "android", "ios", "iphone", "ipad",
    "swift", "swiftui", "kotlin", "jetpack compose",
    "xamarin", "ionic", "cordova", "nativescript",
    "app development", "cross-platform", "cross platform",
    "objective-c", "objective c",
    "google play", "app store", "apk",
    # Arabic
    "تطبيق", "تطبيقات", "موبايل", "جوال", "هاتف",
    "أندرويد", "اندرويد", "آيفون", "ايفون", "ايباد",
    "فلاتر", "فلتر", "رياكت نيتيف",
]


class BaseScraper(ABC):
    """أساس مشترك لجميع الـ scrapers: rate limiting, UA rotation, normalization."""

    platform: str = "base"

    def __init__(self) -> None:
        self._last_request_at: float = 0.0

    # ───────────────── HTTP helpers ─────────────────

    def _random_user_agent(self) -> str:
        return random.choice(settings.user_agents)

    async def _polite_delay(self) -> None:
        delay = random.uniform(
            settings.request_delay_min, settings.request_delay_max
        )
        await asyncio.sleep(delay)

    async def _get(
        self,
        url: str,
        *,
        params: Union[dict, Sequence[tuple[str, Any]], None] = None,
        headers: Optional[dict] = None,
        timeout: float = 20.0,
    ) -> Optional[httpx.Response]:
        await self._polite_delay()
        final_headers = {
            "User-Agent": self._random_user_agent(),
            "Accept-Language": "ar,en;q=0.8",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }
        if headers:
            final_headers.update(headers)
        try:
            async with httpx.AsyncClient(
                timeout=timeout, follow_redirects=True
            ) as client:
                resp = await client.get(url, params=params, headers=final_headers)
                if resp.status_code >= 400:
                    logger.warning(
                        "[%s] HTTP %s on %s", self.platform, resp.status_code, url
                    )
                    return None
                return resp
        except (httpx.HTTPError, asyncio.TimeoutError) as exc:
            logger.warning("[%s] request failed: %s", self.platform, exc)
            return None

    # ───────────────── Normalization helpers ─────────────────

    @staticmethod
    def clean_text(raw: str, *, limit: int = 500) -> str:
        if not raw:
            return ""
        # حذف HTML tags
        no_tags = re.sub(r"<[^>]+>", " ", raw)
        # توحيد المسافات
        collapsed = re.sub(r"\s+", " ", no_tags).strip()
        if limit and len(collapsed) > limit:
            return collapsed[:limit].rstrip() + "…"
        return collapsed

    @staticmethod
    def is_mobile_related(*texts: str) -> bool:
        """فحص أولي قبل التخزين: هل النص يذكر شيئاً متعلقاً بالموبايل؟"""
        haystack = " ".join(t for t in texts if t).lower()
        return any(k in haystack for k in MOBILE_KEYWORDS)

    @staticmethod
    def extract_skills(text: str, known_skills: Iterable[str]) -> List[str]:
        """استخراج المهارات بالمطابقة مع قائمة معروفة."""
        low = text.lower()
        found: List[str] = []
        for skill in known_skills:
            if skill.lower() in low and skill not in found:
                found.append(skill)
        return found[:10]

    def normalize_job(
        self,
        *,
        title: str,
        description: str,
        url: str,
        published_at: Optional[datetime] = None,
        budget_min: Optional[float] = None,
        budget_max: Optional[float] = None,
        currency: str = "USD",
        skills: Optional[List[str]] = None,
        client_name: Optional[str] = None,
        client_rating: Optional[float] = None,
        client_jobs_posted: Optional[int] = None,
        proposals_count: Optional[int] = None,
        is_hourly: bool = False,
        country: Optional[str] = None,
    ) -> JobCreate:
        return JobCreate(
            platform=self.platform,
            title=self.clean_text(title, limit=300),
            description=self.clean_text(description, limit=1500),
            budget_min=budget_min,
            budget_max=budget_max,
            currency=currency,
            skills=skills or [],
            client_name=client_name,
            client_rating=client_rating,
            client_jobs_posted=client_jobs_posted,
            proposals_count=proposals_count,
            url=url,
            published_at=published_at or datetime.utcnow(),
            is_hourly=is_hourly,
            country=country,
        )

    # ───────────────── Public API ─────────────────

    @abstractmethod
    async def scrape(self) -> List[JobCreate]:
        """يُرجع قائمة المشاريع المسحوبة من المنصة."""
        raise NotImplementedError

    async def safe_scrape(self) -> List[JobCreate]:
        """تغليف scrape مع معالجة أخطاء كي لا يُسقط فشل scraper كامل الجولة."""
        try:
            jobs = await self.scrape()
            logger.info("[%s] scraped %d jobs", self.platform, len(jobs))
            return jobs
        except Exception as exc:  # noqa: BLE001
            logger.exception("[%s] scrape failed: %s", self.platform, exc)
            return []

"""خمسات Scraper — قسم طلبات الخدمات المتعلقة بتطوير تطبيقات الموبايل."""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from models.job import JobCreate

from .base_scraper import BaseScraper
from .mostaql_scraper import _parse_relative_arabic_time

logger = logging.getLogger(__name__)


BASE_URL = "https://khamsat.com"
REQUESTS_URL = "https://khamsat.com/community/requests?category=programming"

KNOWN_SKILLS = [
    "Flutter", "فلاتر", "React Native", "Android", "اندرويد",
    "iOS", "آيفون", "Firebase", "تطبيق موبايل", "تطبيق جوال",
    "Dart", "Java", "Kotlin",
]


class KhamsatScraper(BaseScraper):
    platform = "khamsat"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for page in range(1, 4):
            url = f"{REQUESTS_URL}&page={page}"
            resp = await self._get(url)
            if resp is None:
                continue

            soup = BeautifulSoup(resp.text, "lxml")
            rows = soup.select("tr.forum_post") or soup.select(
                "table tbody tr"
            )

            for row in rows:
                title_link = row.select_one("h3.details-head a") or row.select_one(
                    "h3 a"
                )
                if not title_link:
                    continue

                title = title_link.get_text(strip=True)
                href = title_link.get("href") or ""
                request_url = urljoin(BASE_URL, href).split("?")[0]
                if not request_url or request_url in seen:
                    continue
                seen.add(request_url)

                # خمسات لا يعرض الوصف في صفحة القائمة
                # نستخدم العنوان فقط للفلتر
                if not self.is_mobile_related(title):
                    continue

                # الوقت: span[title="17/04/2026 03:46:35 GMT"]
                published_at = _parse_khamsat_time(row)

                skills = self.extract_skills(title, KNOWN_SKILLS)

                jobs.append(
                    self.normalize_job(
                        title=title,
                        description="",  # غير متاح في الـ listing
                        url=request_url,
                        published_at=published_at,
                        budget_min=None,
                        budget_max=None,
                        currency="USD",
                        skills=skills,
                    )
                )
        return jobs


# ────────────────────────── Helpers ──────────────────────────


def _parse_khamsat_time(row) -> datetime:
    """خمسات يضع الوقت في span[title="DD/MM/YYYY HH:MM:SS GMT"]."""
    spans = row.select("span[title]")
    for sp in spans:
        title = sp.get("title") or ""
        # Format: "17/04/2026 03:46:35 GMT"
        try:
            # أزل " GMT" وحلّل
            cleaned = title.replace(" GMT", "").strip()
            return datetime.strptime(cleaned, "%d/%m/%Y %H:%M:%S")
        except (ValueError, TypeError):
            continue

    # fallback: النص العربي "منذ X"
    text = row.get_text(" ", strip=True)
    return _parse_relative_arabic_time(text)

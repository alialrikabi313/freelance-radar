"""The Muse Scraper — وظائف من شركات معروفة.

API: https://www.themuse.com/developers/api/v2
يعمل بدون مفتاح (500 req/h). لو أردت 3600 req/h راسل api@themuse.com.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import List

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://www.themuse.com/api/public/jobs"

# فئات تقنية فقط
CATEGORIES = [
    "Software Engineering",
    "Data and Analytics",
    "Data Science",
    "IT",
    "Design and UX",
]

# عدد الصفحات لكل فئة (20 وظيفة/صفحة)
PAGES_PER_CATEGORY = 3


class TheMuseScraper(BaseScraper):
    platform = "themuse"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for category in CATEGORIES:
            for page in range(PAGES_PER_CATEGORY):
                resp = await self._get(
                    API_URL,
                    params={
                        "page": page,
                        "category": category,
                        "descending": "true",
                    },
                )
                if resp is None:
                    continue
                try:
                    data = resp.json()
                except ValueError:
                    continue

                for item in data.get("results", []) or []:
                    job = self._parse(item)
                    if job is None or job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)

                # لو الـ page فارغ، توقف مبكراً
                if len(data.get("results", [])) < 20:
                    break
        return jobs

    def _parse(self, item: dict) -> JobCreate | None:
        title = item.get("name") or ""
        contents_html = item.get("contents") or ""
        description = self.clean_text(contents_html, limit=1500)

        if not self.is_programming_related(title, description):
            return None

        refs = item.get("refs") or {}
        url = refs.get("landing_page") or ""
        if not url:
            return None

        company = item.get("company") or {}
        client_name = company.get("name")

        locations = item.get("locations") or []
        country = None
        if locations:
            country = locations[0].get("name")

        tags = item.get("tags") or []
        levels = item.get("levels") or []
        categories = item.get("categories") or []
        skills = [
            t.get("name") for t in tags if t.get("name")
        ] + [c.get("name") for c in categories if c.get("name")]
        # أضف المستوى للمهارات ليكون قابلاً للبحث
        for lvl in levels:
            name = lvl.get("name")
            if name and name not in skills:
                skills.append(name)
        skills = [s for s in skills if s][:10]

        published_at = _parse_date(item.get("publication_date"))

        return self.normalize_job(
            title=title,
            description=description,
            url=url,
            published_at=published_at,
            skills=skills,
            client_name=client_name,
            country=country,
            currency="USD",
        )


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()

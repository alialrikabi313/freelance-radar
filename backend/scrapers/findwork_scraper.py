"""Findwork.dev Scraper — وظائف تقنية عالمية (أغلبها remote).

Docs: https://findwork.dev/developers/
Auth: Token header.
Rate limit: 60 requests/minute.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List

import httpx

from config import settings
from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://findwork.dev/api/jobs/"

# نستهدف: remote + عدة queries لتنوع النتائج
QUERIES = [
    {"remote": "true", "sort_by": "date"},
    {"search": "mobile", "sort_by": "date"},
    {"search": "flutter", "sort_by": "date"},
    {"search": "react native", "sort_by": "date"},
]
PAGES_PER_QUERY = 2  # صفحتين لكل query


class FindworkScraper(BaseScraper):
    platform = "findwork"

    async def scrape(self) -> List[JobCreate]:
        if not settings.findwork_api_key:
            logger.info("[findwork] FINDWORK_API_KEY not set; skipping")
            return []

        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for base_params in QUERIES:
            for page in range(1, PAGES_PER_QUERY + 1):
                batch = await self._fetch({**base_params, "page": page})
                if not batch:
                    break  # لا جدوى من الصفحة التالية
                for job in batch:
                    if job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)
        return jobs

    async def _fetch(self, params: dict) -> List[JobCreate]:
        await self._polite_delay()
        headers = {
            "Authorization": f"Token {settings.findwork_api_key}",
            "Accept": "application/json",
            "User-Agent": self._random_user_agent(),
        }
        try:
            async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
                resp = await client.get(API_URL, params=params, headers=headers)
                if resp.status_code >= 400:
                    logger.warning(
                        "[findwork] HTTP %s for %s",
                        resp.status_code, params,
                    )
                    return []
                data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.warning("[findwork] request failed: %s", exc)
            return []

        jobs: List[JobCreate] = []
        for item in data.get("results", []) or []:
            title = item.get("role") or ""
            description = item.get("text") or ""
            keywords = item.get("keywords") or []

            if not self.is_programming_related(
                title, description, " ".join(keywords)
            ):
                continue

            url = item.get("url") or ""
            if not url:
                continue

            published_at = _parse_date(item.get("date_posted"))

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    skills=[str(k) for k in keywords if k][:10],
                    client_name=item.get("company_name"),
                    country=item.get("location"),
                    currency="USD",
                )
            )
        return jobs


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()

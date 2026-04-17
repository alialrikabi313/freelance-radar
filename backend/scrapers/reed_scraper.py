"""Reed.co.uk Scraper — سوق الوظائف البريطاني الأكبر.

Docs: https://www.reed.co.uk/developers/jobseeker
Auth: HTTP Basic — API key كـ username، password فارغ.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List, Optional

import httpx

from config import settings
from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://www.reed.co.uk/api/1.0/search"

SEARCH_QUERIES = [
    "flutter developer",
    "mobile developer",
    "react developer",
    "software engineer",
    "python developer",
    "full stack developer",
]

KNOWN_SKILLS = [
    "Flutter", "Dart", "React Native", "Swift", "Kotlin",
    "Android", "iOS", "Firebase",
    "React", "Vue", "Angular", "TypeScript", "JavaScript",
    "Python", "Django", "FastAPI", "Node.js",
    "Go", "Rust", "Ruby", "Rails", "PHP", "Laravel",
    "AWS", "Docker", "Kubernetes", "PostgreSQL", "MongoDB",
]


class ReedScraper(BaseScraper):
    platform = "reed"

    async def scrape(self) -> List[JobCreate]:
        if not settings.reed_api_key:
            logger.info("[reed] REED_API_KEY not set; skipping")
            return []

        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for query in SEARCH_QUERIES:
            batch = await self._fetch(query)
            for job in batch:
                if job.url in seen:
                    continue
                seen.add(job.url)
                jobs.append(job)
        return jobs

    async def _fetch(self, query: str) -> List[JobCreate]:
        # Reed يتطلب Basic Auth — نستخدم httpx مباشرة بدل _get
        # لأن base_scraper._get لا يدعم auth.
        await self._polite_delay()
        headers = {
            "User-Agent": self._random_user_agent(),
            "Accept": "application/json",
        }
        try:
            async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
                resp = await client.get(
                    API_URL,
                    params={
                        "keywords": query,
                        "resultsToTake": 100,
                    },
                    headers=headers,
                    auth=(settings.reed_api_key, ""),
                )
                if resp.status_code >= 400:
                    logger.warning(
                        "[reed] HTTP %s for query=%s",
                        resp.status_code, query,
                    )
                    return []
                data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.warning("[reed] request failed: %s", exc)
            return []

        jobs: List[JobCreate] = []
        for item in data.get("results", []) or []:
            title = item.get("jobTitle") or ""
            description = item.get("jobDescription") or ""

            if not self.is_programming_related(title, description):
                continue

            url = item.get("jobUrl") or ""
            if not url:
                continue

            budget_min = _to_float(item.get("minimumSalary"))
            budget_max = _to_float(item.get("maximumSalary"))
            currency = (item.get("currency") or "GBP").upper()[:3]

            published_at = _parse_date(item.get("date"))

            skills = self.extract_skills(
                f"{title} {description}", KNOWN_SKILLS
            )

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency=currency,
                    skills=skills,
                    client_name=item.get("employerName"),
                    country=item.get("locationName"),
                    is_hourly=False,
                )
            )
        return jobs


def _to_float(v) -> Optional[float]:
    if v in (None, "", 0, "0"):
        return None
    try:
        f = float(v)
        return f if f > 0 else None
    except (TypeError, ValueError):
        return None


def _parse_date(raw) -> datetime:
    """Reed يُرجع التاريخ بصيغة "DD/MM/YYYY"."""
    if not raw:
        return datetime.utcnow()
    s = str(raw).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(s[:19] if "T" in s else s, fmt)
        except ValueError:
            continue
    return datetime.utcnow()

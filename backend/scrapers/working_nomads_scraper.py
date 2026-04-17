"""Working Nomads Scraper — JSON API عام.

URL: https://www.workingnomads.com/api/exposed_jobs/
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://www.workingnomads.com/api/exposed_jobs/"


class WorkingNomadsScraper(BaseScraper):
    platform = "workingnomads"

    async def scrape(self) -> List[JobCreate]:
        resp = await self._get(API_URL)
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            return []

        jobs: List[JobCreate] = []
        for item in data if isinstance(data, list) else []:
            title = item.get("title") or ""
            description = item.get("description") or ""
            tags_raw = item.get("tags") or ""
            category = item.get("category_name") or ""
            tags = [t.strip() for t in tags_raw.split(",") if t.strip()]

            if not self.is_programming_related(
                title, description, tags_raw, category
            ):
                continue

            url = (item.get("url") or "").split("?")[0]
            if not url:
                continue

            published_at = _parse_date(item.get("pub_date"))

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    skills=tags[:10],
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

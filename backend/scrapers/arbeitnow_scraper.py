"""Arbeitnow Scraper — JSON API عام.

Docs: https://documenter.getpostman.com/view/18545278/UVkstmMS
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://www.arbeitnow.com/api/job-board-api"


class ArbeitnowScraper(BaseScraper):
    platform = "arbeitnow"

    async def scrape(self) -> List[JobCreate]:
        resp = await self._get(API_URL)
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            return []

        jobs: List[JobCreate] = []
        for item in data.get("data", []) or []:
            title = item.get("title") or ""
            description = item.get("description") or ""
            tags = item.get("tags") or []

            if not self.is_programming_related(
                title, description, " ".join(tags)
            ):
                continue

            url = (item.get("url") or "").split("?")[0]
            if not url:
                continue

            published_at = _parse_created(item.get("created_at"))

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    skills=[str(t) for t in tags if t][:10],
                    client_name=item.get("company_name"),
                    country=item.get("location"),
                    currency="EUR",
                )
            )
        return jobs


def _parse_created(raw) -> datetime:
    if raw is None:
        return datetime.utcnow()
    if isinstance(raw, (int, float)):
        try:
            return datetime.fromtimestamp(float(raw))
        except (OSError, OverflowError):
            return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()

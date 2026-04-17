"""RemoteOK Scraper — JSON API عام بدون auth.

Docs: https://remoteok.com/api
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List, Optional

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://remoteok.com/api"


class RemoteOkScraper(BaseScraper):
    platform = "remoteok"

    async def scrape(self) -> List[JobCreate]:
        resp = await self._get(API_URL)
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            logger.warning("[remoteok] non-JSON response")
            return []

        jobs: List[JobCreate] = []
        for item in data:
            # أول عنصر عادة metadata
            if not isinstance(item, dict) or not item.get("id"):
                continue
            if not item.get("position") or not item.get("url"):
                continue

            title = item.get("position") or ""
            description = item.get("description") or ""
            tags = item.get("tags") or []

            if not self.is_programming_related(
                title, description, " ".join(tags)
            ):
                continue

            url = item.get("apply_url") or item.get("url") or ""
            url = url.split("?")[0]
            if not url:
                continue

            budget_min = _to_float(item.get("salary_min")) or None
            budget_max = _to_float(item.get("salary_max")) or None
            # RemoteOK يستخدم 0 بدل null للرواتب غير المعلنة
            if budget_min == 0:
                budget_min = None
            if budget_max == 0:
                budget_max = None

            published_at = _parse_date(
                item.get("date") or item.get("epoch")
            )

            skills = [str(t) for t in tags if t][:10]

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency="USD",
                    skills=skills,
                    client_name=item.get("company"),
                    is_hourly=False,
                    country=item.get("location"),
                )
            )
        return jobs


def _to_float(v) -> Optional[float]:
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _parse_date(raw) -> datetime:
    if raw is None:
        return datetime.utcnow()
    if isinstance(raw, (int, float)):
        try:
            return datetime.fromtimestamp(float(raw))
        except (OSError, OverflowError):
            return datetime.utcnow()
    try:
        return datetime.fromisoformat(
            str(raw).replace("Z", "+00:00")
        ).replace(tzinfo=None)
    except (ValueError, TypeError):
        return datetime.utcnow()

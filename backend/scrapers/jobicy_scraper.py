"""Jobicy Scraper — JSON API عام.

Docs: https://jobicy.com/jobs-rss-feed
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List, Optional

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://jobicy.com/api/v2/remote-jobs"


class JobicyScraper(BaseScraper):
    platform = "jobicy"

    async def scrape(self) -> List[JobCreate]:
        # نطلب الفئات البرمجية فقط
        resp = await self._get(
            API_URL, params={"count": "50", "industry": "dev"}
        )
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            return []

        jobs: List[JobCreate] = []
        for item in data.get("jobs", []) or []:
            title = item.get("jobTitle") or ""
            description = (
                item.get("jobDescription") or item.get("jobExcerpt") or ""
            )
            industries = item.get("jobIndustry") or []

            if not self.is_programming_related(
                title, description, " ".join(industries)
            ):
                continue

            url = (item.get("url") or "").split("?")[0]
            if not url:
                continue

            budget_min = _to_float(item.get("annualSalaryMin"))
            budget_max = _to_float(item.get("annualSalaryMax"))
            currency = (item.get("salaryCurrency") or "USD").upper()[:3]

            published_at = _parse_date(item.get("pubDate"))

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=description,
                    url=url,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency=currency,
                    skills=industries[:10],
                    client_name=item.get("companyName"),
                    country=item.get("jobGeo"),
                )
            )
        return jobs


def _to_float(v) -> Optional[float]:
    if v in (None, "", 0, "0"):
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        # يأتي كـ "2026-04-15 14:19:37" أو ISO
        s = str(raw).replace("Z", "").strip()
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
            try:
                return datetime.strptime(s[:19], fmt)
            except ValueError:
                continue
        return datetime.fromisoformat(s).replace(tzinfo=None)
    except (ValueError, TypeError):
        return datetime.utcnow()

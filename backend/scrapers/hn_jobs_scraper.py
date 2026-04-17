"""Hacker News Jobs Scraper — عبر Algolia HN Search API.

API: https://hn.algolia.com/api
لا يحتاج auth. نجلب posts من نوع job المنشورة في آخر 45 يوم.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime, timedelta
from typing import List, Optional

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://hn.algolia.com/api/v1/search_by_date"


_SALARY_RE = re.compile(
    r"\$\s?([\d,]+)\s?(?:k|K|,000)?\s*(?:[-–to]+)\s*\$?\s*([\d,]+)\s?(?:k|K|,000)?"
)

KNOWN_SKILLS = [
    "Flutter", "React Native", "Swift", "Kotlin", "Android", "iOS",
    "React", "Vue", "TypeScript", "JavaScript", "Python", "Go", "Rust",
    "Ruby", "Rails", "Node.js", "PostgreSQL", "MongoDB", "AWS", "Kubernetes",
]


class HnJobsScraper(BaseScraper):
    platform = "hn_jobs"

    async def scrape(self) -> List[JobCreate]:
        # آخر 45 يوم
        cutoff = int((datetime.utcnow() - timedelta(days=45)).timestamp())

        resp = await self._get(
            API_URL,
            params={
                "tags": "job",
                "numericFilters": f"created_at_i>{cutoff}",
                "hitsPerPage": "100",
            },
        )
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            return []

        jobs: List[JobCreate] = []
        for hit in data.get("hits", []) or []:
            title = hit.get("title") or ""
            text = hit.get("story_text") or ""

            if not self.is_programming_related(title, text):
                continue

            url = hit.get("url") or (
                f"https://news.ycombinator.com/item?id={hit.get('objectID')}"
                if hit.get("objectID")
                else ""
            )
            url = url.split("?")[0] if "?" in url and "item?" not in url else url
            if not url:
                continue

            budget_min, budget_max = _parse_salary(f"{title} {text}")
            published_at = _parse_date(hit.get("created_at"))
            skills = self.extract_skills(f"{title} {text}", KNOWN_SKILLS)

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=text,
                    url=url,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency="USD",
                    skills=skills,
                    client_name=hit.get("author"),
                )
            )
        return jobs


def _parse_salary(text: str) -> tuple[Optional[float], Optional[float]]:
    m = _SALARY_RE.search(text)
    if not m:
        return None, None
    try:
        lo = float(m.group(1).replace(",", ""))
        hi = float(m.group(2).replace(",", ""))
        tl = text.lower()
        # تحويل "k" إلى آلاف
        if any(s in tl for s in ("k -", "k–", "$k", "k/")) or (
            lo < 1000 and hi < 1000
        ):
            lo *= 1000
            hi *= 1000
        return lo, hi
    except ValueError:
        return None, None


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()

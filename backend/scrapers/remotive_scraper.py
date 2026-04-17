"""Remotive Scraper — وظائف عن بُعد عبر Remotive Public API.

يستبدل Upwork RSS الذي تم تعطيله منذ 2023 (HTTP 410 Gone).
Remotive API عام ومجاني وبدون authentication.
Docs: https://remotive.com/api-documentation
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import List, Optional

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


API_URL = "https://remotive.com/api/remote-jobs"

# نسحب قسم software-dev ثم نفلتر ذاتياً على فرص الموبايل
REMOTIVE_CATEGORIES = ["software-dev"]

KNOWN_SKILLS = [
    "Flutter", "Dart", "React Native", "Swift", "SwiftUI", "Kotlin",
    "Java", "Objective-C", "Android", "iOS", "Firebase",
    "Node.js", "Express", "REST API", "GraphQL",
    "Google Maps", "Stripe", "PayPal", "Push Notifications",
    "Xamarin", "Ionic", "Cordova", "TypeScript", "JavaScript",
]


_SALARY_RE = re.compile(r"\$?\s*([\d,]+)(?:k|K)?\s*(?:-|–|to)\s*\$?\s*([\d,]+)(?:k|K)?")


class RemotiveScraper(BaseScraper):
    platform = "remotive"

    async def scrape(self) -> List[JobCreate]:
        all_jobs: List[JobCreate] = []
        seen_urls: set[str] = set()

        for category in REMOTIVE_CATEGORIES:
            resp = await self._get(
                API_URL,
                params={"category": category, "limit": "100"},
            )
            if resp is None:
                continue

            try:
                data = resp.json()
            except ValueError:
                logger.warning("[remotive] non-JSON response")
                continue

            for item in data.get("jobs", []) or []:
                url = (item.get("url") or "").split("?")[0]
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)

                title = item.get("title") or ""
                description = item.get("description") or ""
                tags = item.get("tags") or []

                # الفلتر الأساسي: هل هذه فرصة موبايل؟
                if not self.is_mobile_related(
                    title, description, " ".join(tags)
                ):
                    continue

                budget_min, budget_max = _parse_salary(item.get("salary", ""))
                published_at = _parse_date(item.get("publication_date"))

                skills = list(
                    dict.fromkeys(
                        [t for t in tags if t][:10]
                        + self.extract_skills(
                            f"{title} {description}", KNOWN_SKILLS
                        )
                    )
                )[:10]

                all_jobs.append(
                    self.normalize_job(
                        title=title,
                        description=description,
                        url=url,
                        published_at=published_at,
                        budget_min=budget_min,
                        budget_max=budget_max,
                        currency="USD",
                        skills=skills,
                        client_name=item.get("company_name"),
                        is_hourly=False,
                        country=item.get("candidate_required_location"),
                    )
                )

        return all_jobs


def _parse_salary(salary: str) -> tuple[Optional[float], Optional[float]]:
    """Remotive عادة يترك الـ salary فارغ. نحاول استخراج range لو وُجد."""
    if not salary:
        return None, None
    match = _SALARY_RE.search(salary)
    if not match:
        return None, None
    try:
        lo = float(match.group(1).replace(",", ""))
        hi = float(match.group(2).replace(",", ""))
        if "k" in salary.lower():
            lo *= 1000
            hi *= 1000
        return lo, hi
    except ValueError:
        return None, None


def _parse_date(raw: Optional[str]) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        # ISO format: "2026-04-15T14:19:37"
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()

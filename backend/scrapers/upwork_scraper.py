"""Upwork Scraper — عبر RSS feeds العامة."""
from __future__ import annotations

import logging
import re
from datetime import datetime
from time import mktime
from typing import List, Optional
from urllib.parse import quote_plus

import feedparser

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


# قائمة المهارات الشائعة للاستخراج من نص المشروع
KNOWN_SKILLS = [
    "Flutter", "Dart", "React Native", "Swift", "SwiftUI", "Kotlin",
    "Java", "Objective-C", "Android", "iOS", "Firebase",
    "Node.js", "Express", "REST API", "GraphQL",
    "Google Maps", "Stripe", "PayPal", "Push Notifications",
    "Xamarin", "Ionic", "Cordova",
]


# بحوث RSS متعددة لزيادة التغطية
UPWORK_QUERIES = [
    "flutter app development",
    "mobile app development",
    "android ios app",
    "react native app",
    "mobile application developer",
]


class UpworkScraper(BaseScraper):
    platform = "upwork"

    BASE_RSS = "https://www.upwork.com/ab/feed/jobs/rss"

    async def scrape(self) -> List[JobCreate]:
        all_jobs: List[JobCreate] = []
        seen_urls: set[str] = set()

        for query in UPWORK_QUERIES:
            feed_url = (
                f"{self.BASE_RSS}"
                f"?q={quote_plus(query)}&sort=recency&paging=0%3B50"
            )
            resp = await self._get(feed_url)
            if resp is None:
                continue

            parsed = feedparser.parse(resp.text)
            for entry in parsed.entries:
                url = getattr(entry, "link", "").split("?")[0]
                if not url or url in seen_urls:
                    continue
                seen_urls.add(url)

                title = getattr(entry, "title", "")
                summary = getattr(entry, "summary", "")

                # فلتر أولي — نحتفظ بالمرتبط بالموبايل فقط
                if not self.is_mobile_related(title, summary):
                    continue

                budget_min, budget_max, currency, is_hourly = _parse_upwork_budget(
                    summary
                )
                country = _parse_country(summary)
                published_at = _parse_published(entry)
                skills = self.extract_skills(f"{title} {summary}", KNOWN_SKILLS)

                job = self.normalize_job(
                    title=title,
                    description=summary,
                    url=url,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency=currency,
                    skills=skills,
                    is_hourly=is_hourly,
                    country=country,
                )
                all_jobs.append(job)

        return all_jobs


# ────────────────────────── Helpers ──────────────────────────


_BUDGET_RE = re.compile(
    r"Budget:\s*\$?([\d,]+)(?:\s*-\s*\$?([\d,]+))?", re.IGNORECASE
)
_HOURLY_RE = re.compile(
    r"Hourly\s*Range:\s*\$?([\d,.]+)\s*-\s*\$?([\d,.]+)", re.IGNORECASE
)
_COUNTRY_RE = re.compile(r"Country:\s*([A-Za-z \-]+)", re.IGNORECASE)


def _parse_upwork_budget(
    summary: str,
) -> tuple[Optional[float], Optional[float], str, bool]:
    """استخراج الميزانية من وصف Upwork RSS."""
    hourly_match = _HOURLY_RE.search(summary)
    if hourly_match:
        try:
            return (
                float(hourly_match.group(1).replace(",", "")),
                float(hourly_match.group(2).replace(",", "")),
                "USD",
                True,
            )
        except ValueError:
            pass

    match = _BUDGET_RE.search(summary)
    if match:
        try:
            lo = float(match.group(1).replace(",", ""))
            hi = float(match.group(2).replace(",", "")) if match.group(2) else lo
            return lo, hi, "USD", False
        except ValueError:
            pass

    return None, None, "USD", False


def _parse_country(summary: str) -> Optional[str]:
    match = _COUNTRY_RE.search(summary)
    return match.group(1).strip() if match else None


def _parse_published(entry) -> datetime:
    struct = getattr(entry, "published_parsed", None) or getattr(
        entry, "updated_parsed", None
    )
    if struct:
        try:
            return datetime.fromtimestamp(mktime(struct))
        except Exception:  # noqa: BLE001
            pass
    return datetime.utcnow()

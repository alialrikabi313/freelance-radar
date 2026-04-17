"""Guru.com Scraper — سوق فريلانس عالمي (bid-based مثل Freelancer).

Web scraping لصفحات public جوب listings.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import List, Optional
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


BASE_URL = "https://www.guru.com"
CATEGORY_URLS = [
    "https://www.guru.com/d/jobs/c/programming-development/",
    "https://www.guru.com/d/jobs/c/programming-development/sc/mobile-application-development/",
    "https://www.guru.com/d/jobs/c/programming-development/sc/web-development/",
    "https://www.guru.com/d/jobs/c/design-art/sc/user-interface-design/",
]
PAGES_PER_CATEGORY = 3


class GuruScraper(BaseScraper):
    platform = "guru"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for url in CATEGORY_URLS:
            for page in range(1, PAGES_PER_CATEGORY + 1):
                page_url = f"{url}?page={page}" if page > 1 else url
                resp = await self._get(page_url)
                if resp is None:
                    continue

                soup = BeautifulSoup(resp.text, "lxml")
                records = soup.select(".jobRecord") or soup.select(".job-record")

                for rec in records:
                    job = self._parse(rec)
                    if job is None or job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)

                if len(records) < 20:
                    break
        return jobs

    def _parse(self, rec) -> Optional[JobCreate]:
        title_link = rec.select_one("h2 a") or rec.select_one("a.title")
        if not title_link:
            return None
        title = title_link.get_text(strip=True)
        href = title_link.get("href") or ""
        # guru.com أحياناً يضيف &SearchUrl=... للرابط — نقطعه
        clean_href = href.split("&")[0].split("?")[0]
        url = urljoin(BASE_URL, clean_href)

        if not self.is_programming_related(title):
            return None

        # الوصف
        desc = ""
        desc_el = rec.select_one(".description") or rec.select_one(
            "p.description"
        )
        if desc_el:
            desc = desc_el.get_text(" ", strip=True)

        # الميزانية من النص (غالباً "$100 - $500" أو "Fixed Price" إلخ)
        budget_min, budget_max = None, None
        price_el = rec.select_one(".price") or rec.select_one(".amount")
        if price_el:
            budget_min, budget_max = _parse_budget(price_el.get_text(" ", strip=True))

        # الوقت من النص "Posted X days ago" إلخ
        time_el = rec.select_one(".posted") or rec.select_one("time")
        published_at = _parse_time(time_el.get_text(strip=True) if time_el else "")

        return self.normalize_job(
            title=title,
            description=desc,
            url=url,
            published_at=published_at,
            budget_min=budget_min,
            budget_max=budget_max,
            currency="USD",
        )


# ────────── helpers ──────────


_BUDGET_RE = re.compile(r"\$?\s*([\d,]+)\s*(?:-|to)\s*\$?\s*([\d,]+)")
_SINGLE_BUDGET = re.compile(r"\$?\s*([\d,]+)")


def _parse_budget(text: str) -> tuple[Optional[float], Optional[float]]:
    if not text:
        return None, None
    m = _BUDGET_RE.search(text)
    if m:
        try:
            return (
                float(m.group(1).replace(",", "")),
                float(m.group(2).replace(",", "")),
            )
        except ValueError:
            pass
    m2 = _SINGLE_BUDGET.search(text)
    if m2:
        try:
            v = float(m2.group(1).replace(",", ""))
            return v, v
        except ValueError:
            pass
    return None, None


def _parse_time(text: str) -> datetime:
    """تحويل نصوص مثل "Posted 3 days ago" إلى datetime."""
    from datetime import timedelta
    if not text:
        return datetime.utcnow()
    t = text.lower()
    m = re.search(r"(\d+)", t)
    n = int(m.group(1)) if m else 1
    now = datetime.utcnow()
    if "hour" in t or "hr" in t:
        return now - timedelta(hours=n)
    if "day" in t:
        return now - timedelta(days=n)
    if "week" in t:
        return now - timedelta(weeks=n)
    if "month" in t:
        return now - timedelta(days=30 * n)
    if "minute" in t or "min" in t:
        return now - timedelta(minutes=n)
    return now

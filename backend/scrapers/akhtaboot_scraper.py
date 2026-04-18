"""Akhtaboot Scraper — سوق توظيف MENA.

URL: https://www.akhtaboot.com/en/jobs/search
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

BASE_URL = "https://www.akhtaboot.com"
SEARCH_QUERIES = [
    "developer",
    "flutter",
    "react native",
    "mobile",
    "software engineer",
]
PAGES_PER_QUERY = 2


class AkhtabootScraper(BaseScraper):
    platform = "akhtaboot"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for query in SEARCH_QUERIES:
            for page in range(1, PAGES_PER_QUERY + 1):
                url = (
                    f"{BASE_URL}/en/jobs/search"
                    f"?keyword={query.replace(' ', '+')}&page={page}"
                )
                resp = await self._get(url)
                if resp is None:
                    continue

                soup = BeautifulSoup(resp.text, "lxml")
                items = soup.select(".job")

                for item in items:
                    job = self._parse(item)
                    if job is None or job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)

                if len(items) < 20:
                    break
        return jobs

    def _parse(self, item) -> Optional[JobCreate]:
        link = item.select_one("a.job-link")
        if not link:
            return None

        href = link.get("href") or ""
        url = urljoin(BASE_URL, href).split("?")[0]
        if not url or "/jobs/" not in url:
            return None

        # العنوان داخل الـ a — نصه الأساسي
        title = link.get_text(" ", strip=True)
        # استخرج العنوان من الرابط "…166744-<TITLE>-at-<COMPANY>"
        company = None
        if " at " in title.lower():
            parts = re.split(r"\s+at\s+", title, maxsplit=1, flags=re.IGNORECASE)
            if len(parts) == 2:
                title = parts[0].strip()
                company = parts[1].strip()

        if not self.is_programming_related(title):
            return None

        # Date Posted في <small class="pull-right">
        date_el = item.select_one("small.pull-right")
        published_at = _parse_date(date_el.get_text(" ", strip=True) if date_el else "")

        # Location من الرابط نفسه /en/<country>/jobs/<city>/
        country = None
        m = re.search(r"/en/([^/]+)/jobs/([^/]+)/", href)
        if m:
            country = f"{m.group(2).title()}, {m.group(1).title()}"

        # Tags (skills)
        tags = []
        for tag_el in item.select(".job-tags-div a, .job-tags a"):
            t = tag_el.get_text(strip=True)
            if t:
                tags.append(t)

        return self.normalize_job(
            title=title[:200],
            description="",  # لا يظهر في القائمة
            url=url,
            published_at=published_at,
            skills=tags[:10],
            client_name=company,
            country=country,
            currency="USD",
        )


def _parse_date(text: str) -> datetime:
    """Date Posted: DD-MM-YYYY."""
    m = re.search(r"(\d{1,2})[-/](\d{1,2})[-/](\d{4})", text)
    if m:
        try:
            d, month, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
            return datetime(y, month, d)
        except (ValueError, TypeError):
            pass
    return datetime.utcnow()

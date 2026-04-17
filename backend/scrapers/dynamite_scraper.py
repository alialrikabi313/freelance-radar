"""Dynamite Jobs Scraper — RSS Feed لوظائف remote عالية الجودة.

URL: https://dynamitejobs.com/feed/rss.xml
نفلتر المقالات/المدونة ونبقي الوظائف فقط.
"""
from __future__ import annotations

import logging
from datetime import datetime
from time import mktime
from typing import List

import feedparser

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

FEED_URL = "https://dynamitejobs.com/feed/rss.xml"


class DynamiteScraper(BaseScraper):
    platform = "dynamite"

    async def scrape(self) -> List[JobCreate]:
        resp = await self._get(FEED_URL)
        if resp is None:
            return []

        parsed = feedparser.parse(resp.text)
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for entry in parsed.entries:
            link = (getattr(entry, "link", "") or "").split("?")[0]
            if not link or link in seen:
                continue
            # نستثني مقالات المدونة
            if "/blog/" in link:
                continue
            seen.add(link)

            title = getattr(entry, "title", "") or ""
            summary = getattr(entry, "summary", "") or ""

            if not self.is_programming_related(title, summary):
                continue

            struct = getattr(entry, "published_parsed", None) or getattr(
                entry, "updated_parsed", None
            )
            published_at = (
                datetime.fromtimestamp(mktime(struct))
                if struct
                else datetime.utcnow()
            )

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=summary,
                    url=link,
                    published_at=published_at,
                    currency="USD",
                )
            )
        return jobs

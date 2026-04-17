"""NoDesk Scraper — RSS Feed عام.

URL: https://nodesk.co/remote-jobs/index.xml
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

FEED_URL = "https://nodesk.co/remote-jobs/index.xml"


class NoDeskScraper(BaseScraper):
    platform = "nodesk"

    async def scrape(self) -> List[JobCreate]:
        resp = await self._get(FEED_URL)
        if resp is None:
            return []

        parsed = feedparser.parse(resp.text)
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for entry in parsed.entries:
            url = (getattr(entry, "link", "") or "").split("?")[0]
            if not url or url in seen:
                continue
            seen.add(url)

            title = getattr(entry, "title", "") or ""
            summary = getattr(entry, "summary", "") or ""

            if not self.is_programming_related(title, summary):
                continue

            # العنوان عادة: "Job Title at Company"
            client_name = None
            if " at " in title:
                parts = title.rsplit(" at ", 1)
                if len(parts) == 2:
                    client_name = parts[1].strip()
                    title = parts[0].strip()

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
                    url=url,
                    published_at=published_at,
                    client_name=client_name,
                    currency="USD",
                )
            )
        return jobs

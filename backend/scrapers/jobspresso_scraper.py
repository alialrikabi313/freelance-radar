"""Jobspresso Scraper — RSS feed (فرص remote عالية الجودة).

Feed URL: https://jobspresso.co/feed/?post_type=job_listing
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

FEED_URLS = [
    "https://jobspresso.co/feed/?post_type=job_listing",
]


class JobspressoScraper(BaseScraper):
    platform = "jobspresso"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for url in FEED_URLS:
            resp = await self._get(url)
            if resp is None:
                continue
            parsed = feedparser.parse(resp.text)
            for entry in parsed.entries:
                link = (getattr(entry, "link", "") or "").split("?")[0]
                if not link or link in seen:
                    continue
                seen.add(link)

                title = getattr(entry, "title", "") or ""
                summary = getattr(entry, "summary", "") or ""

                if not self.is_programming_related(title, summary):
                    continue

                # العنوان أحياناً بصيغة "Company: Title"
                client_name = None
                if ":" in title:
                    parts = title.split(":", 1)
                    if len(parts) == 2:
                        client_name = parts[0].strip()
                        title = parts[1].strip()

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
                        client_name=client_name,
                        currency="USD",
                    )
                )
        return jobs

"""CryptocurrencyJobs.co Scraper — وظائف Crypto/Web3.

URL: https://cryptocurrencyjobs.co/index.xml (RSS)
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

FEED_URL = "https://cryptocurrencyjobs.co/index.xml"

KNOWN_SKILLS = [
    "Solidity", "Rust", "Go", "Node.js", "React",
    "Smart Contracts", "Web3", "Ethereum", "Bitcoin", "Polygon",
    "NFT", "DeFi", "Blockchain", "Cryptocurrency",
    "Flutter", "React Native", "TypeScript", "JavaScript",
]


class CryptoJobsScraper(BaseScraper):
    platform = "cryptojobs"

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
            seen.add(link)

            title = getattr(entry, "title", "") or ""
            summary = getattr(entry, "summary", "") or ""

            # هنا نفترض كل الوظائف تقنية (الموقع crypto-focused)
            # لكن نتأكد من أنها برمجية
            if not self.is_programming_related(title, summary):
                continue

            # العنوان عادة "Title at Company"
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

            skills = self.extract_skills(
                f"{title} {summary}", KNOWN_SKILLS
            )

            jobs.append(
                self.normalize_job(
                    title=title,
                    description=summary,
                    url=link,
                    published_at=published_at,
                    skills=skills,
                    client_name=client_name,
                    currency="USD",
                )
            )
        return jobs

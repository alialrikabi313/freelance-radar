"""WeWorkRemotely Scraper — RSS Feed عام.

URL: https://weworkremotely.com/categories/remote-programming-jobs.rss
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

RSS_URLS = [
    "https://weworkremotely.com/categories/remote-programming-jobs.rss",
    "https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss",
    "https://weworkremotely.com/categories/remote-front-end-programming-jobs.rss",
    "https://weworkremotely.com/categories/remote-back-end-programming-jobs.rss",
]


KNOWN_SKILLS = [
    "Flutter", "Dart", "React Native", "Swift", "Kotlin",
    "Android", "iOS", "Firebase",
    "Node.js", "Express", "REST API", "GraphQL",
    "React", "Vue", "Angular", "TypeScript", "JavaScript",
    "Python", "Django", "Flask", "FastAPI",
    "Go", "Rust", "Ruby", "Rails", "PHP", "Laravel",
    "AWS", "Docker", "Kubernetes", "PostgreSQL", "MongoDB",
]


class WeWorkRemotelyScraper(BaseScraper):
    platform = "weworkremotely"

    async def scrape(self) -> List[JobCreate]:
        all_jobs: List[JobCreate] = []
        seen: set[str] = set()

        for feed_url in RSS_URLS:
            resp = await self._get(feed_url)
            if resp is None:
                continue

            parsed = feedparser.parse(resp.text)
            for entry in parsed.entries:
                url = (getattr(entry, "link", "") or "").split("?")[0]
                if not url or url in seen:
                    continue
                seen.add(url)

                title = getattr(entry, "title", "") or ""
                summary = getattr(entry, "summary", "") or ""

                if not self.is_programming_related(title, summary):
                    continue

                # العنوان غالباً بصيغة "Company: Title - Remote"
                # نفصل الشركة
                client_name = None
                parts = title.split(":", 1)
                if len(parts) == 2:
                    client_name = parts[0].strip()
                    clean_title = parts[1].strip()
                else:
                    clean_title = title

                published_at = _parse_published(entry)
                skills = self.extract_skills(
                    f"{title} {summary}", KNOWN_SKILLS
                )

                all_jobs.append(
                    self.normalize_job(
                        title=clean_title,
                        description=summary,
                        url=url,
                        published_at=published_at,
                        skills=skills,
                        client_name=client_name,
                        currency="USD",
                    )
                )
        return all_jobs


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

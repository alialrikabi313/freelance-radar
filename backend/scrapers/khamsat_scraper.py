"""خمسات Scraper — قسم طلبات الخدمات المتعلقة بتطوير تطبيقات الموبايل."""
from __future__ import annotations

import logging
from typing import List
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from models.job import JobCreate

from .base_scraper import BaseScraper
from .mostaql_scraper import (
    _parse_int,
    _parse_mostaql_budget,
    _parse_relative_arabic_time,
    _text_of,
)

logger = logging.getLogger(__name__)


BASE_URL = "https://khamsat.com"
REQUESTS_URL = (
    "https://khamsat.com/community/requests?category=programming"
)

KNOWN_SKILLS = [
    "Flutter", "فلاتر", "React Native", "Android", "اندرويد",
    "iOS", "آيفون", "Firebase", "تطبيق موبايل", "تطبيق جوال",
    "Dart", "Java", "Kotlin",
]


class KhamsatScraper(BaseScraper):
    platform = "khamsat"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for page in range(1, 4):
            url = f"{REQUESTS_URL}&page={page}"
            resp = await self._get(url)
            if resp is None:
                continue

            soup = BeautifulSoup(resp.text, "lxml")
            cards = soup.select(
                "table.table-requests tbody tr"
            ) or soup.select("tr.request")

            for card in cards:
                title_tag = card.select_one("h3 a") or card.select_one(
                    "a.request-title"
                )
                if not title_tag:
                    continue
                title = title_tag.get_text(strip=True)
                href = title_tag.get("href") or ""
                request_url = urljoin(BASE_URL, href).split("?")[0]
                if not request_url or request_url in seen:
                    continue
                seen.add(request_url)

                desc_tag = card.select_one(".request-brief") or card.select_one(
                    "p.brief"
                )
                description = desc_tag.get_text(" ", strip=True) if desc_tag else ""

                if not self.is_mobile_related(title, description):
                    continue

                budget_text = _text_of(card, ".budget") or _text_of(
                    card, ".request-budget"
                )
                budget_min, budget_max, currency = _parse_mostaql_budget(budget_text)

                offers_text = _text_of(card, ".offers") or _text_of(
                    card, ".request-offers"
                )
                proposals_count = _parse_int(offers_text)

                time_text = _text_of(card, "time") or _text_of(card, ".date")
                published_at = _parse_relative_arabic_time(time_text)

                skills = self.extract_skills(
                    f"{title} {description}", KNOWN_SKILLS
                )

                jobs.append(
                    self.normalize_job(
                        title=title,
                        description=description,
                        url=request_url,
                        published_at=published_at,
                        budget_min=budget_min,
                        budget_max=budget_max,
                        currency=currency,
                        proposals_count=proposals_count,
                        skills=skills,
                    )
                )
        return jobs

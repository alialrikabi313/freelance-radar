"""مستقل Scraper — web scraping عبر httpx + BeautifulSoup."""
from __future__ import annotations

import logging
import re
from datetime import datetime, timedelta
from typing import List, Optional
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


BASE_URL = "https://mostaql.com"
LISTING_URL = (
    "https://mostaql.com/projects?category=development&sort=latest"
)

ARABIC_SKILLS = [
    "Flutter", "فلاتر", "React Native", "Dart", "Android", "اندرويد",
    "iOS", "آيفون", "Firebase", "Kotlin", "Swift",
    "برمجة تطبيقات", "تطبيق موبايل", "تطبيق جوال", "Java",
    "REST API", "Google Maps", "Push Notifications",
]


class MostaqlScraper(BaseScraper):
    platform = "mostaql"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for page in range(1, 4):  # أول 3 صفحات
            url = f"{LISTING_URL}&page={page}"
            resp = await self._get(url)
            if resp is None:
                continue

            soup = BeautifulSoup(resp.text, "lxml")
            cards = soup.select("tr.project-row") or soup.select(
                "table.projects-list tbody tr"
            )

            for card in cards:
                title_tag = card.select_one("h2.project-title__title a") or card.select_one(
                    "a.project-title"
                )
                if not title_tag:
                    continue
                title = title_tag.get_text(strip=True)
                href = title_tag.get("href") or ""
                project_url = urljoin(BASE_URL, href).split("?")[0]
                if not project_url or project_url in seen:
                    continue
                seen.add(project_url)

                desc_tag = card.select_one("p.project__brief") or card.select_one(
                    ".project-brief"
                )
                description = desc_tag.get_text(" ", strip=True) if desc_tag else ""

                if not self.is_mobile_related(title, description):
                    continue

                budget_text = _text_of(card, "li.list-meta__budget") or _text_of(
                    card, ".project__meta-budget"
                )
                budget_min, budget_max, currency = _parse_mostaql_budget(budget_text)

                offers_text = _text_of(card, "li.list-meta__offers") or _text_of(
                    card, ".project__meta-offers"
                )
                proposals_count = _parse_int(offers_text)

                time_text = _text_of(card, "li.list-meta__time time") or _text_of(
                    card, "time"
                )
                published_at = _parse_relative_arabic_time(time_text)

                skills = self.extract_skills(
                    f"{title} {description}", ARABIC_SKILLS
                )

                jobs.append(
                    self.normalize_job(
                        title=title,
                        description=description,
                        url=project_url,
                        published_at=published_at,
                        budget_min=budget_min,
                        budget_max=budget_max,
                        currency=currency,
                        proposals_count=proposals_count,
                        skills=skills,
                    )
                )
        return jobs


# ────────────────────────── Helpers ──────────────────────────


def _text_of(node, selector: str) -> str:
    el = node.select_one(selector)
    return el.get_text(" ", strip=True) if el else ""


_BUDGET_RE = re.compile(r"([\d,.]+)\s*(?:-|–|إلى)\s*([\d,.]+)")
_SINGLE_BUDGET_RE = re.compile(r"([\d,.]+)")


def _parse_mostaql_budget(
    text: str,
) -> tuple[Optional[float], Optional[float], str]:
    if not text:
        return None, None, "USD"

    currency = "USD"
    if "$" in text:
        currency = "USD"
    elif "ر.س" in text or "SAR" in text:
        currency = "SAR"
    elif "د.إ" in text or "AED" in text:
        currency = "AED"
    elif "ج.م" in text or "EGP" in text:
        currency = "EGP"

    match = _BUDGET_RE.search(text)
    if match:
        try:
            lo = float(match.group(1).replace(",", ""))
            hi = float(match.group(2).replace(",", ""))
            return lo, hi, currency
        except ValueError:
            pass

    match = _SINGLE_BUDGET_RE.search(text)
    if match:
        try:
            v = float(match.group(1).replace(",", ""))
            return v, v, currency
        except ValueError:
            pass

    return None, None, currency


def _parse_int(text: str) -> Optional[int]:
    if not text:
        return None
    match = re.search(r"\d+", text)
    return int(match.group(0)) if match else None


_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _parse_relative_arabic_time(text: str) -> datetime:
    """يحاول تحويل نص مثل "منذ ساعتين" إلى datetime."""
    if not text:
        return datetime.utcnow()
    t = text.translate(_ARABIC_DIGITS).lower()

    now = datetime.utcnow()
    match = re.search(r"(\d+)", t)
    n = int(match.group(1)) if match else 1

    if "دقيق" in t or "minute" in t:
        return now - timedelta(minutes=n)
    if "ساعة" in t or "ساعت" in t or "hour" in t:
        return now - timedelta(hours=n)
    if "يوم" in t or "يومين" in t or "day" in t:
        return now - timedelta(days=n)
    if "أسبوع" in t or "اسبوع" in t or "week" in t:
        return now - timedelta(weeks=n)
    if "شهر" in t or "شهرين" in t or "month" in t:
        return now - timedelta(days=30 * n)

    return now

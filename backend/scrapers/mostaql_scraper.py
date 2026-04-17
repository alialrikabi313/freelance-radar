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
LISTING_URL = "https://mostaql.com/projects?category=development&sort=latest"

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

        for page in range(1, 11):  # أول 10 صفحات (~250 فرصة)
            url = f"{LISTING_URL}&page={page}"
            resp = await self._get(url)
            if resp is None:
                continue

            soup = BeautifulSoup(resp.text, "lxml")
            rows = soup.select("tr.project-row")

            for row in rows:
                title_link = row.select_one("h2 a")
                if not title_link:
                    continue

                title = title_link.get_text(strip=True)
                href = title_link.get("href") or ""
                project_url = urljoin(BASE_URL, href).split("?")[0]
                if not project_url or project_url in seen:
                    continue
                seen.add(project_url)

                # الوصف
                brief = row.select_one(".project__brief")
                description = brief.get_text(" ", strip=True) if brief else ""

                # فلتر مبدئي — مشاريع الموبايل فقط
                if not self.is_programming_related(title, description):
                    continue

                # الوقت: time[datetime="2026-04-16 22:02:58"]
                published_at = _parse_time_element(row.select_one("time"))

                # عدد العروض: من li الأخير في .list-meta-items
                proposals_count = _parse_proposals(row)

                # المهارات
                skills = self.extract_skills(
                    f"{title} {description}", ARABIC_SKILLS
                )

                jobs.append(
                    self.normalize_job(
                        title=title,
                        description=description,
                        url=project_url,
                        published_at=published_at,
                        # الميزانية لا تظهر في صفحة القائمة — نتركها فارغة
                        budget_min=None,
                        budget_max=None,
                        currency="USD",
                        proposals_count=proposals_count,
                        skills=skills,
                    )
                )

        return jobs


# ────────────────────────── Helpers ──────────────────────────


def _parse_time_element(time_el) -> datetime:
    """قراءة datetime attribute من <time> tag."""
    if time_el is None:
        return datetime.utcnow()
    dt_str = time_el.get("datetime") or ""
    try:
        # Format: "2026-04-16 22:02:58"
        return datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
    except (ValueError, TypeError):
        pass
    return datetime.utcnow()


_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _parse_proposals(row) -> Optional[int]:
    """آخر li في .list-meta-items يحتوي 'X عرض'."""
    meta = row.select_one(".list-meta-items")
    if meta is None:
        return None
    for li in meta.select("li"):
        text = li.get_text(" ", strip=True).translate(_ARABIC_DIGITS)
        match = re.search(r"(\d+)\s*عرض", text)
        if match:
            try:
                return int(match.group(1))
            except ValueError:
                pass
    return None


def _parse_relative_arabic_time(text: str) -> datetime:
    """Fallback: يحوّل نص مثل "منذ ساعتين" إلى datetime (يستخدمه Khamsat)."""
    if not text:
        return datetime.utcnow()
    t = text.translate(_ARABIC_DIGITS).lower()

    now = datetime.utcnow()
    match = re.search(r"(\d+)", t)
    n = int(match.group(1)) if match else 1

    if "دقيق" in t or "minute" in t:
        return now - timedelta(minutes=n)
    if "ساع" in t or "hour" in t:
        return now - timedelta(hours=n)
    if "يوم" in t or "day" in t:
        return now - timedelta(days=n)
    if "أسبوع" in t or "اسبوع" in t or "week" in t:
        return now - timedelta(weeks=n)
    if "شهر" in t or "month" in t:
        return now - timedelta(days=30 * n)

    return now

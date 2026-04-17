"""مستقل Scraper — listing + detail page enrichment."""
from __future__ import annotations

import asyncio
import json
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
    "React", "Vue", "Angular", "Node.js", "Python", "Django",
    "Laravel", "PHP", "WordPress", "MongoDB", "MySQL",
]


# مدى موازي للـ detail fetching (كي لا نُحظر)
DETAIL_CONCURRENCY = 4


class MostaqlScraper(BaseScraper):
    platform = "mostaql"

    async def scrape(self) -> List[JobCreate]:
        listings = await self._scrape_listings()
        if not listings:
            return []

        # غناء موازي: جلب تفاصيل كل مشروع
        sem = asyncio.Semaphore(DETAIL_CONCURRENCY)

        async def enrich(job: JobCreate) -> JobCreate:
            async with sem:
                return await self._enrich_detail(job)

        enriched = await asyncio.gather(
            *(enrich(j) for j in listings), return_exceptions=False
        )
        return list(enriched)

    async def _scrape_listings(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()

        for page in range(1, 11):
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
                url = urljoin(BASE_URL, href).split("?")[0]
                if not url or url in seen:
                    continue
                seen.add(url)

                brief = row.select_one(".project__brief")
                description = brief.get_text(" ", strip=True) if brief else ""

                if not self.is_programming_related(title, description):
                    continue

                published_at = _parse_time_element(row.select_one("time"))
                proposals_count = _parse_proposals(row)
                skills = self.extract_skills(
                    f"{title} {description}", ARABIC_SKILLS
                )

                jobs.append(
                    self.normalize_job(
                        title=title,
                        description=description,
                        url=url,
                        published_at=published_at,
                        budget_min=None,
                        budget_max=None,
                        currency="USD",
                        proposals_count=proposals_count,
                        skills=skills,
                    )
                )
        return jobs

    async def _enrich_detail(self, job: JobCreate) -> JobCreate:
        """يجلب صفحة المشروع ويستخرج الميزانية + الوصف الكامل من JSON-LD."""
        resp = await self._get(job.url)
        if resp is None:
            return job

        soup = BeautifulSoup(resp.text, "lxml")

        # استخرج JSON-LD (schema.org JobPosting)
        budget_min, budget_max, full_desc, currency = None, None, None, "USD"
        for script in soup.select('script[type="application/ld+json"]'):
            if not script.string:
                continue
            try:
                data = json.loads(script.string)
            except (json.JSONDecodeError, TypeError):
                continue
            # قد يكون list of dicts أو dict
            if isinstance(data, list):
                data = next(
                    (d for d in data if isinstance(d, dict) and
                     "JobPosting" in str(d.get("@type", ""))),
                    None
                )
                if data is None:
                    continue
            if not isinstance(data, dict):
                continue
            if "JobPosting" not in str(data.get("@type", "")):
                continue

            salary = data.get("baseSalary") or {}
            if isinstance(salary, dict):
                val = salary.get("value")
                if isinstance(val, dict):
                    budget_min = _to_float(val.get("minValue"))
                    budget_max = _to_float(val.get("maxValue") or val.get("value"))
                else:
                    budget_max = _to_float(val)
                    budget_min = budget_max
                currency = salary.get("currency") or data.get(
                    "salaryCurrency"
                ) or "USD"

            desc = data.get("description")
            if desc:
                full_desc = self.clean_text(str(desc), limit=2000)
            break

        # fallback: HTML .meta-row (الميزانية)
        if budget_max is None:
            for row in soup.select(".meta-row"):
                label = row.select_one(".meta-label")
                value = row.select_one(".meta-value") or row
                if not label:
                    continue
                if "الميزانية" in label.get_text():
                    text = (value.get_text(" ", strip=True)
                            .replace(label.get_text(strip=True), ""))
                    budget_min, budget_max, currency = _parse_budget_text(text)
                    break

        # إنشاء نسخة محدّثة من الـ job
        updated_desc = full_desc or job.description or ""
        return JobCreate(
            platform=job.platform,
            title=job.title,
            description=updated_desc,
            url=job.url,
            published_at=job.published_at,
            budget_min=budget_min or job.budget_min,
            budget_max=budget_max or job.budget_max,
            currency=currency or job.currency,
            skills=job.skills,
            client_name=job.client_name,
            client_rating=job.client_rating,
            client_jobs_posted=job.client_jobs_posted,
            proposals_count=job.proposals_count,
            is_hourly=job.is_hourly,
            country=job.country,
        )


# ────────────────────────── Helpers ──────────────────────────


def _to_float(v) -> Optional[float]:
    if v in (None, ""):
        return None
    try:
        f = float(str(v).replace(",", ""))
        return f if f > 0 else None
    except (TypeError, ValueError):
        return None


_BUDGET_RE = re.compile(r"\$?\s*([\d,.]+)\s*(?:-|إلى|–)\s*\$?\s*([\d,.]+)")
_SINGLE_BUDGET = re.compile(r"\$?\s*([\d,.]+)")


def _parse_budget_text(text: str) -> tuple[Optional[float], Optional[float], str]:
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

    m = _BUDGET_RE.search(text)
    if m:
        try:
            return (
                float(m.group(1).replace(",", "")),
                float(m.group(2).replace(",", "")),
                currency,
            )
        except ValueError:
            pass
    m2 = _SINGLE_BUDGET.search(text)
    if m2:
        try:
            v = float(m2.group(1).replace(",", ""))
            return v, v, currency
        except ValueError:
            pass
    return None, None, currency


def _parse_time_element(time_el) -> datetime:
    if time_el is None:
        return datetime.utcnow()
    dt_str = time_el.get("datetime") or ""
    try:
        return datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
    except (ValueError, TypeError):
        pass
    return datetime.utcnow()


_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def _parse_proposals(row) -> Optional[int]:
    meta = row.select_one(".list-meta-items")
    if meta is None:
        return None
    for li in meta.select("li"):
        text = li.get_text(" ", strip=True).translate(_ARABIC_DIGITS)
        m = re.search(r"(\d+)\s*عرض", text)
        if m:
            try:
                return int(m.group(1))
            except ValueError:
                pass
    return None


def _parse_relative_arabic_time(text: str) -> datetime:
    if not text:
        return datetime.utcnow()
    t = text.translate(_ARABIC_DIGITS).lower()
    now = datetime.utcnow()
    m = re.search(r"(\d+)", t)
    n = int(m.group(1)) if m else 1
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

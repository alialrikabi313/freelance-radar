"""Adzuna Scraper — وظائف عالمية عبر Adzuna Public API.

Docs: https://developer.adzuna.com/overview
يتطلب ADZUNA_APP_ID + ADZUNA_APP_KEY (مجاني بعد تسجيل).
يغطي 19 دولة. نسحب IT/Engineering من دول مختارة كل جولة.
"""
from __future__ import annotations

import asyncio
import logging
import re
from datetime import datetime
from typing import List, Optional

from config import settings
from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_BASE = "https://api.adzuna.com/v1/api/jobs/{country}/search/1"

# نسحب من الدول الأكبر للـ IT
# GB/US: أكبر سوق، DE/NL: أوروبا، AU/CA: إنجليزية أخرى
COUNTRIES = ["gb", "us", "de", "nl", "au", "ca"]

# كلمات بحث — يرسل query واحد للـ API لكل دولة
SEARCH_QUERIES = [
    "flutter developer",
    "mobile app developer",
    "react developer",
    "software engineer remote",
]

KNOWN_SKILLS = [
    "Flutter", "React Native", "Swift", "Kotlin", "Android", "iOS",
    "React", "Vue", "Angular", "TypeScript", "JavaScript",
    "Python", "Django", "FastAPI", "Node.js",
    "Go", "Rust", "Ruby", "Rails", "PHP", "Laravel",
    "AWS", "Docker", "Kubernetes", "PostgreSQL", "MongoDB",
]


class AdzunaScraper(BaseScraper):
    platform = "adzuna"

    async def scrape(self) -> List[JobCreate]:
        if not settings.adzuna_app_id or not settings.adzuna_app_key:
            logger.info("[adzuna] credentials not set; skipping")
            return []

        jobs: List[JobCreate] = []
        seen: set[str] = set()

        # تسلسلياً مع delay الموجود في _get (تجنب HTTP 429)
        for country in COUNTRIES:
            for query in SEARCH_QUERIES:
                batch = await self._fetch(country, query)
                for job in batch:
                    if job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)
        return jobs

    async def _fetch(self, country: str, query: str) -> List[JobCreate]:
        url = API_BASE.format(country=country)
        resp = await self._get(
            url,
            params={
                "app_id": settings.adzuna_app_id,
                "app_key": settings.adzuna_app_key,
                "results_per_page": "50",
                "what": query,
                "category": "it-jobs",
                "sort_by": "date",
                "content-type": "application/json",
            },
        )
        if resp is None:
            return []
        try:
            data = resp.json()
        except ValueError:
            return []

        jobs: List[JobCreate] = []
        for item in data.get("results", []) or []:
            title = item.get("title") or ""
            description = item.get("description") or ""

            if not self.is_programming_related(title, description):
                continue

            # Adzuna يضع redirect_url يحوّل لصفحة الإعلان الأصلية
            url_field = item.get("redirect_url") or ""
            if not url_field:
                continue

            budget_min = _to_float(item.get("salary_min"))
            budget_max = _to_float(item.get("salary_max"))
            # Adzuna يعطي الرواتب السنوية — نتركها كما هي لتبقى مقارنة
            # ولكن عندما يكون predicted نعتبرها تقديراً
            # is_predicted = bool(item.get("salary_is_predicted"))

            published_at = _parse_date(item.get("created"))
            currency = _country_currency(country)

            location_obj = item.get("location") or {}
            country_name = None
            if isinstance(location_obj, dict):
                area = location_obj.get("area") or []
                if area:
                    country_name = area[0]

            company_obj = item.get("company") or {}
            client_name = (
                company_obj.get("display_name") if isinstance(company_obj, dict)
                else None
            )

            skills = self.extract_skills(
                f"{title} {description}", KNOWN_SKILLS
            )

            jobs.append(
                self.normalize_job(
                    title=_clean_title(title),
                    description=description,
                    url=url_field,
                    published_at=published_at,
                    budget_min=budget_min,
                    budget_max=budget_max,
                    currency=currency,
                    skills=skills,
                    client_name=client_name,
                    country=country_name,
                    is_hourly=False,
                )
            )
        return jobs


# ────────────────────────── helpers ──────────────────────────


_CURRENCY_BY_COUNTRY = {
    "gb": "GBP",
    "us": "USD",
    "de": "EUR",
    "nl": "EUR",
    "fr": "EUR",
    "es": "EUR",
    "it": "EUR",
    "au": "AUD",
    "ca": "CAD",
    "nz": "NZD",
    "ch": "CHF",
    "pl": "PLN",
    "sg": "SGD",
    "in": "INR",
    "br": "BRL",
    "mx": "MXN",
    "ru": "RUB",
    "za": "ZAR",
    "at": "EUR",
}


def _country_currency(country: str) -> str:
    return _CURRENCY_BY_COUNTRY.get(country.lower(), "USD")


def _to_float(v) -> Optional[float]:
    if v in (None, "", 0, "0"):
        return None
    try:
        f = float(v)
        return f if f > 0 else None
    except (TypeError, ValueError):
        return None


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()


def _clean_title(title: str) -> str:
    # Adzuna أحياناً يضع "<strong>" tags في العنوان
    return re.sub(r"<[^>]+>", "", title).strip()

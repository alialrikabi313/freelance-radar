"""LinkedIn Scraper — عبر Guest Jobs API العام.

يستخدم endpoint غير موثق رسمياً لكن public:
  /jobs-guest/jobs/api/seeMoreJobPostings/search

ملاحظات مهمة:
  - LinkedIn يفرض rate limiting صارم. نحافظ على معدل منخفض.
  - لو طلع HTTP 429 أو 999، نوقف الجولة الحالية لتجنب حظر مؤقت.
  - لا يوجد salary/description في listing — فقط title/company/location/url.
"""
from __future__ import annotations

import asyncio
import logging
import random
import re
from datetime import datetime
from typing import List, Optional

import httpx
from bs4 import BeautifulSoup

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

API_URL = "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search"
DETAIL_URL = "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/{job_id}"

# استعلامات متنوعة — نركّز على remote + keywords تقنية
# f_WT=2 = Remote only
QUERIES = [
    {"keywords": "flutter developer", "f_WT": 2},
    {"keywords": "react native developer", "f_WT": 2},
    {"keywords": "mobile developer", "f_WT": 2},
    {"keywords": "software engineer remote", "f_WT": 2},
]
PAGES_PER_QUERY = 2  # 20 فرصة لكل query


class LinkedInScraper(BaseScraper):
    platform = "linkedin"

    async def scrape(self) -> List[JobCreate]:
        jobs: List[JobCreate] = []
        seen: set[str] = set()
        rate_limited = False

        for query in QUERIES:
            if rate_limited:
                break
            for page in range(PAGES_PER_QUERY):
                start = page * 10
                batch, throttled = await self._fetch(query, start)
                if throttled:
                    logger.warning("[linkedin] rate-limited; aborting round")
                    rate_limited = True
                    break
                if not batch:
                    break
                for job in batch:
                    if job.url in seen:
                        continue
                    seen.add(job.url)
                    jobs.append(job)
                await asyncio.sleep(random.uniform(3, 6))

        # غناء: جلب وصف كل وظيفة من detail endpoint
        if jobs and not rate_limited:
            jobs = await self._enrich_descriptions(jobs)
        return jobs

    async def _enrich_descriptions(
        self, jobs: List[JobCreate]
    ) -> List[JobCreate]:
        """يجلب الوصف لكل وظيفة. يتوقف عند أول rate limit."""
        enriched: List[JobCreate] = []
        throttled = False
        for job in jobs:
            if throttled:
                enriched.append(job)
                continue
            job_id = _extract_job_id(job.url)
            if not job_id:
                enriched.append(job)
                continue
            desc, is_throttled = await self._fetch_description(job_id)
            if is_throttled:
                throttled = True
                enriched.append(job)
                continue
            if desc:
                enriched.append(
                    JobCreate(
                        platform=job.platform,
                        title=job.title,
                        description=desc,
                        url=job.url,
                        published_at=job.published_at,
                        budget_min=job.budget_min,
                        budget_max=job.budget_max,
                        currency=job.currency,
                        skills=job.skills,
                        client_name=job.client_name,
                        client_rating=job.client_rating,
                        client_jobs_posted=job.client_jobs_posted,
                        proposals_count=job.proposals_count,
                        is_hourly=job.is_hourly,
                        country=job.country,
                    )
                )
            else:
                enriched.append(job)
        return enriched

    async def _fetch_description(
        self, job_id: str
    ) -> tuple[str, bool]:
        await self._polite_delay()
        headers = {
            "User-Agent": self._random_user_agent(),
            "Accept": "text/html",
            "Referer": "https://www.linkedin.com/jobs/search/",
        }
        try:
            async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
                resp = await client.get(
                    DETAIL_URL.format(job_id=job_id), headers=headers
                )
                if resp.status_code in (429, 999, 403):
                    return "", True
                if resp.status_code != 200:
                    return "", False
                soup = BeautifulSoup(resp.text, "lxml")
                desc_el = soup.select_one(
                    ".show-more-less-html__markup"
                ) or soup.select_one(".description__text")
                if desc_el:
                    return self.clean_text(
                        desc_el.get_text(" ", strip=True), limit=2000
                    ), False
        except httpx.HTTPError:
            return "", False
        return "", False

    async def _fetch(
        self, base_params: dict, start: int
    ) -> tuple[List[JobCreate], bool]:
        """يُرجع (jobs, rate_limited_flag)."""
        await self._polite_delay()
        params = {**base_params, "start": start}
        headers = {
            "User-Agent": self._random_user_agent(),
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": "https://www.linkedin.com/jobs/search/",
        }
        try:
            async with httpx.AsyncClient(
                timeout=20, follow_redirects=True
            ) as client:
                resp = await client.get(API_URL, params=params, headers=headers)
                # LinkedIn يستخدم 429 و أحياناً 999 للـ rate limit
                if resp.status_code in (429, 999, 403):
                    return [], True
                if resp.status_code >= 400:
                    logger.warning(
                        "[linkedin] HTTP %s for %s",
                        resp.status_code, params,
                    )
                    return [], False
                html = resp.text
        except httpx.HTTPError as exc:
            logger.warning("[linkedin] request failed: %s", exc)
            return [], False

        return self._parse(html), False

    def _parse(self, html: str) -> List[JobCreate]:
        soup = BeautifulSoup(html, "lxml")
        jobs: List[JobCreate] = []

        for li in soup.select("li"):
            title_el = li.select_one("h3") or li.select_one(
                ".base-search-card__title"
            )
            company_el = li.select_one("h4") or li.select_one(
                ".base-search-card__subtitle"
            )
            link_el = li.select_one("a.base-card__full-link") or li.select_one(
                "a[href*='/jobs/view/']"
            )
            if not (title_el and link_el):
                continue

            title = title_el.get_text(strip=True)
            if not self.is_programming_related(title):
                continue

            url = (link_el.get("href") or "").split("?")[0]
            if not url:
                continue

            company = company_el.get_text(strip=True) if company_el else None

            location_el = li.select_one(".job-search-card__location")
            location = location_el.get_text(strip=True) if location_el else None

            date_el = li.select_one("time")
            published_at = _parse_date(
                date_el.get("datetime") if date_el else None
            )

            jobs.append(
                self.normalize_job(
                    title=title,
                    description="",  # LinkedIn لا يعرض الوصف في القائمة
                    url=url,
                    published_at=published_at,
                    client_name=company,
                    country=location,
                    currency="USD",
                )
            )
        return jobs


def _parse_date(raw) -> datetime:
    if not raw:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00")).replace(
            tzinfo=None
        )
    except (ValueError, TypeError):
        return datetime.utcnow()


def _extract_job_id(url: str) -> str:
    """استخرج job ID من URL مثل /jobs/view/flutter-developer-at-xyz-4401340089."""
    m = re.search(r"-(\d{7,})(?:/|$|\?)", url)
    return m.group(1) if m else ""

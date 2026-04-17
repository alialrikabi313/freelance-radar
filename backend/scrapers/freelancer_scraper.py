"""Freelancer.com Scraper — عبر الـ Public API."""
from __future__ import annotations

import logging
from datetime import datetime
from typing import List, Optional

from config import settings
from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


# IDs للوظائف المتعلقة بتطوير تطبيقات الموبايل في Freelancer
# المرجع: https://www.freelancer.com/api/projects/0.1/jobs/
MOBILE_JOB_NAMES = [
    "mobile-app-development",
    "flutter",
    "android",
    "iphone",
    "ipad",
    "react-native",
]


class FreelancerScraper(BaseScraper):
    platform = "freelancer"

    API_URL = "https://www.freelancer.com/api/projects/0.1/projects/active/"
    JOBS_LIST_URL = "https://www.freelancer.com/api/projects/0.1/jobs/"

    async def scrape(self) -> List[JobCreate]:
        job_ids = await self._resolve_job_ids()
        if not job_ids:
            logger.warning(
                "[freelancer] could not resolve job ids; skipping this run"
            )
            return []

        headers: dict[str, str] = {}
        if settings.freelancer_api_key:
            headers["Freelancer-OAuth-V1"] = settings.freelancer_api_key

        params: list[tuple[str, str]] = [
            ("compact", "true"),
            ("job_details", "true"),
            ("full_description", "true"),
            ("user_details", "true"),
            ("user_country_details", "true"),
            ("sort_field", "time_submitted"),
            ("reverse_sort", "true"),
            ("project_types[]", "fixed"),
            ("project_types[]", "hourly"),
            ("limit", "50"),
        ]
        for jid in job_ids:
            params.append(("jobs[]", str(jid)))

        # نمرّر params كقائمة tuples لأن httpx يدعم المفاتيح المكررة
        # (jobs[], project_types[]) — تحويلها إلى dict سيُسقطها.
        resp = await self._get(self.API_URL, params=params, headers=headers)
        if resp is None:
            return []

        try:
            data = resp.json()
        except ValueError:
            logger.warning("[freelancer] non-JSON response")
            return []

        result = data.get("result") or {}
        projects = result.get("projects") or []
        users = {
            str(u.get("id")): u for u in (result.get("users") or {}).values()
        } if isinstance(result.get("users"), dict) else {}
        jobs_catalog = {
            j.get("id"): j for j in (result.get("jobs") or {}).values()
        } if isinstance(result.get("jobs"), dict) else {}

        jobs: List[JobCreate] = []
        for project in projects:
            job = self._project_to_job(project, users, jobs_catalog)
            if job:
                jobs.append(job)
        return jobs

    async def _resolve_job_ids(self) -> list[int]:
        """تحويل أسماء الوظائف (مثل mobile-app-development) إلى IDs."""
        params = [("limit", "500"), ("compact", "true")]
        resp = await self._get(self.JOBS_LIST_URL, params=params)
        if resp is None:
            return []
        try:
            payload = resp.json()
        except ValueError:
            return []
        result = payload.get("result") or []
        if isinstance(result, dict):
            result = list(result.values())
        wanted = {n.lower() for n in MOBILE_JOB_NAMES}
        ids: list[int] = []
        for job_def in result:
            seo = (job_def.get("seo_url") or "").lower()
            name = (job_def.get("name") or "").lower()
            if seo in wanted or name.replace(" ", "-") in wanted:
                ids.append(job_def["id"])
        return ids

    def _project_to_job(
        self,
        project: dict,
        users: dict,
        jobs_catalog: dict,
    ) -> Optional[JobCreate]:
        title = project.get("title") or ""
        description = project.get("description") or project.get(
            "preview_description"
        ) or ""

        if not self.is_mobile_related(title, description):
            return None

        budget = project.get("budget") or {}
        budget_min = _to_float(budget.get("minimum"))
        budget_max = _to_float(budget.get("maximum"))
        currency_obj = project.get("currency") or {}
        currency = currency_obj.get("code") or "USD"
        is_hourly = (project.get("type") or "").lower() == "hourly"

        seo_url = project.get("seo_url") or ""
        if seo_url.startswith("http"):
            url = seo_url
        elif seo_url:
            url = f"https://www.freelancer.com/projects/{seo_url}"
        else:
            pid = project.get("id")
            url = f"https://www.freelancer.com/projects/{pid}" if pid else ""

        if not url:
            return None

        submit_ts = project.get("submitdate")
        published_at = (
            datetime.fromtimestamp(submit_ts) if isinstance(submit_ts, (int, float))
            else datetime.utcnow()
        )

        # Skills
        jobs_field = project.get("jobs") or []
        skills: List[str] = []
        for j in jobs_field:
            if isinstance(j, dict):
                skills.append(j.get("name", ""))
            else:
                catalog = jobs_catalog.get(j)
                if catalog:
                    skills.append(catalog.get("name", ""))
        skills = [s for s in skills if s][:10]

        # Client info
        owner_id = project.get("owner_id")
        owner = users.get(str(owner_id)) if owner_id else None
        client_name: Optional[str] = None
        client_rating: Optional[float] = None
        client_jobs_posted: Optional[int] = None
        country: Optional[str] = None
        if owner:
            client_name = owner.get("public_name") or owner.get("username")
            reputation = (owner.get("employer_reputation") or {}).get(
                "entire_history"
            ) or {}
            client_rating = _to_float(reputation.get("overall"))
            client_jobs_posted = reputation.get("reviews") or reputation.get(
                "complete"
            )
            country = (owner.get("location") or {}).get("country", {}).get("name")

        proposals_count = project.get("bid_stats", {}).get("bid_count")

        return self.normalize_job(
            title=title,
            description=description,
            url=url,
            published_at=published_at,
            budget_min=budget_min,
            budget_max=budget_max,
            currency=currency,
            skills=skills,
            client_name=client_name,
            client_rating=client_rating,
            client_jobs_posted=client_jobs_posted,
            proposals_count=proposals_count,
            is_hourly=is_hourly,
            country=country,
        )


def _to_float(value) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

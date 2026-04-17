"""Reddit Scraper — subreddits مخصصة للفريلانس والتوظيف.

Reddit يوفر JSON API عامة بدون auth:
  https://www.reddit.com/r/{subreddit}/new.json?limit=100

نفلتر posts بعلامة [HIRING] للتركيز على الفرص وليس طلبات التوظيف.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import List, Optional

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

SUBREDDITS = [
    # subreddit, require_hiring_tag
    ("forhire", True),        # فقط [HIRING] (شركات توظف)
    ("jobbit", True),
    ("slavelabour", True),    # gigs صغيرة
    ("remotejs", False),      # remote JS jobs
]


# نبحث عن [HIRING] أو (HIRING) فقط — نستثني [FOR HIRE] (فريلانسر يعرض نفسه)
_HIRING_RE = re.compile(
    r"\[\s*hiring\s*\]|\(\s*hiring\s*\)", re.IGNORECASE
)
# كل post بعلامة [FOR HIRE] نتجاهله (هذا فريلانسر يعرض خدماته)
_FOR_HIRE_RE = re.compile(
    r"\[\s*for\s*hire\s*\]|\(\s*for\s*hire\s*\)", re.IGNORECASE
)

# استخراج الميزانية من نص العنوان أو post body
_BUDGET_RE = re.compile(
    r"\$\s?([\d,]+)(?:\s*/\s*(?:hr|hour|day))?(?:\s*(?:-|to|–)\s*\$?\s*([\d,]+))?",
    re.IGNORECASE,
)


class RedditScraper(BaseScraper):
    platform = "reddit"

    async def scrape(self) -> List[JobCreate]:
        all_jobs: List[JobCreate] = []
        seen: set[str] = set()

        for subreddit, require_hiring in SUBREDDITS:
            resp = await self._get(
                f"https://www.reddit.com/r/{subreddit}/new.json",
                params={"limit": "100"},
            )
            if resp is None:
                continue
            try:
                data = resp.json()
            except ValueError:
                continue

            posts = data.get("data", {}).get("children", []) or []
            for p in posts:
                job = self._parse_post(p.get("data", {}), subreddit, require_hiring)
                if job is None or job.url in seen:
                    continue
                seen.add(job.url)
                all_jobs.append(job)
        return all_jobs

    def _parse_post(
        self, post: dict, subreddit: str, require_hiring: bool
    ) -> Optional[JobCreate]:
        title = post.get("title") or ""
        body = post.get("selftext") or ""
        permalink = post.get("permalink") or ""

        if not title or not permalink:
            return None

        # نستثني [FOR HIRE] — دي فريلانسرز يعرضون خدماتهم
        if _FOR_HIRE_RE.search(title):
            return None

        # نحتاج علامة HIRING للـ subreddits المختلطة (forhire, jobbit...)
        if require_hiring and not _HIRING_RE.search(title):
            return None

        # نطمئن أن هذا بوست برمجي
        if not self.is_programming_related(title, body):
            return None

        # تنظيف العنوان من علامة [HIRING]
        clean_title = re.sub(
            r"\[\s*hiring\s*\]|\(\s*hiring\s*\)",
            "",
            title,
            flags=re.IGNORECASE,
        ).strip(" -:")

        url = f"https://www.reddit.com{permalink}"
        author = post.get("author")
        ups = post.get("ups") or 0

        # وقت النشر epoch
        created = post.get("created_utc")
        published_at = (
            datetime.fromtimestamp(float(created))
            if created
            else datetime.utcnow()
        )

        # استخراج ميزانية من العنوان أو body
        budget_min, budget_max = _parse_budget(f"{title} {body[:400]}")

        return self.normalize_job(
            title=clean_title[:200],
            description=body,
            url=url,
            published_at=published_at,
            budget_min=budget_min,
            budget_max=budget_max,
            currency="USD",
            client_name=author,
            country=f"r/{subreddit}",
            proposals_count=ups if ups else None,
        )


def _parse_budget(text: str) -> tuple[Optional[float], Optional[float]]:
    if not text:
        return None, None
    m = _BUDGET_RE.search(text)
    if not m:
        return None, None
    try:
        lo = float(m.group(1).replace(",", ""))
        hi = float(m.group(2).replace(",", "")) if m.group(2) else lo
        return lo, hi
    except ValueError:
        return None, None

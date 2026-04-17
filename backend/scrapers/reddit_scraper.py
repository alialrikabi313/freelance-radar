"""Reddit Scraper — عبر RSS feeds (لا يحتاج OAuth أبداً).

Reddit JSON API يحظر IPs الـ cloud، لكن RSS يعمل بدون auth.
نبحث عن [HIRING] posts ونستثني [FOR HIRE] (فريلانسرز يعرضون خدماتهم).
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from time import mktime
from typing import List, Optional

import feedparser

from models.job import JobCreate

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


# subreddits — require_hiring_tag إذا كان الـ subreddit مختلط
SUBREDDITS = [
    ("forhire", True),
    ("jobbit", True),
    ("slavelabour", True),
    ("remotejs", False),   # remote JS jobs — كلها فرص
    ("designjobs", True),
    ("freelance_forhire", False),
]


_HIRING_RE = re.compile(
    r"\[\s*hiring\s*\]|\(\s*hiring\s*\)", re.IGNORECASE
)
_FOR_HIRE_RE = re.compile(
    r"\[\s*for\s*hire\s*\]|\(\s*for\s*hire\s*\)", re.IGNORECASE
)
_BUDGET_RE = re.compile(
    r"\$\s?([\d,]+)(?:\s*(?:/\s*(?:hr|hour|day))?)?"
    r"(?:\s*(?:-|to|–)\s*\$?\s*([\d,]+))?",
    re.IGNORECASE,
)


class RedditScraper(BaseScraper):
    platform = "reddit"

    async def scrape(self) -> List[JobCreate]:
        all_jobs: List[JobCreate] = []
        seen: set[str] = set()

        for subreddit, require_hiring in SUBREDDITS:
            url = f"https://www.reddit.com/r/{subreddit}/new/.rss"
            resp = await self._get(url)
            if resp is None:
                continue

            parsed = feedparser.parse(resp.text)
            for entry in parsed.entries:
                job = self._parse_entry(entry, subreddit, require_hiring)
                if job is None or job.url in seen:
                    continue
                seen.add(job.url)
                all_jobs.append(job)
        return all_jobs

    def _parse_entry(
        self, entry, subreddit: str, require_hiring: bool
    ) -> Optional[JobCreate]:
        title = getattr(entry, "title", "") or ""
        link = getattr(entry, "link", "") or ""
        if not title or not link:
            return None

        # نستثني [FOR HIRE] (فريلانسرز يعرضون خدماتهم)
        if _FOR_HIRE_RE.search(title):
            return None

        # نتطلب علامة [HIRING] للـ subreddits المختلطة
        if require_hiring and not _HIRING_RE.search(title):
            return None

        summary = getattr(entry, "summary", "") or ""

        # تأكد أنه برمجي
        if not self.is_programming_related(title, summary):
            return None

        # تنظيف العنوان من [HIRING]
        clean_title = re.sub(
            r"\[\s*hiring\s*\]|\(\s*hiring\s*\)",
            "",
            title,
            flags=re.IGNORECASE,
        ).strip(" -:")

        # وقت النشر
        struct = getattr(entry, "published_parsed", None) or getattr(
            entry, "updated_parsed", None
        )
        published_at = (
            datetime.fromtimestamp(mktime(struct))
            if struct
            else datetime.utcnow()
        )

        # الميزانية من العنوان أو summary
        budget_min, budget_max = _parse_budget(f"{title} {summary[:400]}")

        author = getattr(entry, "author", "") or ""
        # Reddit يعطي author بصيغة "/u/username"
        client_name = author.replace("/u/", "").strip() or None

        return self.normalize_job(
            title=clean_title[:200],
            description=summary,
            url=link,
            published_at=published_at,
            budget_min=budget_min,
            budget_max=budget_max,
            currency="USD",
            client_name=client_name,
            country=f"r/{subreddit}",
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

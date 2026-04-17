"""موديل المشروع — Pydantic فقط (التخزين في Firestore)."""
from __future__ import annotations

import hashlib
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class JobCreate(BaseModel):
    """يستخدم عند إنشاء Job من مخرجات scraper."""

    platform: str
    title: str
    description: str = ""
    budget_min: Optional[float] = None
    budget_max: Optional[float] = None
    currency: str = "USD"
    skills: List[str] = Field(default_factory=list)
    client_name: Optional[str] = None
    client_rating: Optional[float] = None
    client_jobs_posted: Optional[int] = None
    proposals_count: Optional[int] = None
    url: str
    published_at: datetime
    is_hourly: bool = False
    country: Optional[str] = None

    def doc_id(self) -> str:
        """مفتاح ثابت لكل URL — يُستخدم كـ Firestore document id."""
        return hashlib.sha1(self.url.encode("utf-8")).hexdigest()

    def to_firestore(self, *, relevance_score: float) -> dict:
        """تحويل إلى dict جاهز للحفظ في Firestore."""
        return {
            "platform": self.platform,
            "title": self.title,
            "description": self.description,
            "budget_min": self.budget_min,
            "budget_max": self.budget_max,
            "currency": self.currency,
            "skills": self.skills,
            "client_name": self.client_name,
            "client_rating": self.client_rating,
            "client_jobs_posted": self.client_jobs_posted,
            "proposals_count": self.proposals_count,
            "url": self.url,
            "published_at": self.published_at,
            "scraped_at": datetime.utcnow(),
            "is_hourly": self.is_hourly,
            "country": self.country,
            "relevance_score": relevance_score,
        }

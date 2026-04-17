"""تقييم مدى صلة كل مشروع بتطوير تطبيقات الموبايل.

الأسلوب: keyword scoring محلي بدون API خارجي.
النتيجة النهائية تُحصر بين 0.0 و 1.0.
"""
from __future__ import annotations

from models.job import JobCreate


HIGH_RELEVANCE_KEYWORDS = [
    "flutter", "dart", "react native", "react-native",
    "mobile app", "mobile application", "تطبيق موبايل",
    "تطبيق جوال", "تطبيق هاتف", "android app", "ios app",
    "cross-platform", "cross platform", "app development",
    "swiftui", "jetpack compose",
]

MEDIUM_RELEVANCE_KEYWORDS = [
    "firebase", "push notification", "app store", "google play",
    "ui/ux mobile", "responsive mobile", "api integration",
    "تطبيق", "أندرويد", "اندرويد", "آيفون", "ايفون",
    "swift", "kotlin", "objective-c", "xamarin", "ionic",
]

LOW_RELEVANCE_KEYWORDS = [
    "frontend", "javascript", "typescript", "node.js",
    "واجهة", "برمجة", "تطوير", "backend",
]

NEGATIVE_KEYWORDS = [
    "wordpress", "shopify", "seo", "content writing",
    "data entry", "virtual assistant", "تفريغ", "كتابة محتوى",
    "video editing", "translation", "ترجمة", "تصميم لوجو",
    "logo design", "graphic design", "مونتاج",
]


def score_job(job: JobCreate) -> float:
    """يُرجع درجة صلة بين 0.0 و 1.0."""
    text = f"{job.title} {job.description} {' '.join(job.skills or [])}".lower()
    score = 0.0

    for kw in HIGH_RELEVANCE_KEYWORDS:
        if kw in text:
            score += 0.3

    for kw in MEDIUM_RELEVANCE_KEYWORDS:
        if kw in text:
            score += 0.15

    for kw in LOW_RELEVANCE_KEYWORDS:
        if kw in text:
            score += 0.05

    for kw in NEGATIVE_KEYWORDS:
        if kw in text:
            score -= 0.5

    # clamp
    if score < 0.0:
        return 0.0
    if score > 1.0:
        return 1.0
    return round(score, 3)

"""تشغيل جميع الـ scrapers بالتوازي وكتابتها إلى Firestore."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta
from typing import List

from google.cloud.firestore_v1 import FieldFilter

from config import settings
from firebase_client import get_firestore
from models.job import JobCreate
from scrapers import (
    AkhtabootScraper,
    ArbeitnowScraper,
    CryptoJobsScraper,
    FindworkScraper,
    FreelancerScraper,
    GuruScraper,
    HnJobsScraper,
    JobicyScraper,
    JobspressoScraper,
    KhamsatScraper,
    LinkedInScraper,
    MostaqlScraper,
    NoDeskScraper,
    RedditScraper,
    ReedScraper,
    RemoteOkScraper,
    RemotiveScraper,
    TheMuseScraper,
    WeWorkRemotelyScraper,
    WorkingNomadsScraper,
)

from .ai_filter import categorize_job, score_job

logger = logging.getLogger(__name__)


def _all_scrapers():
    return [
        # International — REST APIs
        ReedScraper(),  # السوق البريطاني — مئات الآلاف
        TheMuseScraper(),  # شركات معروفة (Apple, Google, BofA, ...)
        FindworkScraper(),  # وظائف تقنية remote (4K+)
        RemotiveScraper(),
        RemoteOkScraper(),
        ArbeitnowScraper(),
        WorkingNomadsScraper(),
        JobicyScraper(),
        HnJobsScraper(),
        # International — RSS
        WeWorkRemotelyScraper(),
        NoDeskScraper(),
        # Freelance marketplaces (bid-based)
        FreelancerScraper(),
        GuruScraper(),
        # Curated remote
        JobspressoScraper(),
        # LinkedIn (rate-limit محافظ)
        LinkedInScraper(),
        # Reddit — r/forhire + r/jobbit + r/slavelabour + r/remotejs
        # (قد يفشل من GitHub Actions — يحتاج OAuth app لبعض الأحيان)
        RedditScraper(),
        # Crypto / Web3
        CryptoJobsScraper(),
        # Arabic / MENA platforms — web scraping
        MostaqlScraper(),
        KhamsatScraper(),
        AkhtabootScraper(),
    ]


async def run_all_scrapers() -> List[JobCreate]:
    """شغّل جميع الـ scrapers بالتوازي ثم dedup by url."""
    scrapers = _all_scrapers()
    results = await asyncio.gather(
        *(s.safe_scrape() for s in scrapers), return_exceptions=False
    )

    flat: List[JobCreate] = []
    for batch in results:
        flat.extend(batch)

    seen: dict[str, JobCreate] = {}
    for job in flat:
        seen[job.url] = job
    return list(seen.values())


def _delete_old_jobs() -> int:
    """يحذف الوظائف الأقدم من MAX_JOB_AGE_DAYS من Firestore."""
    db = get_firestore()
    cutoff = datetime.utcnow() - timedelta(days=settings.max_job_age_days)
    query = (
        db.collection(settings.firestore_collection)
        .where(filter=FieldFilter("published_at", "<", cutoff))
        .limit(500)
    )
    deleted = 0
    while True:
        docs = list(query.stream())
        if not docs:
            break
        # Batch delete
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(docs)
        if len(docs) < 500:
            break
    return deleted


def _write_jobs(jobs: List[JobCreate]) -> tuple[int, int, int]:
    """يكتب الجديد فقط في Firestore.

    يفحص فقط الـ URLs اللي نحاول كتابتها (لا يقرأ كل الـ collection)
    لتوفير read quota.
    يُرجع (kept_after_filter, new_written, skipped_existing).
    """
    db = get_firestore()
    coll = db.collection(settings.firestore_collection)

    # فلتر + احضّر الـ refs
    candidates: list[tuple[str, JobCreate, float, str]] = []
    for job in jobs:
        relevance = score_job(job)
        if relevance < settings.min_relevance_score:
            continue
        category = categorize_job(job)
        candidates.append((job.doc_id(), job, relevance, category))

    kept = len(candidates)
    if not candidates:
        return 0, 0, 0

    # تحقق من وجود كل doc_id دفعة (batched get_all)
    # get_all يأخذ list of refs ويُرجع snapshots
    refs = [coll.document(doc_id) for doc_id, *_ in candidates]
    existing: set[str] = set()
    # get_all يسمح بـ 500 ref max
    for i in range(0, len(refs), 500):
        chunk = refs[i : i + 500]
        for snap in db.get_all(chunk):
            if snap.exists:
                existing.add(snap.id)

    new_written = 0
    skipped = 0
    batch = db.batch()
    in_batch = 0

    for doc_id, job, relevance, category in candidates:
        if doc_id in existing:
            skipped += 1
            continue

        ref = coll.document(doc_id)
        batch.set(
            ref,
            job.to_firestore(relevance_score=relevance, category=category),
        )
        in_batch += 1
        new_written += 1

        if in_batch >= 450:
            batch.commit()
            batch = db.batch()
            in_batch = 0

    if in_batch > 0:
        batch.commit()

    return kept, new_written, skipped


async def aggregate_and_store() -> dict:
    """الجولة الكاملة: scrape + score + write to Firestore + cleanup."""
    started = datetime.utcnow()
    logger.info("[aggregator] round started at %s", started.isoformat())

    raw_jobs = await run_all_scrapers()
    kept, written, skipped = await asyncio.to_thread(_write_jobs, raw_jobs)
    deleted = await asyncio.to_thread(_delete_old_jobs)

    finished = datetime.utcnow()
    summary = {
        "started_at": started.isoformat(),
        "finished_at": finished.isoformat(),
        "duration_seconds": (finished - started).total_seconds(),
        "scraped_total": len(raw_jobs),
        "kept_after_filter": kept,
        "new_written": written,
        "skipped_existing": skipped,
        "deleted_old_jobs": deleted,
    }
    logger.info("[aggregator] round finished: %s", summary)
    return summary

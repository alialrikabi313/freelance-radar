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
    ArbeitnowScraper,
    FindworkScraper,
    FreelancerScraper,
    GuruScraper,
    HnJobsScraper,
    JobicyScraper,
    JobspressoScraper,
    KhamsatScraper,
    MostaqlScraper,
    NoDeskScraper,
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
        # Arabic platforms — web scraping
        MostaqlScraper(),
        KhamsatScraper(),
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


def _write_jobs(jobs: List[JobCreate]) -> tuple[int, int]:
    """يكتب/يحدّث الوظائف في Firestore. يُرجع (kept, written)."""
    db = get_firestore()
    coll = db.collection(settings.firestore_collection)

    kept = 0
    written = 0
    batch = db.batch()
    in_batch = 0

    for job in jobs:
        relevance = score_job(job)
        if relevance < settings.min_relevance_score:
            continue
        kept += 1

        category = categorize_job(job)
        doc_id = job.doc_id()
        ref = coll.document(doc_id)
        batch.set(
            ref,
            job.to_firestore(relevance_score=relevance, category=category),
            merge=True,
        )
        in_batch += 1
        written += 1

        # Firestore batch حد أقصى 500 عملية
        if in_batch >= 450:
            batch.commit()
            batch = db.batch()
            in_batch = 0

    if in_batch > 0:
        batch.commit()

    return kept, written


async def aggregate_and_store() -> dict:
    """الجولة الكاملة: scrape + score + write to Firestore + cleanup."""
    started = datetime.utcnow()
    logger.info("[aggregator] round started at %s", started.isoformat())

    raw_jobs = await run_all_scrapers()
    # نكتب في thread tangential لأن firestore SDK متزامن
    kept, written = await asyncio.to_thread(_write_jobs, raw_jobs)
    deleted = await asyncio.to_thread(_delete_old_jobs)

    finished = datetime.utcnow()
    summary = {
        "started_at": started.isoformat(),
        "finished_at": finished.isoformat(),
        "duration_seconds": (finished - started).total_seconds(),
        "scraped_total": len(raw_jobs),
        "kept_after_filter": kept,
        "written_to_firestore": written,
        "deleted_old_jobs": deleted,
    }
    logger.info("[aggregator] round finished: %s", summary)
    return summary

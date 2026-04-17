"""تهيئة Firebase Admin SDK والوصول إلى Firestore."""
from __future__ import annotations

import json
import logging
from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore

from config import settings

logger = logging.getLogger(__name__)


def _build_credentials() -> credentials.Base:
    """بناء credentials من المتغيرات البيئية.

    يدعم خيارين:
      1. ملف JSON محلي (FIREBASE_CREDENTIALS_PATH)
      2. محتوى JSON كـ string (FIREBASE_CREDENTIALS_JSON) — مناسب لـ
         GitHub Actions secrets.
    """
    if settings.firebase_credentials_json:
        try:
            data = json.loads(settings.firebase_credentials_json)
        except json.JSONDecodeError as exc:
            raise RuntimeError(
                "FIREBASE_CREDENTIALS_JSON ليس JSON صالحاً"
            ) from exc
        return credentials.Certificate(data)

    if settings.firebase_credentials_path:
        return credentials.Certificate(settings.firebase_credentials_path)

    raise RuntimeError(
        "لم يتم توفير Firebase credentials. حدّد FIREBASE_CREDENTIALS_PATH "
        "أو FIREBASE_CREDENTIALS_JSON في البيئة."
    )


@lru_cache(maxsize=1)
def get_firestore():
    """يُرجع Firestore client مع التهيئة الكسولة."""
    if not firebase_admin._apps:  # noqa: SLF001
        cred = _build_credentials()
        firebase_admin.initialize_app(cred)
        logger.info("Firebase initialized")
    return firestore.client()

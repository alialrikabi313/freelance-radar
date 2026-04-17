"""Entry point — يُشغَّل من GitHub Actions أو يدوياً.

يقوم بجولة سحب واحدة كاملة من جميع المنصات ويكتب النتائج إلى Firestore.
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys

from services.aggregator import aggregate_and_store

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("freelance_radar")


def main() -> int:
    try:
        summary = asyncio.run(aggregate_and_store())
    except Exception as exc:  # noqa: BLE001
        logger.exception("scrape round failed: %s", exc)
        return 1

    print("\n=== Scrape Summary ===")
    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())

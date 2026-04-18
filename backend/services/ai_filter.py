"""تقييم مدى صلة كل مشروع بالبرمجة + تصنيفه إلى فئة.

الأسلوب: keyword scoring محلي بدون API خارجي.
النتيجة النهائية تُحصر بين 0.0 و 1.0.
"""
from __future__ import annotations

from models.job import JobCreate


# ────────────────────── Category detection keywords ──────────────────────

CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "mobile": [
        "flutter", "dart", "react native", "react-native",
        "mobile app", "mobile application", "mobile development",
        "android app", "ios app", "iphone", "ipad", "tablet app",
        "swift", "swiftui", "kotlin", "jetpack compose",
        "xamarin", "ionic", "cordova", "nativescript", "capacitor",
        "cross-platform", "cross platform", "app store", "google play",
        "objective-c", "objective c", "android studio",
        # Arabic
        "تطبيق موبايل", "تطبيق جوال", "تطبيق هاتف", "تطبيق للجوال",
        "أندرويد", "اندرويد", "آيفون", "ايفون", "ايباد", "هاتف محمول",
        "فلاتر", "رياكت نيتيف", "تصميم تطبيق", "برمجة تطبيق",
    ],
    "web": [
        "html", "css", "react", "vue", "angular", "svelte",
        "next.js", "nextjs", "nuxt", "tailwind", "bootstrap",
        "website", "web app", "frontend", "front-end", "front end",
        "web design", "landing page", "wordpress theme", "webflow",
        "wix", "shopify dev", "woocommerce", "magento", "drupal",
        "jquery", "sass", "scss", "webpack", "vite",
        # Arabic
        "واجهة ويب", "موقع الكتروني", "موقع إلكتروني", "تصميم موقع",
        "تطوير موقع", "ووردبريس", "صفحة هبوط", "هبوط",
    ],
    "backend": [
        "backend", "back-end", "back end", "api",
        "node.js", "nodejs", "express", "django", "fastapi", "flask",
        "spring boot", "laravel", "ruby on rails", "rails", "asp.net",
        ".net", "microservices", "kubernetes", "docker", "serverless",
        "aws", "gcp", "azure", "devops", "ci/cd", "terraform",
        "postgres", "postgresql", "mysql", "mongodb", "redis",
        "elasticsearch", "graphql", "grpc", "rest api", "rabbitmq", "kafka",
        # Arabic
        "خادم", "سيرفر", "قاعدة بيانات", "واجهة برمجية", "خلفية",
    ],
    "ai": [
        "machine learning", "deep learning", "neural network",
        "ai ", "artificial intelligence", "llm", "gpt",
        "chatgpt", "openai", "langchain", "rag", "llama",
        "computer vision", "nlp", "natural language",
        "tensorflow", "pytorch", "huggingface", "transformers",
        "anthropic", "claude", "gemini", "stable diffusion",
        "ml engineer", "mlops", "data scientist",
        # Arabic
        "ذكاء اصطناعي", "تعلم آلي", "تعلم عميق", "معالجة اللغة",
        "رؤية حاسوبية", "شات بوت", "روبوت محادثة",
    ],
    "game": [
        "unity", "unreal", "godot", "game dev", "game development",
        "2d game", "3d game", "mobile game", "game design",
        "gamemaker", "cocos2d", "roblox",
        # Arabic
        "تطوير لعبة", "تطوير العاب", "لعبة", "ألعاب", "يونيتي",
    ],
    "data": [
        "data science", "data analysis", "data analyst",
        "data engineering", "etl", "power bi", "tableau",
        "pandas", "numpy", "spark", "airflow", "dbt",
        "snowflake", "bigquery", "databricks", "looker",
        # Arabic
        "تحليل بيانات", "علم بيانات", "هندسة بيانات", "محلل بيانات",
    ],
    "blockchain": [
        "blockchain", "solidity", "smart contract", "web3",
        "ethereum", "nft", "crypto", "defi", "dao",
        "polygon", "bitcoin", "metamask", "hardhat", "foundry",
        "rust smart", "near protocol", "solana",
        # Arabic
        "بلوكتشين", "عقود ذكية", "عملات رقمية", "عملة رقمية",
    ],
    "desktop": [
        "desktop app", "electron", "tauri", "qt", "wpf", "winforms",
        "macos app", "windows app", "linux app", "cross-platform desktop",
        # Arabic
        "تطبيق سطح مكتب", "برنامج ويندوز",
    ],
}


# أي وظيفة تحتوي كلمة من هذي تعتبر برمجية
PROGRAMMING_KEYWORDS: list[str] = [
    "developer", "development", "programming", "programmer", "engineer",
    "software", "code", "coding", "coder",
    "python", "javascript", "typescript", "java ", "c++", "c#", "go ",
    "rust", "php", "ruby", "scala",
    "git", "github", "gitlab",
    "مبرمج", "مطور", "برمجة", "تطوير", "هندسة برمجيات",
]


# كلمات سلبية ترفض الوظيفة نهائياً
NEGATIVE_KEYWORDS: list[str] = [
    "seo", "content writing", "article writing", "blog post",
    "data entry", "virtual assistant", "transcription",
    "video editing", "video editor", "animation", "motion graphics",
    "logo design", "graphic design", "photoshop", "illustrator",
    "translation", "translator", "voice over", "voiceover",
    "تفريغ", "كتابة محتوى", "كتابة مقال", "ترجمة",
    "تصميم لوجو", "تصميم شعار", "مونتاج", "تحرير فيديو",
    "صوتي", "تعليق صوتي",
]


def categorize_job(job: JobCreate) -> str:
    """يحدد فئة الوظيفة الأساسية بناءً على الكلمات المفتاحية.

    يُرجع أول فئة تطابق. لو لا مطابقة → "other".
    الترتيب مهم: mobile قبل web قبل backend لأن "flutter developer"
    ممكن تحتوي "developer" (web) — نريد mobile أولاً.
    """
    text = f"{job.title} {job.description} {' '.join(job.skills or [])}".lower()

    # نفحص بالترتيب — mobile أولاً لأنه الأكثر تخصصاً
    for category in ("mobile", "game", "ai", "blockchain", "data", "web", "backend", "desktop"):
        for kw in CATEGORY_KEYWORDS[category]:
            if kw in text:
                return category
    return "other"


def score_job(job: JobCreate) -> float:
    """يُرجع درجة صلة بين 0.0 و 1.0.

    المنطق:
      - +0.3 لكل كلمة من فئة محددة (mobile/web/backend/...)
      - +0.15 لكل كلمة برمجة عامة
      - -0.5 لكل كلمة سلبية (SEO, كتابة, ترجمة...)
    """
    text = f"{job.title} {job.description} {' '.join(job.skills or [])}".lower()
    score = 0.0

    # كلمات الفئات — كل مطابقة تعزز الـ score
    matched_categories = 0
    for category, keywords in CATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            matched_categories += 1
            score += 0.3

    # كلمات برمجة عامة
    for kw in PROGRAMMING_KEYWORDS:
        if kw in text:
            score += 0.15
            break  # مرة واحدة كافية

    # كلمات سلبية
    for kw in NEGATIVE_KEYWORDS:
        if kw in text:
            score -= 0.5

    # clamp
    if score < 0.0:
        return 0.0
    if score > 1.0:
        return 1.0
    return round(score, 3)

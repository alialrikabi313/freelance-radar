# Master Prompt: FreelanceRadar - تطبيق تجميع فرص العمل الحر للمبرمجين

## 🎯 Project Overview

أنشئ تطبيق موبايل باستخدام **Flutter** مع **Python FastAPI backend** يقوم بتجميع فرص العمل الحر المتعلقة بتطوير تطبيقات الموبايل من عدة منصات فريلانس (Upwork, Freelancer.com, مستقل، خمسات) وعرضها في واجهة واحدة أنيقة مع إمكانية الفلترة والضغط على أي فرصة للانتقال مباشرة لصفحتها الأصلية.

اسم التطبيق: **FreelanceRadar** (فريلانس رادار)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                 Flutter Mobile App                │
│  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ Jobs Feed │ │ Filters  │ │ Job Detail +   │  │
│  │ Screen    │ │ Panel    │ │ External Link  │  │
│  └───────────┘ └──────────┘ └────────────────┘  │
└──────────────────────┬──────────────────────────┘
                       │ REST API
┌──────────────────────▼──────────────────────────┐
│              FastAPI Backend Server               │
│  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ Scraping  │ │ AI       │ │ Caching +      │  │
│  │ Engine    │ │ Filter   │ │ Database       │  │
│  └───────────┘ └──────────┘ └────────────────┘  │
└──────────────────────┬──────────────────────────┘
                       │
    ┌──────────┬───────┴────────┬──────────┐
    ▼          ▼                ▼          ▼
 Upwork   Freelancer.com    مستقل      خمسات
```

---

## 📁 Project Structure

```
freelance-radar/
├── backend/
│   ├── main.py                    # FastAPI entry point
│   ├── requirements.txt
│   ├── config.py                  # Settings & environment variables
│   ├── database.py                # SQLite database setup
│   ├── models/
│   │   ├── __init__.py
│   │   └── job.py                 # Job data model
│   ├── scrapers/
│   │   ├── __init__.py
│   │   ├── base_scraper.py        # Abstract base scraper class
│   │   ├── upwork_scraper.py      # Upwork RSS/API scraper
│   │   ├── freelancer_scraper.py  # Freelancer.com API scraper
│   │   ├── mostaql_scraper.py     # مستقل scraper
│   │   └── khamsat_scraper.py     # خمسات scraper
│   ├── services/
│   │   ├── __init__.py
│   │   ├── aggregator.py          # Combines all scrapers
│   │   ├── ai_filter.py           # AI-based relevance scoring
│   │   └── scheduler.py           # Background job scheduling
│   └── routers/
│       ├── __init__.py
│       └── jobs.py                # API endpoints
│
├── mobile/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── config/
│       │   ├── theme.dart          # App theme (dark/light)
│       │   ├── constants.dart      # API URLs, colors
│       │   └── routes.dart         # Named routes
│       ├── models/
│       │   └── job_model.dart      # Job data model
│       ├── services/
│       │   ├── api_service.dart    # HTTP client for backend
│       │   └── cache_service.dart  # Local caching
│       ├── providers/
│       │   ├── jobs_provider.dart  # State management
│       │   └── filter_provider.dart
│       ├── screens/
│       │   ├── home_screen.dart    # Main jobs feed
│       │   ├── job_detail_screen.dart
│       │   └── settings_screen.dart
│       ├── widgets/
│       │   ├── job_card.dart       # Individual job card
│       │   ├── filter_chips.dart   # Filter UI
│       │   ├── platform_badge.dart # Platform logo badge
│       │   ├── shimmer_loading.dart # Loading skeleton
│       │   └── empty_state.dart    # No results widget
│       └── utils/
│           ├── time_ago.dart       # Relative time formatting
│           ├── url_launcher.dart   # External link handler
│           └── arabic_utils.dart   # Arabic text utilities
│
└── README.md
```

---

## 🔧 Backend Implementation Details

### 1. Database Model (`models/job.py`)

```
Job Model Fields:
- id: String (UUID) - Primary key
- platform: String - "upwork" | "freelancer" | "mostaql" | "khamsat"
- title: String - عنوان المشروع
- description: String - وصف المشروع (أول 500 حرف)
- budget_min: Float (nullable) - الميزانية الدنيا
- budget_max: Float (nullable) - الميزانية القصوى
- currency: String - "USD" | "IQD" | "SAR" etc.
- skills: List[String] - المهارات المطلوبة ["Flutter", "React Native", etc.]
- client_name: String (nullable) - اسم العميل
- client_rating: Float (nullable) - تقييم العميل
- client_jobs_posted: Int (nullable) - عدد مشاريع العميل السابقة
- proposals_count: Int (nullable) - عدد العروض المقدمة
- url: String - الرابط المباشر للمشروع على المنصة الأصلية
- published_at: DateTime - تاريخ النشر
- scraped_at: DateTime - تاريخ السحب
- is_hourly: Boolean - هل بالساعة أم بسعر ثابت
- relevance_score: Float - درجة الصلة (0.0 - 1.0) يحسبها AI
- is_read: Boolean - هل قرأها المستخدم (default: false)
- country: String (nullable) - بلد العميل
```

### 2. Scrapers Architecture

#### Base Scraper (`scrapers/base_scraper.py`):
```python
# Abstract base class with:
# - abstract method: scrape() -> List[Job]
# - shared method: normalize_job() - converts platform-specific data to Job model
# - shared method: is_mobile_related() - checks if job is mobile dev related
# - rate limiting logic with random delays (2-5 seconds between requests)
# - User-Agent rotation
# - Error handling & logging
```

#### Upwork Scraper (`scrapers/upwork_scraper.py`):
```
Strategy: استخدام Upwork RSS Feeds
- RSS URL pattern: https://www.upwork.com/ab/feed/jobs/rss?q=mobile+app+development&sort=recency
- إضافة feeds متعددة بكلمات مفتاحية مختلفة:
  * "flutter app development"
  * "mobile app development"  
  * "android ios app"
  * "react native app"
  * "تطبيق موبايل" (للمشاريع العربية)
- Parse RSS using feedparser library
- Extract: title, description, budget, skills, url, published date
- ملاحظة: Upwork RSS لا يتطلب authentication
```

#### Freelancer.com Scraper (`scrapers/freelancer_scraper.py`):
```
Strategy: استخدام Freelancer.com Public API
- API Base: https://www.freelancer.com/api/projects/0.1/projects/active/
- Parameters:
  * job_details=true
  * compact=true  
  * languages[]=ar (للمشاريع العربية أيضاً)
  * jobs[]=mobile-app-development
  * jobs[]=flutter
  * jobs[]=android-app-development
  * jobs[]=ios-app-development
  * sort_field=time_submitted
  * limit=50
- يتطلب API key (مجاني من developer portal)
- Documentation: https://developers.freelancer.com/
```

#### مستقل Scraper (`scrapers/mostaql_scraper.py`):
```
Strategy: Web Scraping using httpx + BeautifulSoup
- Base URL: https://mostaql.com/projects?category=development&subcategory=mobile
- Parse HTML to extract:
  * عنوان المشروع
  * الوصف المختصر
  * الميزانية
  * عدد العروض
  * تاريخ النشر
  * رابط المشروع
- Pagination: تصفح أول 3 صفحات
- Rate limiting: 3-5 seconds بين كل request
- Handle Arabic text encoding properly (UTF-8)
```

#### خمسات Scraper (`scrapers/khamsat_scraper.py`):
```
Strategy: Web Scraping using httpx + BeautifulSoup  
- Base URL: https://khamsat.com/community/requests?category=programming
- Filter: طلبات متعلقة بتطوير تطبيقات الموبايل
- Parse: العنوان، الوصف، الميزانية، الرابط، التاريخ
- ملاحظة: خمسات قسم "طلبات الخدمات غير الموجودة" هو اللي فيه فرص
```

### 3. AI Filter Service (`services/ai_filter.py`)

```
Purpose: تقييم مدى صلة كل مشروع بتطوير تطبيقات الموبايل

Method: Keyword-based scoring (بدون API خارجي لتوفير التكلفة)

Scoring Logic:
HIGH_RELEVANCE_KEYWORDS (score +0.3 each):
  - "flutter", "dart", "react native", "mobile app", "تطبيق موبايل"
  - "تطبيق جوال", "تطبيق هاتف", "android app", "ios app"
  - "cross-platform", "app development"

MEDIUM_RELEVANCE_KEYWORDS (score +0.15 each):
  - "firebase", "push notification", "app store", "google play"
  - "ui/ux mobile", "responsive", "api integration"
  - "تطبيق", "أندرويد", "آيفون"

LOW_RELEVANCE_KEYWORDS (score +0.05 each):
  - "frontend", "javascript", "typescript", "node.js"
  - "واجهة", "برمجة", "تطوير"

NEGATIVE_KEYWORDS (score -0.5 each):
  - "wordpress", "shopify", "seo", "content writing"
  - "data entry", "virtual assistant", "تفريغ", "كتابة محتوى"

Final score = clamped between 0.0 and 1.0
Only show jobs with relevance_score >= 0.3
```

### 4. API Endpoints (`routers/jobs.py`)

```
GET /api/jobs
  Query params:
    - platform: Optional[str] - فلترة بالمنصة
    - min_budget: Optional[float] - أقل ميزانية
    - max_budget: Optional[float] - أعلى ميزانية
    - sort_by: str = "published_at" | "relevance_score" | "budget_max"
    - sort_order: str = "desc" | "asc"  
    - page: int = 1
    - per_page: int = 20
    - search: Optional[str] - بحث بالعنوان والوصف
    - language: Optional[str] = "all" | "ar" | "en"
  Response: {
    "jobs": [...],
    "total": int,
    "page": int,
    "total_pages": int,
    "last_updated": datetime
  }

GET /api/jobs/{job_id}
  Response: Full job details

POST /api/jobs/refresh
  Triggers manual scraping of all platforms
  Response: { "message": "Scraping started", "estimated_time": "2-3 minutes" }

GET /api/stats
  Response: {
    "total_jobs": int,
    "jobs_by_platform": {...},
    "avg_budget": float,
    "last_scrape": datetime
  }
```

### 5. Scheduler (`services/scheduler.py`)

```
Using APScheduler:
- Run full scrape every 30 minutes
- On each run:
  1. Scrape all platforms concurrently (asyncio.gather)
  2. Deduplicate by URL
  3. Calculate relevance scores
  4. Store new jobs in SQLite
  5. Remove jobs older than 30 days
  6. Log scraping results (success/failure per platform)
```

### 6. Backend Config & Dependencies

```
requirements.txt:
- fastapi
- uvicorn[standard]
- httpx
- beautifulsoup4
- feedparser
- apscheduler
- pydantic
- aiosqlite
- databases
- python-dotenv

config.py:
- DATABASE_URL = "sqlite:///./jobs.db"
- SCRAPE_INTERVAL_MINUTES = 30
- MAX_JOB_AGE_DAYS = 30
- MIN_RELEVANCE_SCORE = 0.3
- USER_AGENTS = [list of 10+ browser user agents for rotation]
- REQUEST_DELAY_MIN = 2
- REQUEST_DELAY_MAX = 5
```

---

## 📱 Flutter Mobile App Details

### 1. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Networking
  dio: ^5.4.0
  # State Management  
  provider: ^6.1.0
  # URL Launching
  url_launcher: ^6.2.0
  # Local Storage
  shared_preferences: ^2.2.0
  # UI Components
  shimmer: ^3.0.0
  cached_network_image: ^3.3.0
  # Date Formatting
  timeago: ^3.6.0
  # Pull to Refresh
  pull_to_refresh_flutter3: ^2.0.2
  # Icons
  flutter_svg: ^2.0.9
  # Intl for Arabic
  intl: ^0.19.0
```

### 2. Theme (`config/theme.dart`)

```
Design System:
- Primary Color: #2563EB (Professional Blue)
- Secondary Color: #10B981 (Success Green)  
- Background: #F8FAFC (Light Gray)
- Surface: #FFFFFF
- Text Primary: #1E293B
- Text Secondary: #64748B

Platform Badge Colors:
- Upwork: #14A800 (Upwork Green)
- Freelancer: #29B2FE (Freelancer Blue)  
- مستقل: #4E4BBB (Mostaql Purple)
- خمسات: #2EAF5C (Khamsat Green)

Typography:
- Arabic Font: Cairo (from Google Fonts)
- English Font: Inter
- Title: 16sp Bold
- Body: 14sp Regular
- Caption: 12sp Regular

الواجهة تدعم RTL بالكامل لأن المستخدم عراقي
Default locale: ar
```

### 3. Home Screen (`screens/home_screen.dart`)

```
Layout:
┌─────────────────────────────────┐
│ 🔍 FreelanceRadar        ⚙️    │  ← AppBar with search & settings
├─────────────────────────────────┤
│ [All] [Upwork] [Freelancer]     │  ← Horizontal scrollable filter chips
│ [مستقل] [خمسات]                │     for platforms
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🟢 Flutter E-commerce App  │ │  ← Job Card
│ │ Upwork • $500-$1000        │ │
│ │ منذ ساعتين • 5 عروض        │ │
│ │ Flutter · Firebase · Dart  │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🟣 تطبيق توصيل طلبات       │ │  ← Job Card (Arabic)
│ │ مستقل • $300-$700          │ │
│ │ منذ 4 ساعات • 12 عرض       │ │
│ │ Flutter · Google Maps      │ │
│ └─────────────────────────────┘ │
│            ...                  │
│     [Pull to refresh ↓]        │
└─────────────────────────────────┘

Features:
- Pull-to-refresh: يسحب من الـ backend آخر الفرص
- Infinite scroll: تحميل المزيد عند الوصول لنهاية القائمة
- Shimmer loading: skeleton animation أثناء التحميل
- Empty state: رسالة ودية إذا ما فيه نتائج
- Badge على كل كارد يوضح المنصة بلونها المميز
- الوقت يعرض بصيغة "منذ X" (timeago)
- Sort button: ترتيب بالأحدث / الأعلى ميزانية / الأكثر صلة
```

### 4. Job Card Widget (`widgets/job_card.dart`)

```
Design:
┌──────────────────────────────────────┐
│  [Upwork Badge]          💰 $500-1K  │
│                                      │
│  Flutter E-commerce App              │  ← Title (bold, max 2 lines)
│                                      │
│  Build a full e-commerce mobile      │  ← Description (max 3 lines,
│  app with payment integration...     │     with ellipsis)
│                                      │
│  ┌────────┐ ┌─────────┐ ┌────────┐  │
│  │Flutter │ │Firebase │ │ Dart  │  │  ← Skill chips
│  └────────┘ └─────────┘ └────────┘  │
│                                      │
│  🕐 منذ ساعتين   👥 5 عروض          │  ← Meta info
│  ⭐ 4.8 (23 مشروع)                  │  ← Client rating if available
└──────────────────────────────────────┘

On tap: Navigate to job detail screen
Card has subtle elevation (2dp) with rounded corners (12dp)
Unread jobs have a thin blue left border indicator
```

### 5. Job Detail Screen (`screens/job_detail_screen.dart`)

```
Layout:
┌─────────────────────────────────┐
│ ← رجوع     تفاصيل المشروع      │
├─────────────────────────────────┤
│                                 │
│ [Upwork Badge]                  │
│                                 │
│ Flutter E-commerce App          │  ← Full title
│                                 │
│ 💰 الميزانية: $500 - $1,000     │
│ 📅 نُشر: منذ ساعتين             │
│ 👥 العروض المقدمة: 5            │
│ ⏱️ النوع: سعر ثابت              │
│ 🌍 بلد العميل: USA              │
│                                 │
│ ─────────────────────────────── │
│                                 │
│ الوصف الكامل:                   │
│ Build a full e-commerce mobile  │
│ app using Flutter with the      │
│ following features:             │
│ - User authentication           │
│ - Product catalog               │
│ - Shopping cart                  │
│ - Payment integration           │
│ ...                             │
│                                 │
│ ─────────────────────────────── │
│                                 │
│ المهارات المطلوبة:               │
│ [Flutter] [Firebase] [Dart]     │
│ [REST API] [Git]                │
│                                 │
│ ─────────────────────────────── │
│                                 │
│ معلومات العميل:                  │
│ ⭐ التقييم: 4.8/5               │
│ 📋 مشاريع سابقة: 23             │
│                                 │
├─────────────────────────────────┤
│                                 │
│   [ 🔗 فتح في المنصة الأصلية ]  │  ← Big CTA button
│                                 │
│   Opens url_launcher to the     │
│   original job URL              │
│                                 │
└─────────────────────────────────┘

الزر "فتح في المنصة الأصلية" يستخدم url_launcher
لفتح الرابط في المتصفح الخارجي مباشرة
```

### 6. Settings Screen (`screens/settings_screen.dart`)

```
Options:
- اختيار المنصات المفعلة (toggle per platform)
- الحد الأدنى للميزانية (slider أو text field)
- لغة المشاريع: الكل / عربي فقط / إنجليزي فقط
- عنوان الـ Backend Server URL (للتعديل)
- زر "تحديث الآن" لتحفيز scraping يدوي
- معلومات التطبيق (الإصدار)
```

### 7. State Management (`providers/jobs_provider.dart`)

```
Using Provider (ChangeNotifier):

State:
- List<Job> jobs
- bool isLoading
- bool isLoadingMore  
- String? error
- int currentPage
- bool hasMore
- String selectedPlatform = "all"
- String sortBy = "published_at"

Methods:
- fetchJobs() - Initial load
- loadMore() - Pagination
- refresh() - Pull to refresh (calls POST /api/jobs/refresh then GET)
- filterByPlatform(String platform)
- changeSortOrder(String sort)
- searchJobs(String query)
```

### 8. API Service (`services/api_service.dart`)

```
Using Dio:
- Base URL configurable (default: http://localhost:8000)
- Timeout: 30 seconds
- Interceptors:
  * Logging interceptor (debug mode)
  * Error handling interceptor
  * Cache interceptor (cache GET responses for 5 minutes)
- Methods mirror all backend endpoints
- Proper error handling with user-friendly Arabic error messages:
  * "لا يوجد اتصال بالإنترنت"
  * "حدث خطأ في الخادم، حاول مرة أخرى"
  * "لم يتم العثور على نتائج"
```

---

## 🚀 Deployment & Running

### Backend:
```bash
cd backend
pip install -r requirements.txt
# Create .env file with any needed API keys
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Mobile:
```bash
cd mobile
flutter pub get
flutter run
```

### للاستخدام الشخصي:
- شغّل الـ backend على جهازك المحلي أو على VPS رخيص
- التطبيق يتصل بالـ backend عبر IP/domain
- ممكن تستخدم خدمة مجانية مثل Railway أو Render لاستضافة الـ backend

---

## ⚠️ Important Notes

1. **Rate Limiting**: احترم حدود المنصات - لا تسحب بيانات أكثر من مرة كل 30 دقيقة
2. **User-Agent Rotation**: استخدم user agents مختلفة لتجنب الحظر
3. **Error Resilience**: إذا فشل scraper منصة واحدة، باقي المنصات تستمر بالعمل
4. **Arabic Support**: الواجهة RTL بالكامل، والبحث يدعم العربي والإنجليزي
5. **No Auto-Apply**: التطبيق للمراقبة فقط - التقديم يكون يدوي عبر فتح الرابط الأصلي
6. **Offline Cache**: آخر نتائج محملة تبقى متاحة بدون إنترنت
7. **Freelancer.com API**: سجّل للحصول على API key مجاني من https://developers.freelancer.com/
8. **الكود بالإنجليزي**: جميع أسماء المتغيرات والدوال بالإنجليزي، التعليقات ممكن عربي

---

## 🔨 Build Order (للتنفيذ بالتسلسل)

### Phase 1: Backend Core
1. إنشاء هيكل المشروع وقاعدة البيانات
2. بناء Base Scraper class
3. بناء Upwork RSS Scraper (الأسهل - ابدأ فيه)
4. بناء API endpoints الأساسية
5. اختبار: تشغيل الـ backend والتأكد من سحب وعرض بيانات Upwork

### Phase 2: More Scrapers
6. بناء Freelancer.com API Scraper
7. بناء مستقل Web Scraper
8. بناء خمسات Web Scraper
9. بناء AI Filter service
10. بناء Scheduler للتحديث التلقائي

### Phase 3: Flutter App
11. إنشاء مشروع Flutter مع الهيكل الأساسي
12. بناء Theme و RTL support
13. بناء Job Model و API Service
14. بناء Home Screen مع Job Cards
15. بناء Job Detail Screen مع زر فتح الرابط
16. بناء Filter Chips و Sort
17. بناء Pull-to-refresh و Infinite scroll
18. بناء Settings Screen
19. بناء Shimmer Loading و Empty States

### Phase 4: Polish
20. إضافة Error handling شامل
21. إضافة Offline caching
22. اختبار شامل لجميع المنصات
23. تحسين الأداء وحجم التطبيق

---

## 🎨 Design Principles

- **Clean & Minimal**: واجهة نظيفة بدون فوضى
- **Mobile-First**: مصمم للموبايل أساساً
- **Arabic-First**: RTL هو الافتراضي
- **Fast**: الـ cards تحمل بسرعة مع shimmer loading
- **Actionable**: كل فرصة قابلة للضغط والوصول المباشر
- **Scannable**: المعلومات المهمة (الميزانية، المنصة، الوقت) واضحة من أول نظرة

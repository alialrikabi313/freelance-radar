# FreelanceRadar — فريلانس رادار

> تطبيق موبايل يجمع فرص العمل الحر لتطوير تطبيقات الموبايل من
> **Upwork**, **Freelancer.com**, **مستقل**, و **خمسات**.
>
> 🆓 **معمارية مجانية بالكامل** — بلا backend ولا server.

---

## 🏗️ المعمارية

```
GitHub Actions (cron كل 30 دقيقة، مجاني)
        │
        ▼ يشغّل Python scrapers
        │
        ▼ يكتب الفرص إلى
   Firestore (Spark plan مجاني)
        │
        ▲ يقرأ مباشرة منه
        │
   Flutter App (Firebase SDK)
```

```
freelance-radar/
├── .github/workflows/
│   └── scrape.yml          ← Cron job كل 30 دقيقة
├── backend/                ← Python scraper (يعمل في GitHub Actions)
│   ├── run.py              ← Entry point
│   ├── firebase_client.py
│   ├── config.py
│   ├── models/job.py
│   ├── scrapers/           ← 4 scrapers (Upwork, Freelancer, مستقل, خمسات)
│   └── services/
│       ├── ai_filter.py
│       └── aggregator.py   ← يكتب إلى Firestore
├── mobile/                 ← Flutter app يقرأ من Firestore
├── firestore.rules         ← قواعد أمان Firestore
└── README.md
```

---

## 🚀 خطوات الإعداد (مرّة واحدة)

### الخطوة 1 — إنشاء مشروع Firebase

1. ادخل [console.firebase.google.com](https://console.firebase.google.com/)
2. أنشئ مشروعاً جديداً (Spark plan = مجاني)
3. من القائمة → **Build → Firestore Database** → Create database
   - اختر **Production mode**
   - اختر أقرب region (مثل `eur3` أو `nam5`)
4. ارفع قواعد الأمان: من تبويب **Rules**، الصق محتوى `firestore.rules`

### الخطوة 2 — إنشاء Service Account (للسكرابر)

1. ⚙️ Project Settings → **Service Accounts** → **Generate new private key**
2. سيتم تنزيل ملف JSON. **لا ترفعه على Git.**

### الخطوة 3 — رفع الكود إلى GitHub

```bash
cd freelance-radar
git init
git add .
git commit -m "Initial commit"
gh repo create freelance-radar --private --source=. --push
```

### الخطوة 4 — إضافة GitHub Secrets

من المستودع على GitHub → **Settings → Secrets and variables → Actions** → **New repository secret**:

| اسم الـ Secret | القيمة |
|----------------|--------|
| `FIREBASE_SERVICE_ACCOUNT` | محتوى ملف JSON كاملاً (الذي نزّلته من الخطوة 2) |
| `FREELANCER_API_KEY` | (اختياري) من [developers.freelancer.com](https://developers.freelancer.com/) |

### الخطوة 5 — تشغيل الـ Workflow أول مرة

من تبويب **Actions** في GitHub → **FreelanceRadar Scraper** → **Run workflow**.

بعد دقيقتين راح ترى الوظائف في Firestore (تبويب **Firestore Database** في Firebase console).

من هنا فصاعداً، الـ scraping يعمل تلقائياً كل 30 دقيقة.

### الخطوة 6 — ربط Flutter بـ Firebase

```bash
# تثبيت أداة flutterfire (مرة واحدة على جهازك)
dart pub global activate flutterfire_cli

cd mobile
flutter pub get

# سيسألك أي مشروع Firebase تريد ربطه — اختر مشروعك
flutterfire configure
```

هذا الأمر سيُنشئ:
- `lib/firebase_options.dart` بمفاتيح حقيقية
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### الخطوة 7 — تشغيل التطبيق

```bash
cd mobile
flutter run
```

---

## 🧪 اختبار محلي للسكرابر (اختياري)

إذا أردت تشغيل السكرابر يدوياً قبل دفعه:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate              # Windows
# source .venv/bin/activate        # Linux/Mac

pip install -r requirements.txt

# ضع ملف service account في backend/service-account.json
cp .env.example .env
# عدّل .env وحدد:
#   FIREBASE_CREDENTIALS_PATH=./service-account.json

python run.py
```

---

## 💸 حدود الـ Free Tier

| الخدمة | الحد المجاني | متوقع للاستخدام الشخصي |
|--------|--------------|---------------------------|
| **Firestore** | 50K قراءة + 20K كتابة + 1 GiB تخزين/يوم | ~500 وظيفة × 30 جولة/يوم = 15K كتابة ✓ |
| **GitHub Actions** | 2000 دقيقة/شهر (خاص) أو غير محدود (عام) | ~5 دقائق × 48 جولة/يوم = 7200 دقيقة. **لمستودع خاص → اجعله public أو زِد الفترة لساعة بدل 30 دقيقة** |

> 💡 **نصيحة**: لو المستودع خاص، عدّل `cron: "0 */1 * * *"` في `.github/workflows/scrape.yml` (كل ساعة بدل 30 دقيقة) لتبقى ضمن الـ 2000 دقيقة.

---

## ⚙️ كيف يعمل التصنيف؟

في `backend/services/ai_filter.py`:

- كلمات **عالية الصلة** (Flutter, React Native, تطبيق موبايل…): +0.3
- كلمات **متوسطة** (Firebase, أندرويد, Swift…): +0.15
- كلمات **ضعيفة** (برمجة, frontend…): +0.05
- كلمات **سلبية** (WordPress, SEO, ترجمة…): −0.5

النتيجة بين `0.0` و `1.0`. يُحفظ في Firestore فقط ما تجاوز
`MIN_RELEVANCE_SCORE` (افتراضي 0.3).

---

## 🔒 الأمان

- **القراءة**: مفتوحة (بيانات عامة من الأساس)
- **الكتابة**: ممنوعة من العملاء؛ تتم فقط من service-account
- **service account JSON**: محفوظ كـ GitHub Secret، لا يُرفع للريبو أبداً (مدرج في `.gitignore`)

---

## 🧑‍💻 Conventions

- **كود**: بالإنجليزي (أسماء دوال، متغيرات).
- **تعليقات/UI**: بالعربي.
- **Backend**: Python 3.11+, async/await throughout.
- **Mobile**: Flutter 3.19+, Dart 3.3+, RTL-first.

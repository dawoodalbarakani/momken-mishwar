# إعداد تطبيق السائق Mishwar (driver_app)

## متطلبات التشغيل
- Flutter SDK (غير مثبت على المضيف في هذه الجلسة → لم يُنفَّذ `flutter pub get` / `flutter build` / تحليل الكود)
- Dart SDK (يأتي مع Flutter)

## خطوات الإعداد
1. ثبّت Flutter SDK من https://docs.flutter.dev/get-install
2. وارد إلى مجلد التطبيق:
   ```bash
   cd apps/driver_app
   ```
3. ثبّت الحزم:
   ```bash
   flutter pub get
   ```
4. أنشئ ملف متغيرات البيئة (غير مضمن أي أسرار):
   ```bash
   cp .env.example .env   # إذا وُجد مثال؛ وإلا أنشئ .env يدوياً
   ```
   ثبّت هذه المتغيرات في بيئة البناء (لا تُcommits أي قيم حقيقية):
   - `MISHWAR_API_BASE_URL` — عنوان API القاعدة (المسار `/v1`)
   - `MISHWAR_WS_BASE_URL` — عنوان WebSocket لأحداث الرحلات والعروض
   - `MISHWAR_MAP_API_KEY` — مفتاح Google Maps Android SDK — **لا تُدرج في المستودع**.

   مرّر المفتاح إلى Gradle عبر متغير البيئة أو الخاصية:
   ```bash
   export MISHWAR_MAP_API_KEY="YOUR_RESTRICTED_ANDROID_MAPS_KEY"
   flutter run
   ```
   أو استخدم `-PMISHWAR_MAP_API_KEY=...` مع أمر Gradle. المفتاح المضمّن في APK يمكن استخراجه دائماً؛ قيّده في Google Cloud باسم الحزمة `com.mishwar.driver` وبصمة شهادة التوقيع، وفعّل Google Maps SDK for Android فقط عند الحاجة. **دوّر المفتاح الذي سبق تضمينه في المستودع**، لأن حذفه من الملف لا يبطل النسخ السابقة أو سجل Git.

## الخرائط (مطلوب استبدال stub)
الطبقات المُنشَأة تستخدم `StubMapProvider` التي تُطلق `UnimplementedError` على كل عملية. قبل النشر استبدلها بتنفيذ حقيقي (Google Maps Flutter أو flutter_map) مع مفتاح من لوحة المزود. راجع `lib/core/map_provider.dart`.

## تشغّل الترميز (l10n)
أضف إلى `pubspec.yaml` تحت قسم `flutter`:
```yaml
  generate: true
```
أنشئ `l10n.yaml`، ثم شغّل:
```bash
flutter gen-l10n
```
الملفات `lib/l10n/app_ar.arb` و `app_en.arb` تُترجَم إلى فئات `AppLocalizations`.

## ملخص حالة التنفيذ
- مسارات: `/` (مدخل/مصادقة)، `/register`، `/login`، `/otp`، `/documents`، `/home` (السائق)، `/offers`، `/ride-track/:rideId`، `/earnings`، `/earnings/payout-request`، `/profile`.
- تدفق المصادقة: تسجيل → طلب OTP → تحقق → دخول. لا رمز OTP ثابت، لا أسرار مضمنة.
- رفع المستندات عبر روابط رفع موقّعة من الخادم (no secret keys stored client-side).
- حالة الاعتماد: PENDING / APPROVED / REJECTED / SUSPENDED. لا يُسمح باستقبال رحلات قبل الاعتماد (verification_status=APPROVED).
- العروض: استلام عبر WebSocket/GET، قبول/رفض مع Idempotency-Key، انتهاء تلقائي بعد المهلة، منع رحلتين متعارضتين (رحلة نشطة واحدة)، منع القبول المزدوج.
- تتبع الرحلة: ASSIGNED → ARRIVING → ARRIVED → IN_PROGRESS → COMPLETED مع التحقق من الإسناد ورمز بدء الرحلة والإلغاء مع سبب/فاعل/توقيت.
- الأرباح: تمييز بين إجمالي الأجرة وعمولة المنصة وصافي مستحقات السائق والنقد المحصل ومستحقات المنصة. طلب تسوية/نزاع مالي.
- RTL، العربية افتراضية، الإنجليزية مدعومة.
- لم يُشغّل أو يُختبر التطبيق لعدم توافر Flutter SDK على المضيف.

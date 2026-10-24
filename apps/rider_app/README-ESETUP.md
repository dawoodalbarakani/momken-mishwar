# إعداد تطبيق راكب Mishwar (rider_app)

## متطلبات التشغيل
- Flutter SDK (غير مثبت على المضيف في هذه الجلسة → لم يُنفَّذ `flutter pub get` / `flutter build`)
- Dart SDK (يأتي مع Flutter)

## خطوات الإعداد
1. ثبّت Flutter SDK من https://docs.flutter.dev/get-install
2. وارد إلى مجلد التطبيق:
   ```bash
   cd apps/rider_app
   ```
3. ثبّت الحزم:
   ```bash
   flutter pub get
   ```
4. أنشئ ملف متغيرات البيئة من المثال (غير مضمن أي أسرار):
   ```bash
   cp .env.example .env   # إذا وُجد مثال؛否则 أنشئ .env يدوياً
   ```
   ثبّت هذه المتغيرات في بيئة البناء (لا تُ commits أي قيم حقيقية):
   - `MISHWAR_API_BASE_URL` — عنوان API القاعدة (المسار `/v1`)
   - `MISHWAR_WS_BASE_URL` — عنوان WebSocket لأحداث الرحلة
   - `MISHWAR_MAP_API_KEY` — مفتاح مزود الخرائط (Google Cloud Console / Mapbox studio) — **لا تُدرج في المستودع**

## الخرائط (مطلوب استبدال stub)
الطبقات المُنشَأة تستخدم `StubMapProvider` التي تُطلق `UnimplementedError`. قبل النشر استبدلها بتنفيذ حقيقي (Google Maps Flutter أو flutter_map) مع مفتاح من لوحة المزود. راجع `lib/core/map_provider.dart`.

## تشغّل الترميز (l10n)
أضف إلى `pubspec.yaml` תחת `flutter`:
```yaml
  generate: true
```
وأنشئ `l10n.yaml`، ثم شغّل:
```bash
flutter gen-l10n
```
الملفات `lib/l10n/app_ar.arb` و `app_en.arb` تُترجَم إلى فئات `AppLocalizations`.

## ملخص حالة التنفيذ
- شاشات التدفق متوفَّرة: تسجيل/دخول + OTP، الرئيسية، التقدير، طلب الرحلة، تتبع، إتمام.
- السعر آتي من الخادم فقط (لا سعر ثابت في التطبيق).
- لا رمز OTP ثابت، لا أسرار مضمنة.
- مزود الخرائط افتراضي stub يحتاج استبدال.
- لم يُشغّل أو يُختبر التطبيق لعدم توافر Flutter SDK.

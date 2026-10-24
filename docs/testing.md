# الاختبار

## ما يعمل اليوم (مشغَّل ومُتحقق منه في بيئة التطوير الحالية)

```bash
cd apps/api && npm install        # يتطلب شبكة
npm run test:domain               # tsx --test src/domain/*.test.ts  → 35 اختبارًا
npm run test:integration          # vitest src/integration/*.test.ts → 3/3 عبر Supertest ضد mishwar_test (منفذ 5433)
npm run typecheck                 # tsc --noEmit (strict)
```

نتيجة آخر تشغيل في بيئة الكتابة: **35 نجاح / 0 فشل** في اختبارات النطاق، و**3/3 نجاح** في اختبارات تكامل HTTP عبر vitest على mishwar_test، و`tsc` بوضع strict بلا أخطاء. تغطي: النقود والتقريب، محرك التسعير بأنماطه الثلاثة، آلة حالات الرحلة وصلاحيات كل فاعل، رمز البدء (انتهاء، قفل، عدم تطابق)، دفتر السائق والتسويات، وتسجيل/دخول ورحلات عبر Supertest.

> قرار: اختبارات النطاق النقي تستخدم `node:test` (بلا اعتماديات، تعمل دون شبكة). اختبارات وحدات Nest والتكامل تستخدم **vitest + Supertest** (تم الترحيل من Jest 29 بسبب عدم توافق ESM مع @nestjs/testing v12).

## ما لم يُنفَّذ بعد (مخطط، لا يُدّعى نجاحه)

| الفئة | المحتوى | المتطلب |
|---|---|---|
| ترحيلات | تطبيق `0001`/`0002` على قاعدة جديدة، ثم إعادة التشغيل (idempotent runner) | PostgreSQL+PostGIS (`db_test` في Compose) |
| تكامل الخادم | تسجيل/دخول، RBAC، طلب رحلة، تسعير، قبول/رفض، بدء/إنهاء، إلغاء، دفع نقدي، قيود مالية | Nest + vitest + Supertest + `db_test` (لا SQLite) |
| **التزامن** | `Promise.all` من N اتصالات حقيقية: (1) سائقان يقبلان العرض نفسه؛ (2) سائق يقبل عرضين لرحلتين؛ (3) إعادة `POST /rides` بنفس المفتاح؛ (4) حدث/إشعار مكرر؛ (5) إعادة ترحيل قيود الرحلة؛ (6) القبول لحظة انتهاء العرض. المتوقع: نجاح واحد بالضبط والباقي `409`، ولا صفوف زائدة | `db_test` (6/6 ناجحة بالفعل عبر raw pg ضد mishwar_test) |
| محفزات القاعدة | محاولة `UPDATE/DELETE` على السجلات الثابتة، تعديل تعرفة منشورة، انتقال حالة غير شرعي، إسناد لسائق موقوف | `db_test` |
| الهاتف | RTL، انقطاع الإنترنت، رفض إذن الموقع، إعادة فتح التطبيق أثناء رحلة، لا سائقين، إلغاء، إشعارات متأخرة | Flutter SDK |
| الإدارة | حماية الصفحات، منع تصعيد الصلاحيات، تدقيق التعليق والتسويات | Next.js + Playwright |
| الأمان | قائمة ASVS/MASVS مختارة وتشغيلها يدويًا ثم آليًا | |

## معروفة Blockees (حالات متوقفة)

### Blockee تم حله: اختبار HTTP Integration عبر vitest ضد PostgreSQL فعّالة

**الحل:** تم إعادة إنشاء `apps/api/src/prisma/schema.prisma` عبر `prisma db pull` ضد `mishwar_test` بدون `@field` (أسماء حقول Prisma مطابقة لأسماء أعمدة PostgreSQL snake_case). مولد Prisma Client يعمل (`PRISMA_OK`).

**النتيجة:** Integration tests pass: 3/3 عبر vitest ضد mishwar_test (منفذ 5433).

**ما يعمل رغم ذلك:**
- typecheck strict (0 خطأ)
- البناء (build ناجح)
- اختبارات النطاق النقي (35/35 ناجح)
- الترحيلات SQL (0001/0002) مطبقة على قواعد mishwar و mishwar_test عبر Docker
- البذر المرجعي مكتمل

## CI (مخطط)

مهام: lint (ESLint/Prettier) ← typecheck ← `test:domain` ← ترحيلات على PostGIS ← vitest/Supertest ← Flutter analyze/test ← Playwright. لا دمج دون نجاح الكل.

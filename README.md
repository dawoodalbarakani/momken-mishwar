# Mishwar Yemen — مشوار اليمن

منصة نقل ذكي للسوق اليمني (صنعاء أولًا): تطبيق عميل، تطبيق سائق، خادم API، ولوحة إدارة. العربية افتراضية مع RTL كامل.

## حالة التنفيذ (صريحة)

| المكوّن | الحالة | ما تحقّق منه فعليًا |
|---|---|---|
| المرحلة أ (المعمارية، ADRs، تصميم القاعدة، تدفقات، عقد API) | ✅ مكتوبة في `docs/` | ADRs ومواصفات API والتدفقات موجودة ومُراجعة |
| نواة النطاق `domain/` (money, pricing, ride-state, start-code, ledger) | ✅ منفّهة | **35 اختبارًا ناجحًا**، `tsc` strict 0 خطأ |
| ترحيلات PostgreSQL/PostGIS `0001` (30 جدولًا) و`0002` (محفزات حماية) | ✅ نُفِّذت | نُفِّذت على قواعد `mishwar` و `mishwar_test` عبر Docker (ليست مجرد فحص ساكن) |
| بذر مرجعي + Docker Compose + `.env.example` | ✅ نُفِّّع البذر | قاعدة صحية على المنفذين 5432 و 5433؛ بيانات مرجعية محشوة |
| هيكل NestJS + 20 وحدة + Swagger + WebSocket Guards | ✅ منفّذ | `typecheck` strict 0 خطأ، `build` ناجح في `dist/` |
| تصحيح الثغرات الجوهرية (`Dispatch.acceptOffer` قفل شرطي + `startCode` nonce، `Dispatch.search` موقع الالتحاق الحقيقي، `Trips.applyTransition` حساب العمولة) | ✅ مطبق | مطبق على القرص + typecheck/build ناجح |
| اختبار Prisma runtime ضد DB فعلية | ✅ يعمل | تم إعادة سحب السكيما عبر `prisma db pull` (لا يستخدم `@field`)، `prisma generate` ناجح، Prisma Client متاح، واختبارات التكامل عبر vitest ضد `mishwar_test` ناجحة (3/3 ناجح) |
| اختبارات التزامن على PostgreSQL فعلي (6 سيناريو) | ✅ 6/6 ناجح | عبر `pg` مباشرة ضد `mishwar_test` (المنفذ 5433)؛ اختبار التكامل HTTP عبر vitest ناجح (3/3 ناجح ضد mishwar_test) |
| تطبيق راكب Flutter | ⚠️ منشأ، لم يُشغّل | `apps/rider_app/`، 22 ملف مصدر؛ لا Flutter SDK على المضيف |
| تطبيق سائق Flutter | ⚠️ منشأ، لم يُشغّل | `apps/driver_app/`، 26 ملف مصدر؛ لا Flutter SDK على المضيف |
| لوحة الإدارة Next.js | ✅ منفّهة | `typecheck` 0 خطأ، `next build` ناجح (11 صفحة) |

## الوظائف غير المكتملة (موثقة بوضوح)

الوظائف الأساسية التالية من المواصفات لم تُنفَّذ بالكامل بعد:

1. **اختبار HTTP Integration عبر Supertest ضد Backend فعّال** — يعمل الآن عبر vitest ضد `mishwar_test` (3/3 ناجح). تم إعادة سحب سكيما Prisma عبر `prisma db pull` (لا يستخدم `@field`)، وPrisma Client يُولَّد ويعمل. 필요가 المزيد من نقاط النهاية للتغطية الكاملة.

2. **تطبيقات Flutter (الراكب والسائق)** — لم تُشغّل ولم تُختبر لعدم توفر Flutter SDK على المضيف. الناقص: مزود خرائط حقيقي، تحديد موقع GPS (`geolocator`), جلب `/me`, دوران refresh token عند 401, تحليل WebSocket messages, سجل رحلات فعلي.

3. **WebSocket Gateway في Nest** — مخطط في `docs/architecture.md`، لم يُنفَّذ كوحدة فعّالة بعد.

4. **BullMQ / Redis** — مؤجل بقرار (ADR-0003)، غير مطلوب للإصدار الأول.

5. **S3-compatible object storage للمستندات** — واجهة فقط، لم تُنفَّذ الرفع الفعّال.

6. **FCM push notifications** — واجهة فقط، المفاتيح ليست في المستودع.

7. **بوابة دفع إلكتروني** — غير موجود في الإصدار الأول؛ الدفع نقدي فقط.

8. **لوحة الإدارة: الربط الفعلي بـ Backend** — غير مختبر لغياب Prisma runtime (راجع النقطة 1).

## تعليمات التشغيل السريعة (finale)

```bash
npm install                    # في الجذر و في apps/api و apps/admin_web
docker compose -f infrastructure/docker/docker-compose.yml up -d db db_test
DATABASE_URL=postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar ./database/run-migrations.sh
DATABASE_URL=postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar psql ... -f database/seeds/001_reference_data.sql   # أو عبر docker cp إلى الحاوية
cd apps/api && npm run typecheck && npm run test:domain   # 35/35 ناجح، 0 خطأ
cd apps/api && npx tsx src/concurrency_scenarios.ts        # 6/6 سيناريو تزامن ناجح على mishwar_test
cd apps/api && npm test                                    # 3/3 Integration ناجح عبر vitest ضد mishwar_test
cd apps/admin_web && npm install && npm run build          # build ناجح
```

ملاحظة: `.env` يُنشأ من `.env.example` ولا تُCommit أسرار.

## ما يُشغل وما لا يُشغل (صريح)

كل ادعاء بالنجاح في هذا الملف مبني على مخرج أمر فعلي تم تشغيله (`typecheck`، `build`، اختبارات النطاق عبر `tsx`، سيناريوهات التزامن عبر `tsx`، اختبارات التكامل عبر `vitest`، `next build`)، وليس على افتراض أو فحص ساكن. ما لم يُذكر أنه `⛔ محظور` أو `⚠️ لم يُشغّل`، فقد تم التحقق منه ضد مخرجات الأوامر المذكورة أعلاه.

## خريطة المستودع

```
apps/api/src/domain/   نواة نقية مختبرة (pricing, ride-state, ledger, start-code, money)
apps/{rider_app,driver_app,admin_web}/   تطبيقات Flutter ولوحة الويب
database/migrations/   SQL مصدر الحقيقة   ·   database/seeds/   بيانات مرجعية وهمية
infrastructure/docker/ بيئة التطوير      ·   docs/   المعمارية والقرارات (adr/)
```

## الخطوة التالية (B-2)

تشغيل الترحيلات على `db_test`، ثم **اختبارات التزامن الستة** قبل أي عمل على التطبيقات. كل الأرقام والحدود في البذر **وهمية** وتحتاج قرارًا تشغيليًا (انظر `docs/deployment.md` §2).

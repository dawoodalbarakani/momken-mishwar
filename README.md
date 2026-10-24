# Mishwar Yemen — مشوار اليمن

منصة نقل ذكي للسوق اليمني (صنعاء أولًا): تطبيق عميل، تطبيق سائق، خادم API، ولوحة إدارة. العربية افتراضية مع RTL كامل.

## حالة التنفيذ (صريحة)

| المكوّن | الحالة | ما تحقّق منه فعليًا |
|---|---|---|
| المرحلة A: المعمارية، ADRs، تصميم القاعدة، تدفقات، عقد API | ✅ مكتوبة في `docs/` | مراجعة يدوية |
| نواة النطاق `apps/api/src/domain` (نقود، تسعير بثلاثة أنماط، آلة حالات الرحلة، رمز البدء، دفتر السائق) | ✅ منفّذة | **35 اختبارًا ناجحًا**، و`tsc` strict بلا أخطاء |
| ترحيلات PostgreSQL/PostGIS `0001` (30 جدولًا) و`0002` (محفزات حماية) | ⚠️ مكتوبة | فحص ساكن فقط؛ **لم تُنفَّذ على PostgreSQL** |
| بذر مرجعي + Docker Compose + `.env.example` | ⚠️ مكتوبة | لم تُشغَّل (لا Docker في بيئة الكتابة) |
| هيكل NestJS والوحدات العشرون وSwagger وWebSocket | ⬜ لم يبدأ | يتطلب `npm install` (شبكة) |
| اختبارات التكامل والتزامن على PostgreSQL | ⬜ لم تبدأ | مصمَّمة في `docs/testing.md` |
| تطبيقا Flutter | ⬜ لم يبدآ | يتطلب Flutter SDK |
| لوحة الإدارة Next.js | ⬜ لم تبدأ | |

## تشغيل ما هو جاهز

```bash
npm install
npm run test:domain      # اختبارات نواة النطاق
npm run typecheck
# مع Docker:
cp .env.example .env && npm run db:up
export DATABASE_URL=postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar
npm run db:migrate && npm run db:seed:reference
```

## خريطة المستودع

```
apps/api/src/domain/   نواة نقية مختبرة (pricing, ride-state, ledger, start-code, money)
apps/{rider_app,driver_app,admin_web}/   (فارغة بعد)
database/migrations/   SQL مصدر الحقيقة   ·   database/seeds/   بيانات مرجعية وهمية
infrastructure/docker/ بيئة التطوير      ·   docs/   المعمارية والقرارات (adr/)
```

## الخطوة التالية (B-2)

هيكل Nest (Auth/OTP، Users، ServiceAreas، Pricing فوق `domain/pricing.ts`، RideRequests مع `Idempotency-Key`)، تشغيل الترحيلات على `db_test`، ثم **اختبارات التزامن الستة** قبل أي عمل على التطبيقات. كل الأرقام والحدود في البذر **وهمية** وتحتاج قرارًا تشغيليًا (انظر `docs/deployment.md` §2).

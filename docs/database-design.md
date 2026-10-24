# تصميم قاعدة البيانات

الملفات: `database/migrations/0001_init_schema.sql` (30 جدولًا + عرض) و`0002_integrity_guards.sql` (محفزات).
> **الحالة:** كُتبت ودُقّقت يدويًا وفُحصت ساكنًا فقط (أقواس، علامات `$$`). **لم تُنفَّذ على PostgreSQL فعلي** لأن بيئة الكتابة بلا PostgreSQL أو شبكة. أول خطوة على جهاز فيه Docker: `npm run db:up && DATABASE_URL=... npm run db:migrate`.

## 1. مجموعات الجداول

| المجموعة | الجداول |
|---|---|
| مرجعية | `currencies`، `service_areas`، `dispatch_settings`، `vehicle_types`، `document_types` |
| هوية | `users`، `user_roles`، `otp_challenges`، `refresh_tokens`، `device_tokens` |
| ملفات | `customer_profiles`، `saved_places`، `driver_profiles`، `vehicles`، `driver_documents` |
| تسعير | `pricing_rules`، `fixed_routes` |
| رحلات | `rides`، `ride_events`، `ride_offers`، `driver_location_updates` |
| مال | `payment_records`، `driver_payouts`، `driver_ledger_entries`، العرض `driver_balances` |
| تفاعل ودعم | `ratings`، `support_tickets`، `support_ticket_notes`، `notifications` |
| حوكمة | `audit_logs`، `idempotency_keys` |

جداول أُضيفت عن قائمة الطلب مع مبررها: `user_roles` (شخص واحد قد يكون عميلًا وسائقًا)، `otp_challenges` و`refresh_tokens` (OTP والتدوير)، `dispatch_settings` (قيم المطابقة قابلة للتهيئة بلا قيم افتراضية)، `document_types` (قابلية تهيئة الوثائق)، `fixed_routes`، `saved_places`، `support_ticket_notes`.

## 2. المال والعملة

- في القاعدة: `NUMERIC(18,2)` وعمود `currency_code` في كل صف مالي. لا `float` في أي مكان.
- في الشيفرة: أعداد صحيحة بوحدة العملة الصغرى (`minor`) داخل `domain/money.ts`؛ التحويل عند حدود المستودع باستخدام `currencies.minor_unit_digits` (0..2). الضرب والتقريب بـ `BigInt` نصف-للأعلى.
- العمولة تُحسب مرة واحدة عند التسعير وتُخزَّن؛ دفتر الأستاذ يقرأ القيم المخزنة ولا يعيد حسابها. قيد `CHECK` يضمن `commission + driver_net = final_total` عند الإكمال.
- العملة الافتراضية تُحدد من `service_areas.currency_code`. أُدرجت YER فعّالة وUSD/SAR معطّلة في البذر؛ الاختيار والتحويل قرار تشغيلي، ولا يوجد تحويل عملات في الكود عمدًا.

## 3. الإسناد الذرّي ومنع التعارض

المعاملة عند قبول عرض (تُنفَّذ من `Dispatch`/`Trips`، وترتيب الأقفال ثابت: العرض ← الرحلة ← السائق):

```sql
BEGIN;
SELECT * FROM ride_offers WHERE id = $offer AND driver_id = $driver FOR UPDATE;
-- التطبيق: إن كان ACCEPTED لنفس السائق => نجاح متكرر (idempotent)، وإن لم يكن PENDING => 409.

UPDATE rides
   SET status = 'ASSIGNED', driver_id = $driver, vehicle_id = $vehicle,
       assigned_at = now(), start_code_nonce = $nonce,
       start_code_expires_at = now() + make_interval(mins => $ttl)
 WHERE id = $ride AND status = 'SEARCHING' AND driver_id IS NULL;   -- يجب أن يعدّل صفًا واحدًا بالضبط

UPDATE ride_offers SET status = 'ACCEPTED' WHERE id = $offer AND status = 'PENDING';
UPDATE ride_offers SET status = 'CANCELLED' WHERE ride_id = $ride AND id <> $offer AND status = 'PENDING';
INSERT INTO ride_events (...) VALUES (...);
COMMIT;
```

| الخطر | ما يمنعه في القاعدة |
|---|---|
| سائقان يقبلان الرحلة نفسها | التحديث المشروط `status='SEARCHING' AND driver_id IS NULL` (الثاني يعدّل 0 صفوف) + الفهرس الفريد `ride_offers_one_accepted_uq` |
| سائق يقبل رحلتين متعارضتين | الفهرس الفريد الجزئي `rides_one_active_per_driver_uq` |
| قبول العرض نفسه مرتين | قفل `FOR UPDATE` على العرض + محفز `guard_ride_offer_update` (لا يتغير إلا `PENDING`) |
| قبول عرض منتهي | المحفز نفسه يقارن `clock_timestamp()` بـ `expires_at` |
| إسناد لسائق غير معتمد/غير متصل/موقوف | `guard_ride_update` يتحقق تحت `FOR SHARE` على صف السائق + قيد `driver_online_requires_approval` + محفز `driver_force_offline` |
| مركبة لا تخص السائق أو نوعها مختلف | `guard_ride_update` |
| عرض مقبول لا يطابق الرحلة | محفز مؤجَّل `ride_offers_accepted_matches_ride` عند الالتزام |
| انتقال حالة غير شرعي أو تعديل رحلة منتهية | `guard_ride_update` (جدول انتقالات + تجميد الحالات النهائية + تثبيت السعر والمسار) |
| طلبان نشطان لعميل واحد (مثلًا بعد انقطاع) | `rides_one_active_per_customer_uq` + `Idempotency-Key` |

الرحلات المجدولة غير مدعومة في الإصدار الأول، لذلك «سائق واحد = رحلة نشطة واحدة» يكفي ويغني عن قيد تداخل زمني. عند إضافتها يلزم قيد استبعاد (`EXCLUDE USING gist`) على المدى الزمني.

## 4. سلامة السجلات

- `ride_events` و`audit_logs` و`driver_ledger_entries`: ممنوع `UPDATE`/`DELETE`/`TRUNCATE` (محفزات). التصحيح بقيد `REVERSAL` أو `ADJUSTMENT` يحمل `created_by` و`memo`.
- ممنوع `DELETE` على `rides` و`payment_records` و`driver_payouts` و`users` (حذف المستخدم = إخفاء هوية بتحديث `status='DELETED'`).
- `pricing_rules` قابلة للتعديل وهي `DRAFT` فقط؛ بعد النشر لا يتغير إلا `ACTIVE→RETIRED`.
- `driver_payouts`: قيد «أربع أعين» — المراجع ≠ الطالب.
- التكرار المالي: `driver_ledger_entries.idempotency_key` فريد + فهرس فريد على `(ride_id, entry_type)` لقيدي الرحلة.

## 5. الجغرافيا

`geography(…, 4326)` مع فهارس GiST؛ فهرس جزئي لمواقع السائقين المتصلين فقط. `driver_profiles.last_location` هو الموقع الحار (يُحدَّث بكثافة)، و`driver_location_updates` السجل التاريخي القابل للتقليم. حدود صنعاء في البذر مستطيل تقريبي مؤقت.

## 6. الزمن

كل الأعمدة `timestamptz` (UTC). `service_areas.timezone` (IANA) للعرض والتقارير فقط.

## 7. الاحتفاظ بالبيانات

| البيانات | السياسة المقترحة (تُثبَّت بقرار تشغيلي/قانوني) |
|---|---|
| `driver_location_updates` | حذف الأقدم من نافذة قصيرة قابلة للتهيئة؛ الإبقاء على مواقع الرحلات المتنازع عليها حتى إغلاق النزاع |
| `otp_challenges`، `idempotency_keys`، `refresh_tokens` المنتهية | حذف دوري |
| `rides`، `ride_events`، سجلات المال، `audit_logs` | تُحفظ؛ أي أرشفة/إخفاء هوية لاحقًا بقرار موثّق |

## 8. Prisma

الترحيلات SQL-first (ADR-0002). يُولَّد `schema.prisma` بـ `prisma db pull`، وأعمدة `geography` تظهر `Unsupported(...)`؛ استعلامات PostGIS والأقفال (`FOR UPDATE`) تُكتب بـ `$queryRaw` داخل `$transaction`.

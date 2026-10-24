# مواصفة الـ API (v1) — مسودة العقد

> **الحالة: مخطط.** لا يوجد خادم Nest يعمل بعد. هذا العقد يُنقل إلى `packages/api_contracts` ويُولَّد منه OpenAPI عند بدء المرحلة B-2.

## اتفاقيات

- المسار الأساسي `/v1`، JSON، `Accept-Language: ar|en`.
- المصادقة: `Authorization: Bearer <access JWT>`؛ الـ Refresh بتدوير.
- العمليات الكاتبة القابلة للتكرار تتطلب `Idempotency-Key` (8–128 حرفًا). نفس المفتاح + نفس الجسم ⇒ نفس الرد؛ نفس المفتاح + جسم مختلف ⇒ `422`.
- الأموال نصوص عشرية `"1500.00"` مع `currency`؛ لا أعداد عائمة في JSON.
- الأوقات ISO-8601 UTC.
- صيغة الخطأ الموحدة: `{ "error": { "code": "RIDE_ALREADY_ASSIGNED", "message_ar": "...", "message_en": "...", "request_id": "..." } }`.
- الترقيم: `?limit=&cursor=`.

## نقاط النهاية (الإصدار الأول)

| المجموعة | الطريقة والمسار | الدور | ملاحظة |
|---|---|---|---|
| Auth | `POST /auth/otp/request` · `POST /auth/otp/verify` · `POST /auth/refresh` · `POST /auth/logout` | عام / مسجّل | حدود محاولات وإعادة إرسال |
| Auth (موظفون) | `POST /admin/auth/login` | موظف | بريد + كلمة مرور، قفل بعد الفشل |
| الملف | `GET/PATCH /me` · `GET/POST/DELETE /me/saved-places` | مسجّل | |
| تقدير | `POST /quotes` | CUSTOMER | يعيد السعر من الخادم و`rule_version` |
| الرحلات | `POST /rides` · `GET /rides/active` · `GET /rides/{id}` · `POST /rides/{id}/cancel` · `GET /rides` | CUSTOMER | `Idempotency-Key` على الإنشاء والإلغاء |
| عروض السائق | `GET /driver/offers` · `POST /offers/{id}/accept` · `POST /offers/{id}/reject` | DRIVER | القبول ذرّي |
| تنفيذ الرحلة | `POST /rides/{id}/en-route` · `/arrived` · `/start` (جسم: `code`) · `/complete` | DRIVER المسند | `start` يتحقق من الرمز |
| رمز البدء | `GET /rides/{id}/start-code` | CUSTOMER المالك | مشتق، لا يُخزَّن |
| السائق | `PUT /driver/availability` · `POST /driver/location` (دفعات) · `GET /driver/earnings` · `GET /driver/ledger` · `POST /driver/payout-requests` | DRIVER | `location` يتضمن `recorded_at` |
| تسجيل السائق | `POST /driver/profile` · `POST /driver/vehicles` · `POST /driver/documents` (روابط رفع موقّعة) | DRIVER | |
| التقييم والبلاغات | `POST /rides/{id}/rating` · `POST /rides/{id}/report` · `GET /support/tickets` | الأطراف | |
| الإدارة — سائقون | `GET /admin/drivers` · `POST /admin/drivers/{id}/approve|reject|suspend` | OPS/ADMIN | يكتب `audit_logs` |
| الإدارة — رحلات | `GET /admin/rides` · `GET /admin/rides/{id}/events` · `POST /admin/rides/{id}/cancel` | SUPPORT/OPS | حجب بيانات حسب الدور |
| الإدارة — تسعير | `GET/POST /admin/pricing-rules` · `POST /admin/pricing-rules/{id}/preview|publish` | OPS/ADMIN | الإصدارات غير قابلة للتعديل بعد النشر |
| الإدارة — مال | `GET /admin/payments` · `GET /admin/driver-balances` · `POST /admin/payouts/{id}/approve` · `GET /admin/reports/*` | FINANCE/ADMIN | مراجع ≠ طالب |
| صحة | `GET /health/live` · `GET /health/ready` | عام | |

## أحداث WebSocket

`offer.created` · `offer.expired` · `ride.updated` (يحمل `ride_version`) · `driver.location` (مع `age_s`) · `notification.created`. الاتصال بتوكن؛ كل غرفة مقيّدة بطرفي الرحلة المخوّلين.

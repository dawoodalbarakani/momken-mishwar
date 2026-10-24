# تدفقات المستخدم

## 1. دورة حياة الرحلة

```mermaid
stateDiagram-v2
  [*] --> SEARCHING: العميل يطلب (Idempotency-Key)
  SEARCHING --> ASSIGNED: سائق يقبل (إسناد ذرّي)
  SEARCHING --> NO_DRIVER_FOUND: انتهت مهلة البحث
  SEARCHING --> CANCELLED: العميل / النظام / الموظف
  ASSIGNED --> ARRIVING: السائق في الطريق
  ARRIVING --> ARRIVED: وصل لنقطة الالتقاء
  ARRIVED --> IN_PROGRESS: رمز البدء صحيح
  IN_PROGRESS --> COMPLETED: السائق ينهي الرحلة
  ASSIGNED --> CANCELLED: العميل / السائق / الموظف + السبب
  ARRIVING --> CANCELLED: العميل / السائق / الموظف + السبب
  ARRIVED --> CANCELLED: العميل / السائق / الموظف + السبب
  IN_PROGRESS --> CANCELLED: موظف فقط + سبب
  COMPLETED --> [*]
  CANCELLED --> [*]
  NO_DRIVER_FOUND --> [*]
```

هذه الحالات مطبقة في `domain/ride-state.ts` (مختبرة) ومكررة كمحفز في `0002`. كل إلغاء يحفظ الفاعل (`cancelled_by_role`) والسبب والتوقيت.

## 2. طلب رحلة وقبولها

```mermaid
sequenceDiagram
  participant C as Rider App
  participant API as API
  participant DB as PostgreSQL
  participant D as Driver App
  C->>API: POST /v1/quotes {pickup, destination}
  API->>DB: قاعدة التسعير الفعّالة + مسار ثابت؟
  API-->>C: سعر مقدّر + rule_version (مدة صلاحية قصيرة)
  C->>API: POST /v1/rides + Idempotency-Key
  API->>DB: INSERT rides (SEARCHING) + price snapshot
  API-->>C: 201 ride (أو نفس الرد عند التكرار)
  API->>DB: اختيار مرشحين (PostGIS) + INSERT ride_offers
  API-->>D: WS/Push: عرض جديد (ينتهي في expires_at)
  D->>API: POST /v1/offers/{id}/accept + Idempotency-Key
  API->>DB: معاملة الإسناد الذرّي
  API-->>D: 200 مسندة (أو 409 إن سبقه غيره)
  API-->>C: WS/Push: السائق والمركبة + رمز البدء
```

## 3. استعادة الحالة بعد انقطاع

1. التطبيق يفتح → `GET /v1/rides/active` (يعيد الرحلة الحالية للعميل أو السائق أو لا شيء).
2. يعرض الشاشة المطابقة لـ `status` ويعرض عمر آخر موقع للسائق.
3. يعيد فتح WebSocket ويستقبل الأحداث ذات `ride_version` الأحدث فقط.
4. أي طلب كتابة معلّق يُعاد بنفس `Idempotency-Key`؛ الرد المخزَّن يُعاد دون تكرار الأثر.
5. إن اختلفت حالة الهاتف عن الخادم، **الخادم يغلب** ويُعرض للمستخدم التغيير (مثلًا «أُلغيت الرحلة»).

## 4. تفعيل السائق

تسجيل ← رفع المستندات المطلوبة (من `document_types`) ← `PENDING` ← مراجعة موظف مخوّل ← `APPROVED`/`REJECTED` (مع سبب). السائق `PENDING` أو `REJECTED` أو `SUSPENDED` لا يستطيع الاتصال بالمنصة (قيد قاعدة + محفز).

## 5. الإغلاق المالي لرحلة نقدية

عند `COMPLETED`: `payment_records` (`CASH`, `COLLECTED_BY_DRIVER`) + قيدان في دفتر السائق: `EARNING +صافي` و`CASH_COLLECTED −الإجمالي`، فيظهر على السائق للمنصة مبلغ العمولة. التسوية بطلب `driver_payouts` يراجعه موظف مالي مختلف عن الطالب، ثم قيد تسوية. التفاصيل: `domain/ledger.ts`.

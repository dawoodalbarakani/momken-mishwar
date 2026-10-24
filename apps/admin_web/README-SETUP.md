# إعداد لوحة الإدارة (apps/admin_web)

## المتطلبات
- Node.js ≥ 22 (يُستخدم v24 في هذه الجلسة) و npm ≥ 12.
- شبكة إنترنت لتنفيذ `npm install` (غير مضمونة النجاح في هذه الجلسة).
- Backend فعال يخدم العقد على `/v1` وفقًا لـ `docs/api-specification.md`.

## تثبيت التبعيات
```bash
cd /workspaces/momken-mishwar/apps/admin_web
npm install
```

## متغيرات البيئة
انسخ `.env.example` إلى `.env.local` وضبط القيم לפי البيئة:

```bash
cp .env.example .env.local
```

| المتغير | القيمة الوهمية (التطوير) | 설명 |
|---|---|---|
| `NEXT_PUBLIC_API_BASE_URL` | `http://localhost:4000/v1` | قاعدة API للBackend |
| `NEXT_PUBLIC_APP_URL` | `http://localhost:3000` | عنوان التطبيق |

**لا تُCommit أسرار حقيقية.** `.env` محظور عبر `.gitignore` في جذر المستودع، و `.env.example` يحتوي قيمًا وهمية فقط.

## التشغيل في التطوير
```bash
npm run dev
# يفتح على http://localhost:3000
```

## البناء والفحص
```bash
npm run build      # بناء إنتاج (يحتاج node_modules و types)
npm run typecheck  # tsc --noEmit (strict)
npm run lint       # next lint (إذا توفر ESLint)
```

## الربط بـ Backend فعال
لوحة الإدارة تستدعي API حقيقي على `/v1` عبر `lib/api.ts`:
- `GET /v1/admin/drivers`، `POST /v1/admin/drivers/:id/approve|reject|suspend` (يكتب `audit_logs`)
- `GET /v1/admin/rides`، `GET /v1/admin/rides/:id/events`، `POST /v1/admin/rides/:id/cancel`
- `GET/POST /v1/admin/pricing-rules`، `POST /v1/admin/pricing-rules/:id/preview|publish`
- `GET /v1/admin/payments`، `GET /v1/admin/driver-balances`، `POST /v1/admin/payouts/:id/approve`، `GET /v1/admin/reports/*`
- `GET /v1/admin/audit`
- `POST /v1/admin/auth/login`

تأكد أن Backend يقبل طلبات من `http://localhost:3000` (CORS) ويصدّق JWT عبر رأس `Authorization: Bearer <token>`.

## المصادقة والصلاحيات (RBAC)
- الرمز يُخزّن في كوكي `SameSite=Lax` (`Secure` في HTTPS فقط) و `localStorage` للبيانات غير الحساسة.
- `lib/auth.ts`: `getToken/setToken/removeToken/getUser/isAuthenticated/hasRole` (فك ترميز JWT payload للعرض فقط، بدون التحقق من التوقيع من العميل).
- `lib/roles.ts`: خريطة الصفحات لكل دور وفقًا لـ `docs/security.md §29` ومنع تصعيد الصلاحيات.
- `middleware.ts` (الجذر يعيد تصدير `lib/middleware.ts`) يحمي `/drivers`, `/rides`, `/pricing`, `/finance`, `/support`, `/auth` ويوجه غير المصرح لهم إلى `/login`.

الأدوار المدعومة: `CUSTOMER, DRIVER, SUPPORT_AGENT, OPERATIONS_MANAGER, FINANCE_MANAGER, ADMIN, SUPER_ADMIN`.

## RTL والتصميم المتجاوب
- `<html dir="rtl" lang="ar">` في `app/layout.tsx`.
- الاتجاه عبر `direction: rtl` على `<html>` وليس عبر Tailwind plugin RTL مخصص.
- الشريط الجانبي والأعلى في `components/layout/rtl.tsx` مع قائمة تنقل تُظهر حسب الدور.
- متجاوب: هاتف، تابلت، سطح مكتب.

## قيود الأمان
- لا تُInclude أسرار حقيقية في المستودع (`AES`/`API Key` غير موجودة).
- أي وظيفة تعتمد على Backend غير فعال تُdocument كالتالي: **"تستدعي API حقيقي — غير مختبر لغياب Prisma runtime"** (انظر `docs/testing.md` blockee حول `@field` في `schema.prisma`).
- لا تُترك دوال أساسية كـ `TODO` دون توضيح.

## ملاحظات حول البناء
هذه الجلسة لا تضمن نجاح `npm install`؛ وبالتالي لم يُشغّل أو يُبنى Next.js فعليًا. الملفات موجهة لتكون كاملة وقابلة للبناء والتشغيل عند توفّر `node_modules` وBackend فعال.

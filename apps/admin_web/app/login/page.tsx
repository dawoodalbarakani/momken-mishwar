"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, FieldDescription, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { setToken, setUser, logout } from "@/lib/auth";
import { Shield, Lock } from "lucide-react";

const LoginSchema = z.object({
  email: z.string().email("الرجاء إدخال بريد إلكتروني صحيح"),
  password: z.string().min(6, "كلمة المرور قصيرة جداً"),
});

type FormValues = z.infer<typeof LoginSchema>;

export default function LoginPage() {
  const router = useRouter();
  const [form, setForm] = useState<FormValues>({ email: "", password: "" });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState({ text: "", type: "error" as "error" | "success" });

  const callbackUrl =
    typeof window !== "undefined" ? new URLSearchParams(window.location.search).get("callbackUrl") : null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErrors({});
    setSubmitting(true);
    try {
      const parsed = LoginSchema.safeParse(form);
      if (!parsed.success) {
        const fieldErrors: Record<string, string> = {};
        parsed.error.issues.forEach((err) => {
          fieldErrors[err.path[0] as string] = err.message;
        });
        setErrors(fieldErrors);
        return;
      }

      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:4000/v1"}/admin/auth/login`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json", "Accept-Language": "ar" },
          body: JSON.stringify({ email: form.email, password: form.password }),
        }
      );

      if (!res.ok) {
        let body: { error?: { code: string; message_ar: string; message_en: string; request_id: string } } = {};
        try { body = await res.json(); } catch { /* ignore */ }
        setMessage({
          text: body.error?.message_ar || "فشل تسجيل الدخول",
          type: "error",
        });
        return;
      }

      const data = await res.json();
      const token = data.token || data.accessToken || data.access_token;
      const user = data.user || { id: data.sub ?? "", email: form.email, roles: data.roles ?? [] };

      if (!token) {
        setMessage({ text: "لم يتم استلام رمز المصادقة", type: "error" });
        return;
      }

      setToken(token, { maxAge: 60 * 60 * 8 });
      setUser(user);
      setMessage({ text: "تم تسجيل الدخول بنجاح", type: "success" });

      const target = callbackUrl && callbackUrl.startsWith("/") ? callbackUrl : "/";
      router.push(target);
    } catch {
      setMessage({ text: "حدث خطأ غير متوقع", type: "error" });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-muted">
      <Card className="w-full max-w-md shadow-lg">
        <CardHeader className="flex flex-row items-center gap-2">
          <Shield className="size-8 text-primary" />
          <div>
            <CardTitle>تسجيل دخول الموظف</CardTitle>
            <CardDescription>لوحة إدارة منصة ميشوار اليمن. أدخل بريدك الإلكتروني وكلمة المرور.</CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {message.text && (
            <Alert variant={message.type === "success" ? "default" : "destructive"} className="mb-4">
              <AlertDescription>{message.text}</AlertDescription>
            </Alert>
          )}
          <form onSubmit={handleSubmit}>
            <FieldGroup>
              <Field data-invalid={!!errors.email}>
                <FieldLabel htmlFor="email">البريد الإلكتروني</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@mishwar.example"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  aria-invalid={!!errors.email}
                />
                {errors.email && <FieldDescription className="text-destructive">{errors.email}</FieldDescription>}
              </Field>
              <Field data-invalid={!!errors.password}>
                <FieldLabel htmlFor="password">كلمة المرور</FieldLabel>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  aria-invalid={!!errors.password}
                />
                {errors.password && <FieldDescription className="text-destructive">{errors.password}</FieldDescription>}
              </Field>
              <Button type="submit" disabled={submitting} className="w-full" loading={submitting}>
                <Lock data-icon="inline-start" /> دخول
              </Button>
            </FieldGroup>
          </form>
          <p className="mt-6 text-xs text-muted-foreground text-center">
            رمز المصادقة يُخزّن في كوكي آمن SameSite=Lax. لا تُخزّن أسرار في المتصفح.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

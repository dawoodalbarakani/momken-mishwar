"use client";
"use strict";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";
import { setToken, setUser, logout } from "@/lib/auth";
import { Mail, Shield, Lock } from "lucide-react";

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
        parsed.error.errors.forEach((err) => {
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
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <Card className="w-full max-w-md p-6 shadow-xl">
        <div className="flex items-center gap-2 mb-6">
          <Shield className="w-8 h-8 text-brand-600" />
          <h1 className="text-xl font-bold">تسجيل دخول الموظف</h1>
        </div>
        <p className="text-sm text-gray-600 mb-6">
          لوحة إدارة منصة ميشوار اليمن. أدخل بريدك الإلكتروني وكلمة المرور.
        </p>
        {message.text && (
          <div className={`mb-4 p-3 rounded text-sm ${message.type === "success" ? "bg-green-50 text-green-800 border border-green-200" : "bg-red-50 text-red-800 border border-red-200"}`}>
            {message.text}
          </div>
        )}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <label className="block text-sm font-medium">البريد الإلكتروني</label>
            <Input
              id="email"
              type="email"
              placeholder="admin@mishwar.example"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              error={!!errors.email}
            />
            {errors.email && <p className="text-xs text-red-600">{errors.email}</p>}
          </div>
          <div className="space-y-2">
            <label className="block text-sm font-medium">كلمة المرور</label>
            <Input
              id="password"
              type="password"
              placeholder="••••••••"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              error={!!errors.password}
            />
            {errors.password && <p className="text-xs text-red-600">{errors.password}</p>}
          </div>
          <Button type="submit" disabled={submitting} className="w-full" loading={submitting}>
            <Lock className="w-4 h-4 mr-2" /> دخول
          </Button>
        </form>
        <p className="mt-6 text-xs text-gray-500 text-center">
          رمز المصادقة يُخزّن في كوكي آمن SameSite=Lax. لا تُخزّن أسرار في المتصفح.
        </p>
      </Card>
    </div>
  );
}

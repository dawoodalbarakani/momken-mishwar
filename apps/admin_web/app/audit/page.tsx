"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { ShieldAlert, Search, Clock, User } from "lucide-react";

type AuditLog = {
  id: string;
  actor: string;
  actor_role: string;
  action: string;
  entity: string;
  entity_id: string;
  at: string;
  ip?: string;
};

export default function AuditPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiRequest<AuditLog[]>("/admin/audit?limit=100")
      .then((data) => setLogs(data || []))
      .catch((err) => setError(err instanceof ApiResponseError ? err.message_ar : "فشل تحميل سجل التدقيق"))
      .finally(() => setLoading(false));
  }, []);

  const filtered = logs.filter((l) => l.actor.includes(query) || l.action.includes(query) || l.entity_id.includes(query));

  if (loading) return <div className="p-4">جاري التحميل...</div>;

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1"><Search className="w-4 h-4" /> البحث في السجل</div>
            <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="الموظف، العملية، الكيان، المعرف" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET /v1/admin/audit`. السجل غير قابل للتعديل ويغطي: اعتماد/تعليق سائق، تغيير تعرفة، تسويات، دخول الإدارة. لم تُختبر لغياب Backend فعال.
          </p>
        </div>
        <div className="overflow-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>الوقت</TableHead>
                <TableHead>الموظف</TableHead>
                <TableHead>الدور</TableHead>
                <TableHead>العملية</TableHead>
                <TableHead>الكيان</TableHead>
                <TableHead>معرف الكيان</TableHead>
                <TableHead>عنوان IP</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.map((l) => (
                <TableRow key={l.id}>
                  <TableCell className="font-mono text-xs">{new Date(l.at).toLocaleString("ar-SA")}</TableCell>
                  <TableCell>{l.actor}</TableCell>
                  <TableCell className="font-mono text-xs text-gray-500">{l.actor_role}</TableCell>
                  <TableCell className="font-mono text-xs">{l.action}</TableCell>
                  <TableCell>{l.entity}</TableCell>
                  <TableCell className="font-mono text-xs">{l.entity_id}</TableCell>
                  <TableCell className="font-mono text-xs">{l.ip || "—"}</TableCell>
                </TableRow>
              ))}
              {filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-gray-500 py-4">لا توجد سجلات تدقيق</TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </Card>

      <Card className="mt-4 p-4">
        <h3 className="font-bold mb-2">نطاق السجل</h3>
        <ul className="text-sm text-gray-600 space-y-1 list-disc pl-5">
          <li>اعتماد / رفض / إيقاف سائق</li>
          <li>نشر / تعديل تعرفة</li>
          <li>تسويات مالية واعتماد صرف</li>
          <li>دخول وخرج المسؤولين الإداريين</li>
          <li>إلغاء رحلات من قبل الدعم / العمليات</li>
        </ul>
        <p className="mt-3 text-xs text-gray-500">
          ملاحظة: السجل يُطبَّق على الخادم (غير قابل للتعديل). الواجهة تعرض فقط ولا تُنفذ عمليات حساسة دون استدعاء API حقيقي مع تدقيق.
        </p>
      </Card>
    </div>
  );
}

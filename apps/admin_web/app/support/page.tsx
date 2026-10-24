"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Headset, ShieldAlert, Search, FileText } from "lucide-react";

type Ticket = { id: string; customer_name: string; category: string; status: string; created_at: string };
type Note = { id: string; ticket_id: string; author: string; body: string; created_at: string };
type Audit = { id: string; actor: string; action: string; entity: string; entity_id: string; at: string };

export default function SupportPage() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [notes, setNotes] = useState<Note[]>([]);
  const [audit, setAudit] = useState<Audit[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      apiRequest<Ticket[]>("/support/tickets?limit=50").catch(() => [] as Ticket[]),
      apiRequest<Note[]>("/support/ticket-notes?limit=50").catch(() => [] as Note[]),
      apiRequest<Audit[]>("/admin/audit?limit=50").catch(() => [] as Audit[]),
    ]).then(([t, n, a]) => {
      setTickets(t || []);
      setNotes(n || []);
      setAudit(a || []);
    }).catch((err) => setError(err instanceof ApiResponseError ? err.message_ar : "فشل تحميل بيانات الدعم"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="p-4">جاري التحميل...</div>;

  return (
    <div className="container-admin py-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2 p-4">
          <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
            <div className="flex-1"><Input placeholder="بحث في الشكاوى والملاحظات الداخلية" /></div>
            <p className="text-xs text-gray-500 hidden md:block">
              استدعي API حقيقي: `GET /v1/support/tickets`، `GET/POST /v1/support/ticket-notes`، `GET /v1/admin/audit`. لم تُختبر لغياب Backend فعال.
            </p>
          </div>
          <div className="overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>الشكوى</TableHead>
                  <TableHead>العميل</TableHead>
                  <TableHead>الفئة</TableHead>
                  <TableHead>الحالة</TableHead>
                  <TableHead>التاريخ</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {tickets.map((t) => (
                  <TableRow key={t.id}>
                    <TableCell className="font-mono text-xs">{t.id}</TableCell>
                    <TableCell>{t.customer_name}</TableCell>
                    <TableCell>{t.category}</TableCell>
                    <TableCell><Badge variant="outline">{t.status}</Badge></TableCell>
                    <TableCell className="font-mono text-xs">{new Date(t.created_at).toLocaleString("ar-SA")}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </Card>

        <div className="flex flex-col gap-4">
          <Card className="p-4">
            <h3 className="font-bold mb-2">ملاحظات داخلية</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto">
              {notes.map((n) => (
                <div key={n.id} className="p-3 border rounded text-sm">
                  <div className="flex justify-between text-xs mb-1"><span>{n.author}</span><span className="text-gray-400">{new Date(n.created_at).toLocaleString("ar-SA")}</span></div>
                  <div>{n.body}</div>
                </div>
              ))}
              {notes.length === 0 && <div className="text-sm text-gray-500">لا توجد ملاحظات داخلية</div>}
            </div>
          </Card>
          <Card className="p-4">
            <h3 className="font-bold mb-2">سجل التغييرات الحساس</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto">
              {audit.map((a) => (
                <div key={a.id} className="p-3 border rounded text-sm">
                  <div className="flex justify-between text-xs mb-1"><span>{a.actor}</span><span className="text-gray-400">{new Date(a.at).toLocaleString("ar-SA")}</span></div>
                  <div>{a.action} — {a.entity} ({a.entity_id})</div>
                </div>
              ))}
              {audit.length === 0 && <div className="text-sm text-gray-500">لا توجد سجلات تدقيق</div>}
            </div>
          </Card>
        </div>
      </div>

      <Card className="mt-6 p-4">
        <h3 className="font-bold mb-2">سجل العمليات المالية الحساسة</h3>
        <p className="text-sm text-gray-600">
          يُسجل كل عملية مالية حساسة (اعتماد صرف، تسوية) مع هوية الموظف والطابع الزمني. لا تُحذف السجلات المالية أو الرحلات المكتملة دون سياسة صريحة.
        </p>
      </Card>
    </div>
  );
}

"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Truck, Search, Clock, AlertTriangle } from "lucide-react";

type RideEvent = { event: string; at: string; note?: string };
type Ride = {
  id: string;
  customer_name: string;
  customer_phone: string;
  driver_name?: string;
  driver_phone?: string;
  status: string;
  fare?: string;
  created_at: string;
  events?: RideEvent[];
};

const STATUS_LABELS: Record<string, string> = {
  SEARCHING: "البحث عن سائق",
  ASSIGNED: "مسند لسائق",
  EN_ROUTE: "في الطريق",
  ARRIVED: "وصل",
  STARTED: "بدأت",
  COMPLETED: "مكتملة",
  CANCELLED: "ملغاة",
  NO_DRIVER_FOUND: "لا يوجد سائق",
};

export default function RidesPage() {
  const [rides, setRides] = useState<Ride[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiRequest<Ride[]>("/admin/rides?limit=50")
      .then((data) => setRides(data || []))
      .catch((err) => setError(err instanceof ApiResponseError ? err.message_ar : "فشل تحميل الرحلات"))
      .finally(() => setLoading(false));
  }, []);

  const filtered = rides.filter((r) => r.id.includes(query) || r.customer_name.includes(query));

  async function handleCancel(id: string) {
    if (!window.confirm("تأكيد إلغاء الرحلة؟")) return;
    try {
      await apiRequest(`/admin/rides/${id}/cancel`, { method: "POST" });
      setRides((prev) => prev.map((r) => (r.id === id ? { ...r, status: "CANCELLED" } : r)));
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل الإلغاء");
    }
  }

  if (loading) return <div className="p-4">جاري التحميل...</div>;

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 mb-4 items-end">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1"><Search className="w-4 h-4" /> البحث عن رحلة</div>
            <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="معرف الرحلة أو اسم العميل" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET /v1/admin/rides`، `GET /v1/admin/rides/:id/events`، `POST /v1/admin/rides/:id/cancel`. لم تُختبر لغياب Backend فعال.
          </p>
        </div>
        <div className="overflow-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>المعرف</TableHead>
                <TableHead>العميل</TableHead>
                <TableHead>السائق</TableHead>
                <TableHead>الحالة</TableHead>
                <TableHead>الأجرة</TableHead>
                <TableHead>التاريخ</TableHead>
                <TableHead>الإجراء</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.map((r) => (
                <TableRow key={r.id}>
                  <TableCell className="font-mono text-xs">{r.id}</TableCell>
                  <TableCell>{r.customer_name}</TableCell>
                  <TableCell>{r.driver_name || "—"}</TableCell>
                  <TableCell><Badge variant="outline">{STATUS_LABELS[r.status] || r.status}</Badge></TableCell>
                  <TableCell className="font-mono text-xs">{r.fare || "—"}</TableCell>
                  <TableCell className="font-mono text-xs">{new Date(r.created_at).toLocaleString("ar-SA")}</TableCell>
                  <TableCell>
                    <Button size="sm" variant="destructive" onClick={() => handleCancel(r.id)}>
                      <AlertTriangle className="w-3 h-3 mr-1" /> إلغاء
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-gray-500 py-4">لا توجد رحلات</TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </Card>

      <Card className="mt-4 p-4">
        <h3 className="font-bold mb-2">تسلسل أحداث الرحلة (ride_events)</h3>
        <p className="text-sm text-gray-600 mb-2">
          افتح تفاصيل الرحلة لعرض `GET /v1/admin/rides/:id/events`. البيانات تُحجب حسب دور الموظف (server-side).
        </p>
      </Card>
    </div>
  );
}

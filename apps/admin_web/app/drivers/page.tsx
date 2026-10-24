"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { useSession } from "@/components/providers/session-provider";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { User, Check, X, Pause, Search } from "lucide-react";

type Driver = {
  id: string;
  name: string;
  email: string;
  phone: string;
  status: "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED";
  created_at: string;
  documents?: string[];
};

const STATUS_LABELS: Record<string, { ar: string; color: "default" | "secondary" | "destructive" | "outline" }> = {
  PENDING: { ar: "في الانتظار", color: "outline" },
  APPROVED: { ar: "معتمد", color: "default" },
  REJECTED: { ar: "مرفوض", color: "destructive" },
  SUSPENDED: { ar: "موقوف", color: "secondary" },
};

export default function DriversPage() {
  const { user } = useSession();
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialog, setDialog] = useState<{ open: boolean; driverId: string; action: "approve" | "reject" | "suspend"; reason: string }>({
    open: false, driverId: "", action: "approve", reason: "",
  });

  useEffect(() => {
    apiRequest<Driver[]>("/admin/drivers")
      .then((data) => setDrivers(data || []))
      .catch((err) => {
        setError(err instanceof ApiResponseError ? err.message_ar : "فشل تحميل السائقين");
      })
      .finally(() => setLoading(false));
  }, []);

  async function handleAction(id: string, action: "approve" | "reject" | "suspend") {
    try {
      await apiRequest(`/admin/drivers/${id}/${action}`, {
        method: "POST",
        body: JSON.stringify({ reason: dialog.reason, actor_id: user?.id }),
      });
      setDialog({ open: false, driverId: "", action, reason: "" });
      setDrivers((prev) => prev.map((d) => (d.id === id ? { ...d, status: ({ approve: "APPROVED", reject: "REJECTED", suspend: "SUSPENDED" }[action] as Driver["status"]) } : d)));
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل تنفيذ الإجراء");
    }
  }

  if (loading) return <div className="p-4">جاري التحميل...</div>;

  return (
    <div className="container-admin py-6">
      <Card>
        <div className="p-4">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 mb-4">
            <h2 className="text-lg font-bold">إدارة السائقين</h2>
            <p className="text-sm text-gray-500">
              تستدعي API حقيقي: `GET /v1/admin/drivers` و `POST /v1/admin/drivers/:id/approve|reject|suspend` (يكتب `audit_logs`). لم تُختبر لغياب Backend فعال.
            </p>
          </div>
          <div className="overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>الاسم</TableHead>
                  <TableHead>البريد</TableHead>
                  <TableHead>الهاتف</TableHead>
                  <TableHead>الحالة</TableHead>
                  <TableHead>الإجراء</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {drivers.map((d) => (
                  <TableRow key={d.id}>
                    <TableCell>{d.name}</TableCell>
                    <TableCell className="font-mono text-xs">{d.email}</TableCell>
                    <TableCell className="font-mono text-xs">{d.phone}</TableCell>
                    <TableCell>
                      <Badge variant={STATUS_LABELS[d.status].color}>{STATUS_LABELS[d.status].ar}</Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        {d.status === "PENDING" && (
                          <Button size="sm" variant="default" onClick={() => setDialog({ open: true, driverId: d.id, action: "approve", reason: "" })}>
                            <Check className="w-3 h-3 mr-1" /> اعتماد
                          </Button>
                        )}
                        {d.status === "PENDING" && (
                          <Button size="sm" variant="destructive" onClick={() => setDialog({ open: true, driverId: d.id, action: "reject", reason: "" })}>
                            <X className="w-3 h-3 mr-1" /> رفض
                          </Button>
                        )}
                        {(d.status === "APPROVED" || d.status === "SUSPENDED") && (
                          <Button size="sm" variant="secondary" onClick={() => setDialog({ open: true, driverId: d.id, action: "suspend", reason: "" })}>
                            <Pause className="w-3 h-3 mr-1" /> {d.status === "APPROVED" ? "إيقاف" : "إعادة تفعيل"}
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
                {drivers.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center text-gray-500 py-4">لا توجد سجلات سائقين</TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </div>
      </Card>

      <Dialog open={dialog.open} onClose={() => setDialog({ open: false, driverId: "", action: dialog.action, reason: "" })} title="تأكيد الإجراء">
        <div className="space-y-3">
          <label className="block text-sm font-medium">السبب</label>
          <textarea
            className="w-full border rounded p-2 text-sm"
            value={dialog.reason}
            onChange={(e) => { dialog.reason = e.target.value; }}
          />
          <div className="flex justify-end gap-2 mt-4">
            <Button variant="outline" onClick={() => setDialog({ open: false, driverId: "", action: dialog.action, reason: "" })}>إلغاء</Button>
            <Button onClick={() => handleAction(dialog.driverId, dialog.action)} loading={false}>تنفيذ</Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}

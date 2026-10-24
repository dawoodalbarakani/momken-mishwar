"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { hasAnyRole } from "@/lib/auth";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useSession } from "@/components/providers/session-provider";
import { Truck, DollarSign, Users, Clock, AlertTriangle } from "lucide-react";

interface DashboardStats {
  rides_by_status?: Record<string, number>;
  completed_rides?: number;
  cancelled_rides?: number;
  online_drivers?: number;
  no_driver_requests?: number;
  total_fares?: string;
  total_commissions?: string;
}

export default function DashboardPage() {
  const { user, hasAnyRole: hasRole } = useSession();
  const [stats, setStats] = useState<DashboardStats>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiRequest<DashboardStats>("/admin/dashboard/stats");
        setStats(data);
      } catch (err) {
        if (err instanceof ApiResponseError) {
          setError(err.message_ar || err.message_en);
        } else {
          setError("فشل تحميل إحصائيات لوحة التحكم");
        }
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const ridesByStatus = stats.rides_by_status || {};

  return (
    <div className="container-admin py-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold">لوحة التحكم</h1>
          <p className="text-gray-600">مرحباً، {user?.email || "المستخدم"}</p>
        </div>
        <div className="flex gap-2">
          {hasRole(["ADMIN", "SUPER_ADMIN"]) && (
            <a href="/audit" className="text-sm px-3 py-2 rounded bg-gray-100 text-gray-700 hover:bg-gray-200">
              سجل التدقيق
            </a>
          )}
        </div>
      </div>

      {error && (
        <div className="mb-4 p-3 rounded bg-red-50 border border-red-200 text-red-800 text-sm">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <StatCard
          title="الرحلات حسب الحالة"
          value={Object.values(ridesByStatus).reduce((a, b) => a + b, 0)}
          icon={<Truck className="w-5 h-5" />}
          subtitle={
            <div className="text-xs space-y-1">
              {Object.entries(ridesByStatus).map(([k, v]) => (
                <div key={k} className="flex justify-between">
                  <span>{k}</span>
                  <span className="font-mono">{v}</span>
                </div>
              ))}
            </div>
          }
        />
        <StatCard title="الرحلات المكتملة" value={stats.completed_rides ?? 0} icon={<DollarSign className="w-5 h-5" />} />
        <StatCard title="الرحلات الملغاة" value={stats.cancelled_rides ?? 0} icon={<AlertTriangle className="w-5 h-5" />} />
        <StatCard title="السائقون المتصلون" value={stats.online_drivers ?? 0} icon={<Users className="w-5 h-5" />} />
        <StatCard title="طلبات بلا سائق" value={stats.no_driver_requests ?? 0} icon={<Clock className="w-5 h-5" />} />
        <StatCard
          title="إجمالي الأجور والعمولات"
          value={`${stats.total_fares ?? "0"} / ${stats.total_commissions ?? "0"} ريال`}
          icon={<DollarSign className="w-5 h-5" />}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <div className="p-4">
            <h2 className="font-bold text-lg mb-4">ملخص الحالة</h2>
            <p className="text-gray-600 text-sm">
              استدعت هذه الصفحة `GET /v1/admin/dashboard/stats`. في غياب خادم Backend فعال، تُعرض القيم الافتراضية
              وتُسجل خطأ الاستدعاء أعلاه. هذه الصفحة تستدعي API حقيقي ولم تُختبر لغياب Prisma runtime في الخادم.
            </p>
          </div>
        </Card>
        <Table>
          <TableHeader>
            <TableRow>
              <th>الصلاحيات المتوفرة</th>
              <th>الحالة</th>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow>
              <td>إدارة السائقين</td>
              <td>
                {hasRole(["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"]) ? (
                  <Badge variant="default">مفعل</Badge>
                ) : (
                  <Badge variant="secondary">غير مسموح</Badge>
                )}
              </td>
            </TableRow>
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, subtitle }: { title: string; value: React.ReactNode; icon: React.ReactNode; subtitle?: React.ReactNode }) {
  return (
    <Card className="p-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-500">{title}</p>
          <p className="text-2xl font-bold">{value}</p>
          {subtitle && <div className="mt-2">{subtitle}</div>}
        </div>
        <div className="p-2 rounded bg-brand-50 text-brand-600">{icon}</div>
      </div>
    </Card>
  );
}

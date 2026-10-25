import { parseJwt, type JwtPayload } from "@/lib/auth";
import { getServerToken } from "@/lib/auth-server";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
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

async function getServerUser(): Promise<{ email: string; roles: string[] } | null> {
  const token = await getServerToken();
  if (!token) return null;
  const payload = parseJwt<JwtPayload & { email?: string; sub?: string }>(token);
  if (!payload) return null;
  return {
    email: payload.email ?? "",
    roles: payload.roles ?? [],
  };
}

async function getDashboardStats(token: string | null): Promise<DashboardStats> {
  try {
    return await apiRequest<DashboardStats>("/admin/dashboard/stats", {
      next: { revalidate: 60 },
      token,
    });
  } catch {
    return {};
  }
}

function hasRole(roles: string[], allowed: string[]): boolean {
  return allowed.some((r) => roles.includes(r));
}

function StatCard({
  title,
  value,
  icon,
  subtitle,
}: {
  title: string;
  value: React.ReactNode;
  icon: React.ReactNode;
  subtitle?: React.ReactNode;
}) {
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

export default async function DashboardPage() {
  const user = await getServerUser();
  const token = await getServerToken();
  const stats = await getDashboardStats(token);

  const ridesByStatus = stats.rides_by_status || {};
  const canAccessAudit = hasRole(user?.roles ?? [], ["ADMIN", "SUPER_ADMIN"]);

  return (
    <div className="container-admin py-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold">لوحة التحكم</h1>
          <p className="text-gray-600">مرحباً، {user?.email || "المستخدم"}</p>
        </div>
        <div className="flex gap-2">
          {canAccessAudit && (
            <a
              href="/audit"
              className="text-sm px-3 py-2 rounded bg-gray-100 text-gray-700 hover:bg-gray-200"
            >
              سجل التدقيق
            </a>
          )}
        </div>
      </div>

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
        <Card className="p-4">
          <div>
            <h2 className="font-bold text-lg mb-4">ملخص الحالة</h2>
            <p className="text-gray-600 text-sm">
              تستدعي هذه الصفحة `GET /v1/admin/dashboard/stats` من الخادم باستخدام Server Component.
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
                {hasRole(user?.roles ?? [], ["OPERATIONS_MANAGER", "ADMIN", "SUPER_ADMIN"]) ? (
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

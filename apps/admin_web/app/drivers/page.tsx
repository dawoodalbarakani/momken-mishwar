import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { DriverRowActions } from "./driver-actions";

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

export default async function DriversPage() {
  const token = await getServerToken();

  let drivers: Driver[] = [];
  try {
    drivers = (await apiRequest<Driver[]>("/admin/drivers", {
      next: { revalidate: 60 },
      token,
    })) || [];
  } catch {
    drivers = [];
  }

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="p-4">
          <h2 className="text-lg font-bold mb-4">إدارة السائقين</h2>
          <p className="text-sm text-gray-500 mb-4">
            تستدعي API حقيقي: `GET /v1/admin/drivers` و `POST /v1/admin/drivers/:id/approve|reject|suspend`.
          </p>
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
                      <Badge variant={STATUS_LABELS[d.status].color}>
                        {STATUS_LABELS[d.status].ar}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <DriverRowActions driver={d} token={token} />
                    </TableCell>
                  </TableRow>
                ))}
                {drivers.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center text-gray-500 py-4">
                      لا توجد سجلات سائقين
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </div>
      </Card>
    </div>
  );
}

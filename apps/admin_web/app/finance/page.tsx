import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { ApprovePayoutButton } from "./approve-payout-button";

type Payment = { id: string; ride_id: string; amount: string; currency: string; status: string; created_at: string };
type Balance = { driver_id: string; driver_name: string; available: string; pending: string; currency: string };

export default async function FinancePage() {
  const token = await getServerToken();

  let payments: Payment[] = [];
  let balances: Balance[] = [];
  try {
    const [p, b] = await Promise.all([
      apiRequest<Payment[]>("/admin/payments?limit=50", { next: { revalidate: 60 }, token }).catch(() => [] as Payment[]),
      apiRequest<Balance[]>("/admin/driver-balances?limit=50", { next: { revalidate: 60 }, token }).catch(() => [] as Balance[]),
    ]);
    payments = p || [];
    balances = b || [];
  } catch {
    payments = [];
    balances = [];
  }

  const total = payments.reduce((a, b) => a + Number(b.amount || 0), 0);

  return (
    <div className="container-admin py-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <Card className="p-4">
          <div className="text-sm text-gray-500">إجمالي المدفوعات</div>
          <div className="text-2xl font-bold">{total.toFixed(2)} ريال</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">سجلات مدفوعات</div>
          <div className="text-2xl font-bold">{payments.length}</div>
        </Card>
        <Card className="p-4">
          <div className="text-sm text-gray-500">رصيد سائقين</div>
          <div className="text-2xl font-bold">{balances.length}</div>
        </Card>
      </div>

      <Card className="mb-6 p-4">
        <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
          <div className="flex-1">
            <Input placeholder="بحث في سجل المدفوعات" defaultValue="" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET /v1/admin/payments`، `GET /v1/admin/driver-balances`، `POST /v1/admin/payouts/:id/approve`.
          </p>
        </div>
        <div className="overflow-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>المعرف</TableHead>
                <TableHead>الرحلة</TableHead>
                <TableHead>المبلغ</TableHead>
                <TableHead>العملة</TableHead>
                <TableHead>الحالة</TableHead>
                <TableHead>التاريخ</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {payments.map((p) => (
                <TableRow key={p.id}>
                  <TableCell className="font-mono text-xs">{p.id}</TableCell>
                  <TableCell className="font-mono text-xs">{p.ride_id}</TableCell>
                  <TableCell className="font-mono text-xs">{p.amount}</TableCell>
                  <TableCell className="text-xs">{p.currency}</TableCell>
                  <TableCell><Badge variant="outline">{p.status}</Badge></TableCell>
                  <TableCell className="font-mono text-xs">{new Date(p.created_at).toLocaleString("ar-SA")}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </Card>

      <Card className="p-4">
        <h3 className="font-bold mb-2">مستحقات السائقين والتسويات (ثنائي الاعتماد)</h3>
        <p className="text-sm text-gray-600 mb-3">
          اعتماد التسويات يتطلب موظَّفين (ثنائي الاعتماد). استدعي `POST /v1/admin/payouts/:id/approve` مع تدقيق.
        </p>
        <div className="overflow-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>السائق</TableHead>
                <TableHead>متاح للسحب</TableHead>
                <TableHead>معلق</TableHead>
                <TableHead>العملة</TableHead>
                <TableHead>الإجراء</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {balances.map((b) => (
                <TableRow key={b.driver_id}>
                  <TableCell>{b.driver_name}</TableCell>
                  <TableCell className="font-mono text-xs">{b.available}</TableCell>
                  <TableCell className="font-mono text-xs">{b.pending}</TableCell>
                  <TableCell className="text-xs">{b.currency}</TableCell>
                  <TableCell>
                    <ApprovePayoutButton driverId={b.driver_id} token={token} />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}

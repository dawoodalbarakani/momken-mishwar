import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { CancelRideButton } from "./cancel-ride-button";
import { Search } from "lucide-react";

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

export default async function RidesPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const token = await getServerToken();
  const query = (searchParams.q || "").toLowerCase();

  let rides: Ride[] = [];
  try {
    rides = (await apiRequest<Ride[]>("/admin/rides?limit=50", {
      next: { revalidate: 60 },
      token,
    })) || [];
  } catch {
    rides = [];
  }

  const filtered = rides.filter(
    (r) => r.id.toLowerCase().includes(query) || r.customer_name.toLowerCase().includes(query)
  );

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 mb-4 items-end">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1">
              <Search className="w-4 h-4" /> البحث عن رحلة
            </div>
            <Input defaultValue={searchParams.q || ""} placeholder="معرف الرحلة أو اسم العميل" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET /v1/admin/rides`، `GET /v1/admin/rides/:id/events`، `POST /v1/admin/rides/:id/cancel`.
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
                    <CancelRideButton rideId={r.id} token={token} />
                  </TableCell>
                </TableRow>
              ))}
              {filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-gray-500 py-4">
                    لا توجد رحلات
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}

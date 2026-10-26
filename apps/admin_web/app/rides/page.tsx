import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { InputGroup, InputGroupInput, InputGroupAddon } from "@/components/ui/input-group";
import { Empty, EmptyHeader, EmptyTitle, EmptyDescription } from "@/components/ui/empty";
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
      <Card>
        <CardHeader>
          <div className="flex flex-col md:flex-row gap-3 items-end">
            <div className="flex-1">
              <InputGroup>
                <InputGroupAddon>
                  <Search className="size-4" />
                </InputGroupAddon>
                <InputGroupInput defaultValue={searchParams.q || ""} placeholder="معرف الرحلة أو اسم العميل" />
              </InputGroup>
            </div>
            <CardDescription className="text-xs hidden md:block">
              استدعي API حقيقي: `GET /v1/admin/rides`، `GET /v1/admin/rides/:id/events`، `POST /v1/admin/rides/:id/cancel`.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {filtered.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>لا توجد رحلات</EmptyTitle>
                <EmptyDescription>لم يتم العثور على رحلات.</EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
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
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

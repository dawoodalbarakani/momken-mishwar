import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { InputGroup, InputGroupInput, InputGroupAddon } from "@/components/ui/input-group";
import { Empty, EmptyHeader, EmptyTitle, EmptyDescription } from "@/components/ui/empty";
import { PublishPricingButton } from "./publish-pricing-button";
import { Search } from "lucide-react";

type PricingRule = {
  id: string;
  region: string;
  vehicle_type: string;
  base_fare: string;
  per_km: string;
  per_minute: string;
  commission_percent: string;
  version: number;
  is_published: boolean;
  created_at: string;
};

export default async function PricingPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const token = await getServerToken();
  const query = (searchParams.q || "").toLowerCase();

  let rules: PricingRule[] = [];
  try {
    rules = (await apiRequest<PricingRule[]>("/admin/pricing-rules?limit=50", {
      next: { revalidate: 60 },
      token,
    })) || [];
  } catch {
    rules = [];
  }

  const filtered = rules.filter(
    (r) => r.region.toLowerCase().includes(query) || r.vehicle_type.toLowerCase().includes(query)
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
                <InputGroupInput defaultValue={searchParams.q || ""} placeholder="المنطقة أو نوع المركبة" />
              </InputGroup>
            </div>
            <CardDescription className="text-xs hidden md:block">
              استدعي API حقيقي: `GET/POST /v1/admin/pricing-rules`، `POST /v1/admin/pricing-rules/:id/publish`.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {filtered.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>لا توجد قواعد تسعير</EmptyTitle>
                <EmptyDescription>لم يتم العثور على قواعد تسعير.</EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <div className="overflow-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>المنطقة</TableHead>
                    <TableHead>نوع المركبة</TableHead>
                    <TableHead>البداية</TableHead>
                    <TableHead>لكل كم</TableHead>
                    <TableHead>لكل دقيقة</TableHead>
                    <TableHead>العمولة %</TableHead>
                    <TableHead>الإصدار</TableHead>
                    <TableHead>الحالة</TableHead>
                    <TableHead>الإجراء</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.map((r) => (
                    <TableRow key={r.id}>
                      <TableCell>{r.region}</TableCell>
                      <TableCell>{r.vehicle_type}</TableCell>
                      <TableCell className="font-mono text-xs">{r.base_fare}</TableCell>
                      <TableCell className="font-mono text-xs">{r.per_km}</TableCell>
                      <TableCell className="font-mono text-xs">{r.per_minute}</TableCell>
                      <TableCell className="font-mono text-xs">{r.commission_percent}</TableCell>
                      <TableCell className="font-mono text-xs">v{r.version}</TableCell>
                      <TableCell>
                        <Badge variant={r.is_published ? "default" : "secondary"}>
                          {r.is_published ? "منشور" : "مسودة"}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        {!r.is_published && <PublishPricingButton ruleId={r.id} token={token} />}
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

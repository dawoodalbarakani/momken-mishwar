import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
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
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1">
              <Search className="w-4 h-4" /> البحث عن قاعدة تسعير
            </div>
            <Input defaultValue={searchParams.q || ""} placeholder="المنطقة أو نوع المركبة" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET/POST /v1/admin/pricing-rules`، `POST /v1/admin/pricing-rules/:id/publish`.
          </p>
        </div>
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
              {rules.length === 0 && (
                <TableRow>
                  <TableCell colSpan={9} className="text-center text-gray-500 py-4">
                    لا توجد قواعد تسعير
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

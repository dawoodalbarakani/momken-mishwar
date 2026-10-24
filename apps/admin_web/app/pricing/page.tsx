"use client";
"use strict";

import { useEffect, useState } from "react";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Percent, Truck, Search } from "lucide-react";

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

export default function PricingPage() {
  const [rules, setRules] = useState<PricingRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  useEffect(() => {
    apiRequest<PricingRule[]>("/admin/pricing-rules?limit=50")
      .then((data) => setRules(data || []))
      .catch((err) => setError(err instanceof ApiResponseError ? err.message_ar : "فشل تحميل قواعد التسعير"))
      .finally(() => setLoading(false));
  }, []);

  async function handlePublish(id: string) {
    try {
      await apiRequest(`/admin/pricing-rules/${id}/publish`, { method: "POST" });
      setRules((prev) => prev.map((r) => (r.id === id ? { ...r, is_published: true } : r)));
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل النشر");
    }
  }

  if (loading) return <div className="p-4">جاري التحميل...</div>;

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1"><Search className="w-4 h-4" /> البحث عن قاعدة تسعير</div>
            <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="المنطقة أو نوع المركبة" />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET/POST /v1/admin/pricing-rules`، `POST /v1/admin/pricing-rules/:id/preview|publish`. الإصدارات المنشورة غير قابلة للتعديل. لم تُختبر لغياب Backend فعال.
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
              {rules.filter((r) => r.region.includes(query) || r.vehicle_type.includes(query)).map((r) => (
                <TableRow key={r.id}>
                  <TableCell>{r.region}</TableCell>
                  <TableCell>{r.vehicle_type}</TableCell>
                  <TableCell className="font-mono text-xs">{r.base_fare}</TableCell>
                  <TableCell className="font-mono text-xs">{r.per_km}</TableCell>
                  <TableCell className="font-mono text-xs">{r.per_minute}</TableCell>
                  <TableCell className="font-mono text-xs">{r.commission_percent}</TableCell>
                  <TableCell className="font-mono text-xs">v{r.version}</TableCell>
                  <TableCell><Badge variant={r.is_published ? "default" : "secondary"}>{r.is_published ? "منشور" : "مسودة"}</Badge></TableCell>
                  <TableCell>
                    {!r.is_published && (
                      <Button size="sm" onClick={() => handlePublish(r.id)}>نشر</Button>
                    )}
                  </TableCell>
                </TableRow>
              ))}
              {rules.length === 0 && (
                <TableRow>
                  <TableCell colSpan={9} className="text-center text-gray-500 py-4">لا توجد قواعد تسعير</TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </Card>

      <Card className="mt-4 p-4">
        <h3 className="font-bold mb-2">معاينة السعر قبل النشر</h3>
        <p className="text-sm text-gray-600">
          استدعي `POST /v1/admin/pricing-rules/:id/preview` لجلب السعر التقديري من محرك التسعير قبل النشر. هذه الصفحة تستدعي API حقيقي ولم تُختبر لغياب Prisma runtime في الخادم.
        </p>
      </Card>
    </div>
  );
}

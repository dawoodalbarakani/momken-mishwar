import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Search } from "lucide-react";

type AuditLog = {
  id: string;
  actor: string;
  actor_role: string;
  action: string;
  entity: string;
  entity_id: string;
  at: string;
  ip?: string;
};

export default async function AuditPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const token = await getServerToken();
  const query = (searchParams.q || "").toLowerCase();

  let logs: AuditLog[] = [];
  try {
    logs = (await apiRequest<AuditLog[]>("/admin/audit?limit=100", {
      next: { revalidate: 60 },
      token,
    })) || [];
  } catch {
    logs = [];
  }

  const filtered = logs.filter(
    (l) =>
      l.actor.toLowerCase().includes(query) ||
      l.action.toLowerCase().includes(query) ||
      l.entity_id.toLowerCase().includes(query)
  );

  return (
    <div className="container-admin py-6">
      <Card className="p-4">
        <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 text-sm font-medium mb-1">
              <Search className="w-4 h-4" /> البحث في السجل
            </div>
            <Input
              defaultValue={searchParams.q || ""}
              placeholder="الموظف، العملية، الكيان، المعرف"
            />
          </div>
          <p className="text-xs text-gray-500 hidden md:block">
            استدعي API حقيقي: `GET /v1/admin/audit`. السجل غير قابل للتعديل.
          </p>
        </div>
        <div className="overflow-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>الوقت</TableHead>
                <TableHead>الموظف</TableHead>
                <TableHead>الدور</TableHead>
                <TableHead>العملية</TableHead>
                <TableHead>الكيان</TableHead>
                <TableHead>معرف الكيان</TableHead>
                <TableHead>عنوان IP</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.map((l) => (
                <TableRow key={l.id}>
                  <TableCell className="font-mono text-xs">
                    {new Date(l.at).toLocaleString("ar-SA")}
                  </TableCell>
                  <TableCell>{l.actor}</TableCell>
                  <TableCell className="font-mono text-xs text-gray-500">{l.actor_role}</TableCell>
                  <TableCell className="font-mono text-xs">{l.action}</TableCell>
                  <TableCell>{l.entity}</TableCell>
                  <TableCell className="font-mono text-xs">{l.entity_id}</TableCell>
                  <TableCell className="font-mono text-xs">{l.ip || "—"}</TableCell>
                </TableRow>
              ))}
              {filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-gray-500 py-4">
                    لا توجد سجلات تدقيق
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

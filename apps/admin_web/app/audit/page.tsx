import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { InputGroup, InputGroupInput, InputGroupAddon } from "@/components/ui/input-group";
import { Empty, EmptyHeader, EmptyTitle, EmptyDescription } from "@/components/ui/empty";
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
      <Card>
        <CardHeader>
          <div className="flex flex-col md:flex-row gap-3 items-end">
            <div className="flex-1">
              <InputGroup>
                <InputGroupAddon>
                  <Search className="size-4" />
                </InputGroupAddon>
                <InputGroupInput
                  defaultValue={searchParams.q || ""}
                  placeholder="الموظف، العملية، الكيان، المعرف"
                />
              </InputGroup>
            </div>
            <CardDescription className="text-xs hidden md:block">
              استدعي API حقيقي: `GET /v1/admin/audit`. السجل غير قابل للتعديل.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {filtered.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>لا توجد سجلات تدقيق</EmptyTitle>
                <EmptyDescription>لم يتم العثور على سجلات تدقيق.</EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
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
                      <TableCell className="font-mono text-xs text-muted-foreground">{l.actor_role}</TableCell>
                      <TableCell className="font-mono text-xs">{l.action}</TableCell>
                      <TableCell>{l.entity}</TableCell>
                      <TableCell className="font-mono text-xs">{l.entity_id}</TableCell>
                      <TableCell className="font-mono text-xs">{l.ip || "—"}</TableCell>
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

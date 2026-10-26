import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { InputGroup, InputGroupInput, InputGroupAddon } from "@/components/ui/input-group";
import { Empty, EmptyHeader, EmptyTitle, EmptyDescription } from "@/components/ui/empty";
import { Separator } from "@/components/ui/separator";
import { Search } from "lucide-react";

type Ticket = { id: string; customer_name: string; category: string; status: string; created_at: string };
type Note = { id: string; ticket_id: string; author: string; body: string; created_at: string };
type Audit = { id: string; actor: string; action: string; entity: string; entity_id: string; at: string };

export default async function SupportPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const token = await getServerToken();
  const query = (searchParams.q || "").toLowerCase();

  let tickets: Ticket[] = [];
  let notes: Note[] = [];
  let audit: Audit[] = [];
  try {
    const [t, n, a] = await Promise.all([
      apiRequest<Ticket[]>("/support/tickets?limit=50", { next: { revalidate: 60 }, token }).catch(() => [] as Ticket[]),
      apiRequest<Note[]>("/support/ticket-notes?limit=50", { next: { revalidate: 60 }, token }).catch(() => [] as Note[]),
      apiRequest<Audit[]>("/admin/audit?limit=50", { next: { revalidate: 60 }, token }).catch(() => [] as Audit[]),
    ]);
    tickets = t || [];
    notes = n || [];
    audit = a || [];
  } catch {
    tickets = [];
    notes = [];
    audit = [];
  }

  const filteredTickets = tickets.filter(
    (t) => t.id.toLowerCase().includes(query) || t.customer_name.toLowerCase().includes(query)
  );

  return (
    <div className="container-admin py-6">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2">
          <CardHeader>
            <div className="flex flex-col md:flex-row gap-3 items-end">
              <div className="flex-1">
                <InputGroup>
                  <InputGroupAddon>
                    <Search className="size-4" />
                  </InputGroupAddon>
                  <InputGroupInput defaultValue={searchParams.q || ""} placeholder="العميل، الفئة، ملاحظة" />
                </InputGroup>
              </div>
              <CardDescription className="text-xs hidden md:block">
                استدعي API حقيقي: `GET /v1/support/tickets`، `GET/POST /v1/support/ticket-notes`، `GET /v1/admin/audit`.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            {filteredTickets.length === 0 ? (
              <Empty>
                <EmptyHeader>
                  <EmptyTitle>لا توجد شكاوى</EmptyTitle>
                  <EmptyDescription>لم يتم العثور على شكاوى.</EmptyDescription>
                </EmptyHeader>
              </Empty>
            ) : (
              <div className="overflow-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>الشكوى</TableHead>
                      <TableHead>العميل</TableHead>
                      <TableHead>الفئة</TableHead>
                      <TableHead>الحالة</TableHead>
                      <TableHead>التاريخ</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filteredTickets.map((t) => (
                      <TableRow key={t.id}>
                        <TableCell className="font-mono text-xs">{t.id}</TableCell>
                        <TableCell>{t.customer_name}</TableCell>
                        <TableCell>{t.category}</TableCell>
                        <TableCell><Badge variant="outline">{t.status}</Badge></TableCell>
                        <TableCell className="font-mono text-xs">{new Date(t.created_at).toLocaleString("ar-SA")}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="flex flex-col gap-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">ملاحظات داخلية</CardTitle>
            </CardHeader>
            <CardContent>
              {notes.length === 0 ? (
                <p className="text-sm text-muted-foreground">لا توجد ملاحظات داخلية</p>
              ) : (
                <div className="flex flex-col gap-2 max-h-60 overflow-y-auto">
                  {notes.map((n) => (
                    <Card key={n.id} className="p-3">
                      <div className="flex justify-between text-xs mb-1">
                        <span className="font-medium">{n.author}</span>
                        <span className="text-muted-foreground">{new Date(n.created_at).toLocaleString("ar-SA")}</span>
                      </div>
                      <div className="text-sm">{n.body}</div>
                    </Card>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">سجل التغييرات الحساس</CardTitle>
            </CardHeader>
            <CardContent>
              {audit.length === 0 ? (
                <p className="text-sm text-muted-foreground">لا توجد سجلات تدقيق</p>
              ) : (
                <div className="flex flex-col gap-2 max-h-60 overflow-y-auto">
                  {audit.map((a) => (
                    <Card key={a.id} className="p-3">
                      <div className="flex justify-between text-xs mb-1">
                        <span className="font-medium">{a.actor}</span>
                        <span className="text-muted-foreground">{new Date(a.at).toLocaleString("ar-SA")}</span>
                      </div>
                      <div className="text-sm">{a.action} — {a.entity} ({a.entity_id})</div>
                    </Card>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="text-base">سجل العمليات المالية الحساسة</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            يُسجل كل عملية مالية حساسة (اعتماد صرف، تسوية) مع هوية الموظف والطابع الزمني. لا تُحذف السجلات المالية أو الرحلات المكتملة دون سياسة صريحة.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

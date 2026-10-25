import { getServerToken } from "@/lib/auth-server";
import { apiRequest } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
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
        <Card className="lg:col-span-2 p-4">
          <div className="flex flex-col md:flex-row gap-3 items-end mb-4">
            <div className="flex-1">
              <div className="flex items-center gap-2 text-sm font-medium mb-1">
                <Search className="w-4 h-4" /> البحث في الشكاوى والملاحظات الداخلية
              </div>
              <Input defaultValue={searchParams.q || ""} placeholder="العميل، الفئة، ملاحظة" />
            </div>
            <p className="text-xs text-gray-500 hidden md:block">
              استدعي API حقيقي: `GET /v1/support/tickets`، `GET/POST /v1/support/ticket-notes`، `GET /v1/admin/audit`.
            </p>
          </div>
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
                {filteredTickets.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center text-gray-500 py-4">
                      لا توجد شكاوى
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </Card>

        <div className="flex flex-col gap-4">
          <Card className="p-4">
            <h3 className="font-bold mb-2">ملاحظات داخلية</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto">
              {notes.map((n) => (
                <div key={n.id} className="p-3 border rounded text-sm">
                  <div className="flex justify-between text-xs mb-1">
                    <span>{n.author}</span>
                    <span className="text-gray-400">{new Date(n.created_at).toLocaleString("ar-SA")}</span>
                  </div>
                  <div>{n.body}</div>
                </div>
              ))}
              {notes.length === 0 && <div className="text-sm text-gray-500">لا توجد ملاحظات داخلية</div>}
            </div>
          </Card>
          <Card className="p-4">
            <h3 className="font-bold mb-2">سجل التغييرات الحساس</h3>
            <div className="space-y-2 max-h-60 overflow-y-auto">
              {audit.map((a) => (
                <div key={a.id} className="p-3 border rounded text-sm">
                  <div className="flex justify-between text-xs mb-1">
                    <span>{a.actor}</span>
                    <span className="text-gray-400">{new Date(a.at).toLocaleString("ar-SA")}</span>
                  </div>
                  <div>{a.action} — {a.entity} ({a.entity_id})</div>
                </div>
              ))}
              {audit.length === 0 && <div className="text-sm text-gray-500">لا توجد سجلات تدقيق</div>}
            </div>
          </Card>
        </div>
      </div>

      <Card className="mt-6 p-4">
        <h3 className="font-bold mb-2">سجل العمليات المالية الحساسة</h3>
        <p className="text-sm text-gray-600">
          يُسجل كل عملية مالية حساسة (اعتماد صرف، تسوية) مع هوية الموظف والطابع الزمني. لا تُحذف السجلات المالية أو الرحلات المكتملة دون سياسة صريحة.
        </p>
      </Card>
    </div>
  );
}

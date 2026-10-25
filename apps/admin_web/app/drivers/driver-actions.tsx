"use client";

import { useState } from "react";
import { getToken } from "@/lib/auth";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Check, X, Pause } from "lucide-react";

type DriverAction = "approve" | "reject" | "suspend";

interface DriverRowActionsProps {
  driver: { id: string; status: DriverActionStatus };
  token: string | null;
}

type DriverActionStatus = "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED";

const ACTION_LABELS: Record<DriverAction, { ar: string; variant: "default" | "destructive" | "secondary"; icon: React.ElementType }> = {
  approve: { ar: "اعتماد", variant: "default", icon: Check },
  reject: { ar: "رفض", variant: "destructive", icon: X },
  suspend: { ar: "إيقاف", variant: "secondary", icon: Pause },
};

export function DriverRowActions({ driver, token }: DriverRowActionsProps) {
  const [open, setOpen] = useState(false);
  const [action, setAction] = useState<DriverAction>("approve");
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const availableActions: DriverAction[] =
    driver.status === "PENDING"
      ? ["approve", "reject"]
      : driver.status === "APPROVED" || driver.status === "SUSPENDED"
      ? ["suspend"]
      : [];

  async function handleExecute() {
    setError(null);
    setSubmitting(true);
    try {
      const resolvedToken = token || getToken();
      await apiRequest(`/admin/drivers/${driver.id}/${action}`, {
        method: "POST",
        body: JSON.stringify({ reason, actor_id: "" }),
        token: resolvedToken,
      });
      setOpen(false);
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل تنفيذ الإجراء");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex gap-2">
      {availableActions.map((act) => {
        const { ar, variant, icon: Icon } = ACTION_LABELS[act];
        return (
          <Button
            key={act}
            size="sm"
            variant={variant}
            onClick={() => {
              setAction(act);
              setReason("");
              setOpen(true);
            }}
          >
            <Icon className="w-3 h-3 mr-1" /> {ar}
          </Button>
        );
      })}
      {open && (
        <Dialog
          open={open}
          onClose={() => setOpen(false)}
          title="تأكيد الإجراء"
        >
          <div className="space-y-3">
            <label className="block text-sm font-medium">السبب</label>
            <textarea
              className="w-full border rounded p-2 text-sm"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
            {error && (
              <p className="text-xs text-red-600">{error}</p>
            )}
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="outline" onClick={() => setOpen(false)}>
                إلغاء
              </Button>
              <Button onClick={handleExecute} loading={submitting} disabled={submitting}>
                تنفيذ
              </Button>
            </div>
          </div>
        </Dialog>
      )}
    </div>
  );
}

"use client";

import { useState } from "react";
import { getToken } from "@/lib/auth";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Dialog, DialogTitle, DialogContent, DialogFooter } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
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
            <Icon data-icon="inline-start" /> {ar}
          </Button>
        );
      })}
      {open && (
        <Dialog
          open={open}
          onOpenChange={(isOpen) => setOpen(isOpen)}
        >
          <DialogContent>
            <DialogTitle>تأكيد الإجراء</DialogTitle>
            <div className="flex flex-col gap-3">
              <Label htmlFor="reason">السبب</Label>
              <Textarea
                id="reason"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
              {error && (
                <p className="text-xs text-red-600">{error}</p>
              )}
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  إلغاء
                </Button>
                <Button onClick={handleExecute} loading={submitting} disabled={submitting}>
                  تنفيذ
                </Button>
              </DialogFooter>
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}

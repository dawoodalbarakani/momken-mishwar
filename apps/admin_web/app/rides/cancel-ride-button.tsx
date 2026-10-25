"use client";

import { getToken } from "@/lib/auth";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { AlertTriangle } from "lucide-react";

interface CancelRideButtonProps {
  rideId: string;
  token: string | null;
}

export function CancelRideButton({ rideId, token }: CancelRideButtonProps) {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCancel() {
    if (!window.confirm("تأكيد إلغاء الرحلة؟")) return;
    setError(null);
    setSubmitting(true);
    try {
      const resolvedToken = token || getToken();
      await apiRequest(`/admin/rides/${rideId}/cancel`, {
        method: "POST",
        token: resolvedToken,
      });
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل الإلغاء");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div>
      <Button
        size="sm"
        variant="destructive"
        onClick={handleCancel}
        loading={submitting}
        disabled={submitting}
      >
        <AlertTriangle className="w-3 h-3 mr-1" /> إلغاء
      </Button>
      {error && <p className="text-xs text-red-600 mt-1">{error}</p>}
    </div>
  );
}

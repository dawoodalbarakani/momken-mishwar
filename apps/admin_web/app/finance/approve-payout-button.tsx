"use client";

import { getToken } from "@/lib/auth";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useState } from "react";

interface ApprovePayoutButtonProps {
  driverId: string;
  token: string | null;
}

export function ApprovePayoutButton({ driverId, token }: ApprovePayoutButtonProps) {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleApprove() {
    setError(null);
    setSubmitting(true);
    try {
      const resolvedToken = token || getToken();
      await apiRequest(`/admin/payouts/${driverId}/approve`, {
        method: "POST",
        token: resolvedToken,
      });
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل اعتماد التسوية");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div>
      <Button
        size="sm"
        onClick={handleApprove}
        loading={submitting}
        disabled={submitting}
      >
        اعتماد صرف
      </Button>
      {error && <p className="text-xs text-red-600 mt-1">{error}</p>}
    </div>
  );
}

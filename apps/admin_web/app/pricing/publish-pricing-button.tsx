"use client";

import { getToken } from "@/lib/auth";
import { apiRequest, ApiResponseError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useState } from "react";

interface PublishPricingButtonProps {
  ruleId: string;
  token: string | null;
}

export function PublishPricingButton({ ruleId, token }: PublishPricingButtonProps) {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handlePublish() {
    setError(null);
    setSubmitting(true);
    try {
      const resolvedToken = token || getToken();
      await apiRequest(`/admin/pricing-rules/${ruleId}/publish`, {
        method: "POST",
        token: resolvedToken,
      });
    } catch (err) {
      setError(err instanceof ApiResponseError ? err.message_ar : "فشل النشر");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div>
      <Button
        size="sm"
        onClick={handlePublish}
        loading={submitting}
        disabled={submitting}
      >
        نشر
      </Button>
      {error && <p className="text-xs text-red-600 mt-1">{error}</p>}
    </div>
  );
}

"use client";

import { Button } from "@/components/ui/button";

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="container-admin py-12">
      <div className="text-center">
        <h2 className="text-xl font-bold text-red-800">حدث خطأ أثناء تحميل الصفحة</h2>
        <p className="text-gray-600 mt-2">{error.message}</p>
        <Button className="mt-4" onClick={() => reset()}>
          إعادة المحاولة
        </Button>
      </div>
    </div>
  );
}

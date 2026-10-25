"use client";

import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error;
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Admin dashboard error:", error);
  }, [error]);

  return (
    <div className="container-admin py-12">
      <div className="text-center">
        <h2 className="text-xl font-bold text-red-800">حدث خطأ أثناء تحميل الصفحة</h2>
        <p className="text-gray-600 mt-2">{error.message}</p>
        <button
          onClick={() => reset()}
          className="mt-4 inline-flex items-center gap-2 px-4 py-2 rounded-md bg-brand-600 text-white hover:bg-brand-700"
        >
          إعادة المحاولة
        </button>
      </div>
    </div>
  );
}

import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <div className="container-admin py-12 flex flex-col gap-4">
      <Skeleton className="h-8 w-48" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

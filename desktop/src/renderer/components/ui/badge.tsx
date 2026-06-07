import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export function Badge({ className, ...props }: HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border border-border bg-[var(--brewwery-card)] px-2 py-0.5 text-xs font-medium text-muted-foreground",
        className
      )}
      {...props}
    />
  );
}

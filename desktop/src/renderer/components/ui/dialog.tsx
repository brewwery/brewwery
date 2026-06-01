import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export function Dialog({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("rounded-lg border border-border bg-background p-4 shadow-panel", className)} {...props} />;
}

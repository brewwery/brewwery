import type { ButtonHTMLAttributes, HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export function Tabs({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("inline-flex rounded-md border border-border bg-[var(--brewwery-input)] p-1", className)} {...props} />;
}

export function Tab({ className, "aria-selected": selected, ...props }: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={cn(
        "rounded px-3 py-1.5 text-sm text-muted-foreground transition-colors",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--brewwery-focus-ring)] focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--brewwery-app-panel)]",
        selected && "bg-[var(--brewwery-card-hover)] text-foreground",
        className
      )}
      aria-selected={selected}
      {...props}
    />
  );
}

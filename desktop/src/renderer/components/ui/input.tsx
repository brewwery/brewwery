import type { InputHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-9 rounded-md border border-border bg-[var(--brewwery-input)] px-3 text-sm text-foreground outline-none placeholder:text-muted-foreground focus:border-[color:var(--brewwery-warning-border)] focus-visible:ring-2 focus-visible:ring-[color:var(--brewwery-focus-ring)] focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--brewwery-app-panel)]",
        className
      )}
      {...props}
    />
  );
}

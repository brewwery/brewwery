import type { ButtonHTMLAttributes, HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export function Tabs({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("inline-flex rounded-md border border-border bg-black/20 p-1", className)} {...props} />;
}

export function Tab({ className, "aria-selected": selected, ...props }: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={cn(
        "rounded px-3 py-1.5 text-sm text-muted-foreground transition-colors",
        selected && "bg-white/[0.08] text-foreground",
        className
      )}
      aria-selected={selected}
      {...props}
    />
  );
}

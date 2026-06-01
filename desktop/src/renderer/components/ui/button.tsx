import type { ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

type ButtonVariant = "primary" | "secondary" | "ghost";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

export function Button({ className, variant = "secondary", ...props }: ButtonProps) {
  return (
    <button
      className={cn(
        "inline-flex h-9 items-center justify-center gap-2 rounded-md px-3 text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-50",
        variant === "primary" && "bg-accent text-accent-foreground hover:bg-amber-400",
        variant === "secondary" && "border border-border bg-white/[0.04] text-foreground hover:bg-white/[0.07]",
        variant === "ghost" && "text-muted-foreground hover:bg-white/[0.06] hover:text-foreground",
        className
      )}
      {...props}
    />
  );
}

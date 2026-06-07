import { CheckCircle2, Info, X, XCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/cn";
import type { ToastTone } from "@/stores/toast-store";
import { useToastStore } from "@/stores/toast-store";

export function ToastViewport() {
  const toasts = useToastStore((state) => state.toasts);
  const dismissToast = useToastStore((state) => state.dismissToast);

  if (toasts.length === 0) return null;

  return (
    <div className="pointer-events-none fixed bottom-12 right-4 z-50 flex w-[360px] max-w-[calc(100vw-2rem)] flex-col gap-2">
      {toasts.map((toast) => {
        const Icon = iconForTone(toast.tone);
        return (
          <div
            key={toast.id}
            className={cn(
              "pointer-events-auto rounded-lg border bg-[var(--brewwery-card)] p-3 shadow-panel backdrop-blur",
              toast.tone === "success" && "border-emerald-500/25",
              toast.tone === "error" && "border-red-500/25",
              toast.tone === "info" && "border-border"
            )}
          >
            <div className="flex items-start gap-3">
              <Icon
                className={cn(
                  "mt-0.5 h-4 w-4 shrink-0",
                  toast.tone === "success" && "text-emerald-300",
                  toast.tone === "error" && "text-red-300",
                  toast.tone === "info" && "text-accent"
                )}
              />
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium text-foreground">{toast.title}</div>
                {toast.description ? <div className="mt-1 line-clamp-2 text-xs leading-5 text-muted-foreground">{toast.description}</div> : null}
              </div>
              <Button variant="ghost" className="h-6 w-6 shrink-0 px-0" onClick={() => dismissToast(toast.id)} aria-label="Dismiss">
                <X className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function iconForTone(tone: ToastTone) {
  if (tone === "success") return CheckCircle2;
  if (tone === "error") return XCircle;
  return Info;
}

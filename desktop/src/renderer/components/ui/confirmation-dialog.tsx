import type { ReactNode } from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";

interface ConfirmationDialogProps {
  open: boolean;
  title: string;
  description: ReactNode;
  confirmLabel: string;
  loading?: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}

export function ConfirmationDialog({
  open,
  title,
  description,
  confirmLabel,
  loading,
  onCancel,
  onConfirm
}: ConfirmationDialogProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-[var(--brewwery-overlay)] p-6">
      <Dialog className="w-full max-w-md">
        <div className="flex items-start gap-3">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-md border border-[color:var(--brewwery-warning-border)] bg-[var(--brewwery-warning-bg)]">
            <AlertTriangle className="h-4 w-4 text-accent" />
          </div>
          <div>
            <h2 className="text-base font-semibold text-foreground">{title}</h2>
            <div className="mt-2 text-sm leading-6 text-muted-foreground">{description}</div>
          </div>
        </div>
        <div className="mt-5 flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={loading}>
            Cancel
          </Button>
          <Button variant="primary" onClick={onConfirm} disabled={loading}>
            {loading ? "Working..." : confirmLabel}
          </Button>
        </div>
      </Dialog>
    </div>
  );
}

import type { ReactNode } from "react";
import { AlertTriangle, Beer, Loader2, PackageOpen } from "lucide-react";
import type { IpcError } from "@brewwery/shared-types";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/cn";
import { errorDetails, friendlyErrorMessage } from "@/lib/errors";

interface StatePanelProps {
  title: string;
  description?: ReactNode;
  action?: ReactNode;
  kind?: "loading" | "empty" | "error" | "homebrew";
}

export function StatePanel({ title, description, action, kind = "empty" }: StatePanelProps) {
  const Icon = kind === "loading" ? Loader2 : kind === "error" ? AlertTriangle : kind === "homebrew" ? Beer : PackageOpen;

  return (
    <Card>
      <CardContent className="flex min-h-64 flex-col items-center justify-center text-center">
        <Icon className={cn("mb-4 h-8 w-8 text-accent", kind === "loading" && "animate-spin")} />
        <h2 className="text-base font-semibold text-foreground">{title}</h2>
        {description ? <div className="mt-2 max-w-lg text-sm leading-6 text-muted-foreground">{description}</div> : null}
        {action ? <div className="mt-4">{action}</div> : null}
      </CardContent>
    </Card>
  );
}

export function ErrorDescription({ error }: { error: IpcError }) {
  const details = errorDetails(error);

  return (
    <>
      <div>{friendlyErrorMessage(error)}</div>
      <details className="mt-2">
        <summary className="cursor-pointer text-xs font-medium text-accent">Show details</summary>
        <div className="mt-2 font-mono text-xs text-[var(--brewwery-warning)]">{error.code}</div>
        {details ? <pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap rounded-md border border-border bg-[var(--brewwery-pre)] p-2 text-left text-xs text-muted-foreground">{details}</pre> : null}
      </details>
    </>
  );
}

import type { ReactNode } from "react";
import { AlertTriangle, Beer, Loader2, PackageOpen } from "lucide-react";
import type { IpcError } from "@brewwery/shared-types";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/cn";

interface StatePanelProps {
  title: string;
  description?: ReactNode;
  kind?: "loading" | "empty" | "error" | "homebrew";
}

export function StatePanel({ title, description, kind = "empty" }: StatePanelProps) {
  const Icon = kind === "loading" ? Loader2 : kind === "error" ? AlertTriangle : kind === "homebrew" ? Beer : PackageOpen;

  return (
    <Card>
      <CardContent className="flex min-h-64 flex-col items-center justify-center text-center">
        <Icon className={cn("mb-4 h-8 w-8 text-accent", kind === "loading" && "animate-spin")} />
        <h2 className="text-base font-semibold text-foreground">{title}</h2>
        {description ? <div className="mt-2 max-w-lg text-sm leading-6 text-muted-foreground">{description}</div> : null}
      </CardContent>
    </Card>
  );
}

export function ErrorDescription({ error }: { error: IpcError }) {
  return (
    <>
      <div>{error.message}</div>
      <div className="mt-2 font-mono text-xs text-amber-300">{error.code}</div>
    </>
  );
}

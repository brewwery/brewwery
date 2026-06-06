import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import type { OperationProgressState } from "@/hooks/use-progress-operation";
import { cn } from "@/lib/cn";
import { friendlyErrorMessage } from "@/lib/errors";
import { Button } from "./button";
import { Card, CardContent } from "./card";

interface OperationProgressPanelProps {
  progress?: OperationProgressState;
  onClear?: () => void;
}

export function OperationProgressPanel({ progress, onClear }: OperationProgressPanelProps) {
  if (!progress) return null;

  const output = progress.lines.length > 0 ? progress.lines : fallbackLines(progress);
  const summary = progressSummary(progress);

  return (
    <Card className="overflow-hidden">
      <CardContent className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2">
            {progress.status === "running" ? <Loader2 className="h-4 w-4 animate-spin text-accent" /> : null}
            {progress.status === "success" ? <CheckCircle2 className="h-4 w-4 text-emerald-400" /> : null}
            {progress.status === "failed" ? <XCircle className="h-4 w-4 text-red-400" /> : null}
            <div className="min-w-0">
              <div className="truncate text-sm font-medium">
                {progress.status === "running" ? "Running Homebrew operation" : progress.status === "success" ? "Operation completed" : "Operation failed"}
              </div>
              <div className="truncate font-mono text-xs text-muted-foreground">{progress.command}</div>
            </div>
          </div>
          {progress.status !== "running" ? (
            <Button variant="ghost" className="h-8" onClick={onClear}>
              Dismiss
            </Button>
          ) : null}
        </div>

        <div className="grid gap-2 rounded-md border border-border bg-background/45 p-3 text-xs md:grid-cols-[1fr_auto_auto] md:items-center">
          <div className="min-w-0">
            <div className="text-muted-foreground">Target</div>
            <div className="mt-1 truncate font-medium text-foreground">{progress.target ?? progress.command}</div>
          </div>
          <Meta label="Packages" value={summary.packageLabel} />
          <Meta label="Operation ID" value={shortOperationId(progress.operationId)} mono />
        </div>

        <div>
          <div className="mb-1 flex items-center justify-between text-xs text-muted-foreground">
            <span>{summary.statusLabel}</span>
            <span>{progress.status}</span>
          </div>
          <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
            <div
              className={cn(
                "h-full rounded-full transition-all",
                progress.status === "failed" ? "bg-red-400" : progress.status === "success" ? "bg-emerald-400" : "animate-pulse bg-accent"
              )}
              style={{ width: progress.status === "success" || progress.status === "failed" ? "100%" : `${summary.percent}%` }}
            />
          </div>
        </div>

        <div className="max-h-48 overflow-auto rounded-md border border-border bg-background/70 p-3 font-mono text-xs leading-5">
          {output.length > 0 ? (
            output.map((line, index) => (
              <pre
                key={`${line.timestamp}:${index}`}
                className={cn("whitespace-pre-wrap break-words", line.stream === "stderr" ? "text-amber-200" : "text-muted-foreground")}
              >
                {line.text}
              </pre>
            ))
          ) : (
            <div className="text-muted-foreground">Waiting for Homebrew output...</div>
          )}
        </div>

        {progress.error ? <div className="text-sm text-red-300">{friendlyErrorMessage(progress.error)}</div> : null}
      </CardContent>
    </Card>
  );
}

function Meta({ label, mono, value }: { label: string; mono?: boolean; value: string }) {
  return (
    <div className="min-w-[110px]">
      <div className="text-muted-foreground">{label}</div>
      <div className={cn("mt-1 truncate text-foreground", mono ? "font-mono" : "font-medium")}>{value}</div>
    </div>
  );
}

function progressSummary(progress: OperationProgressState) {
  const text = `${progress.stdout}\n${progress.stderr}`;
  const total = parseQueuedPackageCount(text, progress);
  const packageLabel = total === 1 ? "1 package queued" : `${total} packages queued`;

  if (progress.status === "success") {
    return { packageLabel, percent: 100, statusLabel: total === 1 ? "1 of 1 package completed" : `${total} packages completed` };
  }

  if (progress.status === "failed") {
    return { packageLabel, percent: 100, statusLabel: "Stopped with an error" };
  }

  const phaseCount = (text.match(/^==>/gm) ?? []).length;
  const percent = Math.min(85, Math.max(12, phaseCount * 12));
  const statusLabel = total === 1 ? "Processing 1 package" : `Processing ${total} packages`;
  return { packageLabel, percent, statusLabel };
}

function parseQueuedPackageCount(text: string, progress: OperationProgressState) {
  const upgradeMatch = text.match(/Upgrading\s+(\d+)\s+outdated package/i);
  if (upgradeMatch?.[1]) return Number(upgradeMatch[1]);
  return progress.kind === "upgrade" && progress.target ? 1 : 1;
}

function shortOperationId(operationId: string) {
  return operationId.split("-")[0] ?? operationId.slice(0, 8);
}

function fallbackLines(progress: OperationProgressState) {
  const lines = [];
  if (progress.stdout) lines.push({ stream: "stdout" as const, text: progress.stdout, timestamp: "stdout" });
  if (progress.stderr) lines.push({ stream: "stderr" as const, text: progress.stderr, timestamp: "stderr" });
  return lines;
}

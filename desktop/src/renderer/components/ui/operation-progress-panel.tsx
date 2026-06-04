import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import type { OperationProgressState } from "@/hooks/use-progress-operation";
import { cn } from "@/lib/cn";
import { Button } from "./button";
import { Card, CardContent } from "./card";

interface OperationProgressPanelProps {
  progress?: OperationProgressState;
  onClear?: () => void;
}

export function OperationProgressPanel({ progress, onClear }: OperationProgressPanelProps) {
  if (!progress) return null;

  const output = progress.lines.length > 0 ? progress.lines : fallbackLines(progress);

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

        {progress.error ? <div className="text-sm text-red-300">{progress.error.message}</div> : null}
      </CardContent>
    </Card>
  );
}

function fallbackLines(progress: OperationProgressState) {
  const lines = [];
  if (progress.stdout) lines.push({ stream: "stdout" as const, text: progress.stdout, timestamp: "stdout" });
  if (progress.stderr) lines.push({ stream: "stderr" as const, text: progress.stderr, timestamp: "stderr" });
  return lines;
}

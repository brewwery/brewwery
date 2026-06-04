import { Clipboard, Download, History, Search, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { StatePanel } from "@/components/ui/state-panel";
import { Tab, Tabs } from "@/components/ui/tabs";
import { cn } from "@/lib/cn";
import type { OperationKind, OperationLogEntry } from "@/stores/history-store";
import { useHistoryStore } from "@/stores/history-store";

type HistoryFilter = "all" | OperationKind;

const filters: Array<{ value: HistoryFilter; label: string }> = [
  { value: "all", label: "All" },
  { value: "upgrade", label: "Upgrades" },
  { value: "service", label: "Services" },
  { value: "cleanup", label: "Cleanup" },
  { value: "doctor", label: "Doctor" },
  { value: "brewfile_export", label: "Brewfile" }
];

export function HistoryPage() {
  const entries = useHistoryStore((state) => state.entries);
  const clearEntries = useHistoryStore((state) => state.clearEntries);
  const [filter, setFilter] = useState<HistoryFilter>("all");
  const [query, setQuery] = useState("");

  const visibleEntries = useMemo(
    () =>
      entries.filter((entry) => {
        if (filter !== "all" && entry.kind !== filter) return false;
        const normalizedQuery = query.trim().toLowerCase();
        if (!normalizedQuery) return true;

        return [
          entry.title,
          entry.command,
          entry.target,
          entry.details,
          entry.stdout,
          entry.stderr,
          entry.error?.code,
          entry.error?.message,
          entry.error?.raw
        ].some((value) => value?.toLowerCase().includes(normalizedQuery));
      }),
    [entries, filter, query]
  );

  const successCount = entries.filter((entry) => entry.status === "success").length;
  const failedCount = entries.length - successCount;

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">History</h1>
          <p className="mt-1 text-sm text-muted-foreground">Local operation log with command summaries, output details, and timestamps.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" disabled={entries.length === 0} onClick={() => exportHistory(entries)}>
            <Download className="h-4 w-4" />
            Export JSON
          </Button>
          <Button variant="secondary" disabled={entries.length === 0} onClick={clearEntries}>
            <Trash2 className="h-4 w-4" />
            Clear
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <SummaryCard label="Operations" value={entries.length} />
        <SummaryCard label="Succeeded" value={successCount} />
        <SummaryCard label="Failed" value={failedCount} />
      </div>

      <div className="flex items-center justify-between gap-3">
        <div className="relative max-w-sm flex-1">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input className="pl-9" placeholder="Search history..." value={query} onChange={(event) => setQuery(event.target.value)} />
        </div>
        <Tabs>
          {filters.map((item) => (
            <Tab key={item.value} aria-selected={filter === item.value} onClick={() => setFilter(item.value)}>
              {item.label}
            </Tab>
          ))}
        </Tabs>
      </div>

      {entries.length === 0 ? <StatePanel title="No operations yet" /> : null}
      {entries.length > 0 && visibleEntries.length === 0 ? <StatePanel title="No operations match this filter" /> : null}

      {visibleEntries.length > 0 ? (
        <div className="space-y-3">
          {visibleEntries.map((entry) => (
            <OperationCard key={entry.id} entry={entry} />
          ))}
        </div>
      ) : null}
    </section>
  );
}

function SummaryCard({ label, value }: { label: string; value: number }) {
  return (
    <Card>
      <CardContent>
        <div className="text-sm text-muted-foreground">{label}</div>
        <div className="mt-1 text-2xl font-semibold">{value}</div>
      </CardContent>
    </Card>
  );
}

function OperationCard({ entry }: { entry: OperationLogEntry }) {
  const output = [entry.details, entry.stdout, entry.stderr, entry.error?.raw].filter(Boolean).join("\n\n");

  return (
    <Card>
      <CardContent>
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <History className="h-4 w-4 text-accent" />
              <h2 className="truncate text-sm font-semibold">{entry.title}</h2>
            </div>
            <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
              <Badge>{formatKind(entry.kind)}</Badge>
              <StatusBadge status={entry.status} />
              <span>{formatTimestamp(entry.timestamp)}</span>
              {entry.target ? <span className="truncate">Target: {entry.target}</span> : null}
            </div>
            {entry.command ? <div className="mt-3 font-mono text-xs text-muted-foreground">{entry.command}</div> : null}
            {entry.error ? (
              <div className="mt-3 rounded-md border border-red-500/20 bg-red-500/10 p-3 text-sm text-red-200">
                <div>{entry.error.message}</div>
                <div className="mt-1 font-mono text-xs">{entry.error.code}</div>
              </div>
            ) : null}
          </div>
          <Button
            variant="ghost"
            className="h-8 shrink-0"
            disabled={!output}
            onClick={() => output && void navigator.clipboard.writeText(output)}
          >
            <Clipboard className="h-4 w-4" />
            Copy
          </Button>
        </div>

        {output ? (
          <details className="mt-4">
            <summary className="cursor-pointer text-xs font-medium text-accent">Show output details</summary>
            <pre className="mt-2 max-h-80 overflow-auto rounded-md border border-border bg-black/20 p-3 text-xs leading-5 text-muted-foreground">
              {output}
            </pre>
          </details>
        ) : null}
      </CardContent>
    </Card>
  );
}

function StatusBadge({ status }: { status: OperationLogEntry["status"] }) {
  return (
    <Badge
      className={cn(
        status === "success" && "border-emerald-500/25 bg-emerald-500/10 text-emerald-300",
        status === "failed" && "border-red-500/25 bg-red-500/10 text-red-300"
      )}
    >
      {status}
    </Badge>
  );
}

function formatKind(kind: OperationKind) {
  return kind.replace("_", " ");
}

function formatTimestamp(timestamp: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "medium"
  }).format(new Date(timestamp));
}

function exportHistory(entries: OperationLogEntry[]) {
  const blob = new Blob([JSON.stringify({ exportedAt: new Date().toISOString(), entries }, null, 2)], {
    type: "application/json"
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `brewwery-history-${new Date().toISOString().slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

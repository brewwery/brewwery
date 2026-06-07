import { RefreshCw, Trash2 } from "lucide-react";
import { useState } from "react";
import type { CleanupItem, IpcError } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { useCleanup } from "@/hooks/use-cleanup";

export function CleanupPage() {
  const { preview, result, loading, running, error, previewCleanup, runCleanup } = useCleanup();
  const [confirmOpen, setConfirmOpen] = useState(false);

  const canRunCleanup = Boolean(preview && preview.items.length > 0);

  const confirmCleanup = async () => {
    await runCleanup();
    setConfirmOpen(false);
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Cleanup</h1>
          <p className="mt-1 text-sm text-muted-foreground">Preview removable Homebrew caches and old versions before running cleanup.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" disabled={loading || running} onClick={() => void previewCleanup()}>
            <RefreshCw className="h-4 w-4" />
            Preview cleanup
          </Button>
          <Button variant="primary" disabled={!canRunCleanup || loading || running} onClick={() => setConfirmOpen(true)}>
            <Trash2 className="h-4 w-4" />
            Run cleanup
          </Button>
        </div>
      </div>

      <Card>
        <CardContent className="text-sm leading-6 text-muted-foreground">
          Brewwery always runs <span className="font-mono text-foreground">brew cleanup -n</span> first. The actual cleanup command is
          only available after a preview and requires confirmation.
        </CardContent>
      </Card>

      {loading ? <StatePanel kind="loading" title="Loading cleanup preview..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel
          kind="error"
          title={error.code === "CLEANUP_RUN_FAILED" ? "Cleanup failed" : "Failed to preview cleanup"}
          description={<ErrorDescription error={error} />}
        />
      ) : null}

      {!loading && !error && result ? (
        <StatePanel
          title="Cleanup completed"
          description={
            <>
              <div>{result.removedItems ?? 0} removal operations reported.</div>
              {result.freedSpace ? <div className="mt-1">Freed space: {result.freedSpace}</div> : null}
              {result.stdout || result.stderr ? <RawOutput stdout={result.stdout} stderr={result.stderr} /> : null}
            </>
          }
        />
      ) : null}

      {!loading && !error && preview && preview.items.length === 0 ? (
        <StatePanel title="Nothing to clean" description={preview.rawOutput ? <RawOutput stdout={preview.rawOutput} /> : undefined} />
      ) : null}

      {!loading && !error && !preview && !result ? <StatePanel title="No cleanup preview yet" /> : null}

      {!loading && !error && preview && preview.items.length > 0 ? (
        <Card className="overflow-hidden">
          <CardHeader>
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold">Preview Results</h2>
              <div className="text-sm text-muted-foreground">
                {preview.items.length} items{preview.totalSize ? ` · ${preview.totalSize}` : ""}
              </div>
            </div>
          </CardHeader>
          <Table>
            <thead>
              <tr>
                <Th>Item</Th>
                <Th className="w-32">Kind</Th>
                <Th className="w-32">Size</Th>
                <Th>Path</Th>
              </tr>
            </thead>
            <tbody>
              {preview.items.map((item, index) => (
                <tr key={`${item.path ?? item.name}:${index}`} className="hover:bg-[var(--brewwery-card-hover)]">
                  <Td className="font-medium">{item.name ?? "Unknown item"}</Td>
                  <Td>
                    <Badge>{formatKind(item.kind)}</Badge>
                  </Td>
                  <Td className="text-muted-foreground">{item.size ?? "Unknown"}</Td>
                  <Td className="max-w-lg truncate text-muted-foreground">{item.path ?? "Unknown path"}</Td>
                </tr>
              ))}
            </tbody>
          </Table>
          {preview.rawOutput ? (
            <div className="border-t border-border p-4">
              <RawOutput stdout={preview.rawOutput} />
            </div>
          ) : null}
        </Card>
      ) : null}

      <ConfirmationDialog
        open={confirmOpen}
        title="Run Homebrew cleanup?"
        description={
          <>
            Brewwery will run <span className="font-mono text-foreground">brew cleanup</span>. This can remove old versions, caches,
            logs, and broken links listed in the preview.
          </>
        }
        confirmLabel="Run cleanup"
        loading={running}
        onCancel={() => setConfirmOpen(false)}
        onConfirm={() => void confirmCleanup()}
      />
    </section>
  );
}

function formatKind(kind: CleanupItem["kind"]) {
  return kind?.replace("_", " ") ?? "unknown";
}

function RawOutput({ stdout, stderr }: { stdout?: string; stderr?: string }) {
  return (
    <details className="mt-3 text-left">
      <summary className="cursor-pointer text-xs font-medium text-accent">Show details</summary>
      <pre className="mt-2 max-h-64 overflow-auto rounded-md border border-border bg-[var(--brewwery-pre)] p-3 text-xs leading-5 text-muted-foreground">
        {[stdout, stderr].filter(Boolean).join("\n")}
      </pre>
    </details>
  );
}

function HomebrewNotFound() {
  return (
    <StatePanel
      kind="homebrew"
      title="Homebrew not found"
      description={
        <>
          <div>Brewwery could not find Homebrew at:</div>
          <div className="mt-2 font-mono text-xs text-foreground">/opt/homebrew/bin/brew</div>
          <div className="font-mono text-xs text-foreground">/usr/local/bin/brew</div>
          <div className="mt-2">Install Homebrew or set a custom path in Settings.</div>
        </>
      }
    />
  );
}

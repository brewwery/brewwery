import { GitFork, Plus, RefreshCw, Trash2 } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { BrewTap, IpcError, TapActionRequest } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { Input } from "@/components/ui/input";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { api } from "@/lib/api";
import { useHistoryStore } from "@/stores/history-store";

export function TapsPage() {
  const [taps, setTaps] = useState<BrewTap[]>([]);
  const [newTap, setNewTap] = useState("");
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<IpcError>();
  const [pending, setPending] = useState<{ action: "tap" | "untap"; name: string }>();

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(undefined);
    const response = await api.taps.list();
    if (response.ok) setTaps(response.data ?? []);
    else setError(response.error);
    setLoading(false);
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const sortedTaps = useMemo(() => [...taps].sort((a, b) => a.name.localeCompare(b.name)), [taps]);
  const submitTap = () => {
    const name = newTap.trim();
    if (name) setPending({ action: "tap", name });
  };

  const confirmAction = async () => {
    if (!pending) return;
    setActionLoading(true);
    setError(undefined);
    const request: TapActionRequest = { name: pending.name };
    const response = pending.action === "tap" ? await api.taps.add(request) : await api.taps.remove(request);

    if (response.ok) {
      useHistoryStore.getState().addEntry({
        kind: "tap",
        status: "success",
        title: pending.action === "tap" ? `Added tap ${pending.name}` : `Removed tap ${pending.name}`,
        command: `brew ${pending.action} ${pending.name}`,
        target: pending.name,
        stdout: response.data?.stdout,
        stderr: response.data?.stderr
      });
      if (pending.action === "tap") setNewTap("");
      setPending(undefined);
      await refresh();
    } else {
      setError(response.error);
      useHistoryStore.getState().addEntry({
        kind: "tap",
        status: "failed",
        title: pending.action === "tap" ? `Failed to add tap ${pending.name}` : `Failed to remove tap ${pending.name}`,
        command: `brew ${pending.action} ${pending.name}`,
        target: pending.name,
        error: response.error,
        stderr: response.error?.raw
      });
    }
    setActionLoading(false);
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Taps</h1>
          <p className="mt-1 text-sm text-muted-foreground">Manage additional Homebrew formula and cask repositories.</p>
        </div>
        <Button variant="secondary" onClick={() => void refresh()} disabled={loading}>
          <RefreshCw className="h-4 w-4" /> Refresh list
        </Button>
      </div>

      <Card className="p-4">
        <div className="text-sm font-medium">Add a tap</div>
        <div className="mt-1 text-xs text-muted-foreground">Use the owner/repository format, for example user/homebrew-tools.</div>
        <div className="mt-3 flex max-w-xl gap-2">
          <Input
            className="flex-1"
            aria-label="Tap name"
            placeholder="owner/repository"
            value={newTap}
            onChange={(event) => setNewTap(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") submitTap();
            }}
          />
          <Button variant="primary" disabled={!newTap.trim() || actionLoading} onClick={submitTap}>
            <Plus className="h-4 w-4" /> Add tap
          </Button>
        </div>
      </Card>

      {loading ? <StatePanel kind="loading" title="Loading taps..." /> : null}
      {!loading && error ? (
        <StatePanel kind="error" title="Homebrew tap operation failed" description={<ErrorDescription error={error} />} action={<Button onClick={() => void refresh()}>Retry</Button>} />
      ) : null}
      {!loading && !error && sortedTaps.length === 0 ? <StatePanel title="No additional taps installed" description="Homebrew can still use its built-in repositories." /> : null}

      {!loading && sortedTaps.length > 0 ? (
        <Card className="divide-y divide-border overflow-hidden">
          {sortedTaps.map((tap) => (
            <div key={tap.name} className="flex min-h-16 items-center justify-between gap-4 px-4 py-3">
              <div className="min-w-0">
                <div className="flex items-center gap-2 font-medium"><GitFork className="h-4 w-4 text-accent" />{tap.name}</div>
                <div className="mt-1 text-xs text-muted-foreground">Installed Homebrew tap</div>
              </div>
              <div className="flex items-center gap-2">
                {tap.official ? <Badge>Official</Badge> : <Badge>Third-party</Badge>}
                <Button variant="ghost" className="h-8 w-8 px-0" aria-label={`Remove ${tap.name}`} onClick={() => setPending({ action: "untap", name: tap.name })}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ))}
        </Card>
      ) : null}

      <ConfirmationDialog
        open={Boolean(pending)}
        title={pending?.action === "tap" ? `Add ${pending.name}?` : `Remove ${pending?.name}?`}
        description={<>Brewwery will run <span className="font-mono text-foreground">brew {pending?.action} {pending?.name}</span>. Removing a tap can make its installed formulae unavailable for future upgrades.</>}
        confirmLabel={pending?.action === "tap" ? "Add tap" : "Remove tap"}
        loading={actionLoading}
        onCancel={() => setPending(undefined)}
        onConfirm={() => void confirmAction()}
      />
    </section>
  );
}

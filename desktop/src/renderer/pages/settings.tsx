import { Clipboard, ExternalLink, RotateCcw, Save, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import type { BrewPathValidationResult, IpcError } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useSystem } from "@/hooks/use-system";
import { usePackages } from "@/hooks/use-packages";
import { useServices } from "@/hooks/use-services";
import { useUpdates } from "@/hooks/use-updates";
import { api } from "@/lib/api";
import {
  APP_CHANNEL,
  APP_VERSION,
  GITHUB_URL,
  ISSUE_URL,
  RELEASE_NOTES_URL,
  WEBSITE_URL
} from "@/lib/constants";
import { useHistoryStore } from "@/stores/history-store";
import { useSettingsStore } from "@/stores/settings-store";

export function SettingsPage() {
  const { detection, error, loading, refresh, system } = useSystem();
  const { packages: formulae } = usePackages("formula");
  const { packages: casks } = usePackages("cask");
  const { services } = useServices();
  const { updates } = useUpdates();
  const entries = useHistoryStore((state) => state.entries);
  const clearEntries = useHistoryStore((state) => state.clearEntries);
  const customHomebrewPath = useSettingsStore((state) => state.customHomebrewPath);
  const resetCustomHomebrewPath = useSettingsStore((state) => state.resetCustomHomebrewPath);
  const setCustomHomebrewPath = useSettingsStore((state) => state.setCustomHomebrewPath);
  const setTheme = useSettingsStore((state) => state.setTheme);
  const theme = useSettingsStore((state) => state.theme);
  const [pathLoading, setPathLoading] = useState(false);
  const [pathValidation, setPathValidation] = useState<BrewPathValidationResult | undefined>();
  const [pathError, setPathError] = useState<IpcError | undefined>();

  useEffect(() => {
    void api.settings.getHomebrewPath().then((response) => {
      if (response.ok) {
        setCustomHomebrewPath(response.data ?? "");
      }
    });
  }, [setCustomHomebrewPath]);

  const validatePath = async () => {
    if (!customHomebrewPath.trim()) return;
    setPathLoading(true);
    setPathError(undefined);
    try {
      const response = await api.settings.validateHomebrewPath(customHomebrewPath);
      if (response.ok) {
        setPathValidation(response.data);
        setPathError(response.data?.error);
      } else {
        setPathError(response.error);
      }
    } finally {
      setPathLoading(false);
    }
  };

  const savePath = async () => {
    if (!customHomebrewPath.trim()) return;
    setPathLoading(true);
    setPathError(undefined);
    try {
      const response = await api.settings.setHomebrewPath(customHomebrewPath);
      if (response.ok && response.data?.valid) {
        setPathValidation(response.data);
        setCustomHomebrewPath(response.data.path);
        await refresh();
      } else {
        setPathValidation(response.data);
        setPathError(response.data?.error ?? response.error);
      }
    } finally {
      setPathLoading(false);
    }
  };

  const resetPath = async () => {
    setPathLoading(true);
    setPathError(undefined);
    try {
      const response = await api.settings.clearHomebrewPath();
      if (response.ok) {
        resetCustomHomebrewPath();
        setPathValidation(undefined);
        await refresh();
      } else {
        setPathError(response.error);
      }
    } finally {
      setPathLoading(false);
    }
  };

  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Settings</h1>
        <p className="mt-1 text-sm text-muted-foreground">Local preferences and app information.</p>
      </div>

      <Card>
        <CardHeader>
          <div className="font-medium">Homebrew</div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 md:grid-cols-2">
            <InfoBox label="Status" value={loading ? "Checking..." : detection?.found ? "Detected" : "Not found"} />
            <InfoBox label="Executable path" value={system?.path ?? detection?.path ?? "Auto-detect"} />
            <InfoBox label="Version" value={system?.version ?? "Unknown"} />
            <InfoBox label="Prefix" value={system?.prefix ?? "Unknown"} />
            <InfoBox label="Architecture" value={system?.architecture ?? "Unknown"} />
            <InfoBox label="Checked paths" value={(detection?.checkedPaths ?? ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]).join(", ")} />
          </div>

          {error ? <div className="rounded-md border border-[color:var(--brewwery-danger-border)] bg-[var(--brewwery-danger-bg)] p-3 text-sm text-[var(--brewwery-danger)]">{error.message}</div> : null}

          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <div className="text-sm font-medium">Custom Homebrew path</div>
              {customHomebrewPath ? <Badge className="border-[color:var(--brewwery-warning-border)] bg-[var(--brewwery-warning-bg)] text-accent">Custom</Badge> : <Badge>Auto-detect</Badge>}
            </div>
            <div className="flex gap-2">
              <Input
                value={customHomebrewPath}
                placeholder="/opt/homebrew/bin/brew"
                onChange={(event) => setCustomHomebrewPath(event.target.value)}
              />
              <Button variant="secondary" onClick={() => void validatePath()} disabled={pathLoading || !customHomebrewPath.trim()}>
                Validate
              </Button>
              <Button variant="primary" onClick={() => void savePath()} disabled={pathLoading || !customHomebrewPath.trim()}>
                <Save className="h-4 w-4" />
                Save
              </Button>
              <Button variant="ghost" onClick={() => void resetPath()} disabled={pathLoading && !customHomebrewPath}>
                <RotateCcw className="h-4 w-4" />
                Reset
              </Button>
            </div>
            {pathValidation?.valid ? (
              <p className="text-xs text-[var(--brewwery-success)]">Validated {pathValidation.version ?? "Homebrew"} at {pathValidation.path}.</p>
            ) : null}
            {pathError ? <p className="text-xs text-[var(--brewwery-danger)]">{pathError.message}</p> : null}
            <p className="text-xs text-muted-foreground">Saved paths are validated by Rust and used by both normal Homebrew commands and streaming progress operations.</p>
          </div>

          <Button variant="secondary" onClick={() => void refresh()}>
            Check manually
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="font-medium">Appearance</div>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap gap-2">
            {(["system", "dark", "light"] as const).map((option) => (
              <Button key={option} variant={theme === option ? "primary" : "secondary"} onClick={() => setTheme(option)}>
                {option}
              </Button>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">System follows macOS appearance. Light uses a warm macOS utility palette.</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="font-medium">History</div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="secondary" onClick={() => exportHistory(entries)} disabled={entries.length === 0}>
              Export history JSON
            </Button>
            <Button variant="ghost" onClick={clearEntries} disabled={entries.length === 0}>
              <Trash2 className="h-4 w-4" />
              Clear history
            </Button>
          </div>
          <p className="mt-2 text-xs text-muted-foreground">{entries.length} local operation entries stored on this Mac.</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="font-medium">About Brewwery</div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <div className="text-lg font-semibold">Brewwery</div>
            <div className="text-sm text-muted-foreground">Homebrew, without the terminal.</div>
          </div>
          <div className="grid gap-3 md:grid-cols-2">
            <InfoBox label="Version" value={APP_VERSION} />
            <InfoBox label="Channel" value={APP_CHANNEL} />
            <InfoBox label="License" value="MIT" />
            <InfoBox label="Made by" value="Made Büro" />
            <InfoBox label="Platform" value="macOS first, Apple Silicon primary" />
            <InfoBox label="Architecture" value={system?.architecture ?? "unknown"} />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="primary"
              onClick={() =>
                void navigator.clipboard.writeText(
                  diagnosticsText({
                    appVersion: APP_VERSION,
                    channel: APP_CHANNEL,
                    brewVersion: system?.version ?? "unknown",
                    brewPath: system?.path ?? "unknown",
                    brewPrefix: system?.prefix ?? "unknown",
                    architecture: system?.architecture ?? "unknown",
                    formulae: formulae.length,
                    casks: casks.length,
                    services: services.length,
                    updates: updates.length
                  })
                )
              }
            >
              <Clipboard className="h-4 w-4" />
              Copy diagnostics
            </Button>
            <ExternalButton href={GITHUB_URL} label="GitHub" />
            <ExternalButton href={WEBSITE_URL} label="Website" />
            <ExternalButton href={ISSUE_URL} label="Report issue" />
            <ExternalButton href={RELEASE_NOTES_URL} label="Release notes" />
          </div>
        </CardContent>
      </Card>
    </section>
  );
}

function diagnosticsText(values: Record<string, string | number>) {
  return Object.entries(values)
    .map(([key, value]) => `${key}: ${value}`)
    .join("\n");
}

function InfoBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-border bg-background/50 p-3">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 truncate text-sm text-foreground">{value}</div>
    </div>
  );
}

function ExternalButton({ href, label }: { href: string; label: string }) {
  return (
    <Button variant="secondary" onClick={() => window.open(href, "_blank", "noopener,noreferrer")}>
      <ExternalLink className="h-4 w-4" />
      {label}
    </Button>
  );
}

function exportHistory(entries: unknown[]) {
  const payload = JSON.stringify({ exportedAt: new Date().toISOString(), entries }, null, 2);
  const blob = new Blob([payload], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `brewwery-history-${new Date().toISOString().slice(0, 10)}.json`;
  link.click();
  URL.revokeObjectURL(url);
}

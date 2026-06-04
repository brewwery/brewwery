import { ExternalLink, RotateCcw, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useSystem } from "@/hooks/use-system";
import {
  APP_VERSION,
  GITHUB_URL,
  ISSUE_URL,
  WEBSITE_URL
} from "@/lib/constants";
import { useHistoryStore } from "@/stores/history-store";
import { useSettingsStore } from "@/stores/settings-store";

export function SettingsPage() {
  const { detection, error, loading, refresh, system } = useSystem();
  const entries = useHistoryStore((state) => state.entries);
  const clearEntries = useHistoryStore((state) => state.clearEntries);
  const customHomebrewPath = useSettingsStore((state) => state.customHomebrewPath);
  const resetCustomHomebrewPath = useSettingsStore((state) => state.resetCustomHomebrewPath);
  const setCustomHomebrewPath = useSettingsStore((state) => state.setCustomHomebrewPath);
  const setTheme = useSettingsStore((state) => state.setTheme);
  const theme = useSettingsStore((state) => state.theme);

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

          {error ? <div className="rounded-md border border-red-500/20 bg-red-500/10 p-3 text-sm text-red-200">{error.message}</div> : null}

          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <div className="text-sm font-medium">Custom Homebrew path</div>
              <Badge>Coming later</Badge>
            </div>
            <div className="flex gap-2">
              <Input
                value={customHomebrewPath}
                placeholder="/opt/homebrew/bin/brew"
                onChange={(event) => setCustomHomebrewPath(event.target.value)}
                disabled
              />
              <Button variant="secondary" disabled>
                Validate
              </Button>
              <Button variant="ghost" onClick={resetCustomHomebrewPath} disabled={!customHomebrewPath}>
                <RotateCcw className="h-4 w-4" />
                Reset
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              v0.5 displays the detected path. Custom path execution will be enabled after shared Rust/main-process validation is wired
              across every Homebrew operation.
            </p>
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
              <Button key={option} variant={theme === option ? "primary" : "secondary"} onClick={() => setTheme(option)} disabled={option !== "dark"}>
                {option}
              </Button>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">Dark theme is active for the public alpha. System and light themes are placeholders.</p>
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
            <InfoBox label="License" value="MIT" />
            <InfoBox label="Made by" value="Made Büro" />
            <InfoBox label="Platform" value="macOS first, Apple Silicon primary" />
          </div>
          <div className="flex flex-wrap gap-2">
            <ExternalButton href={GITHUB_URL} label="GitHub" />
            <ExternalButton href={WEBSITE_URL} label="Website" />
            <ExternalButton href={ISSUE_URL} label="Report issue" />
          </div>
        </CardContent>
      </Card>
    </section>
  );
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

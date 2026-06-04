import { Clipboard, FileDown, FileText } from "lucide-react";
import { useMemo, useState } from "react";
import type { BrewfileEntry, BrewfileEntryKind } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { useBrewfile } from "@/hooks/use-brewfile";

const groups: Array<{ kind: BrewfileEntryKind; label: string }> = [
  { kind: "tap", label: "Taps" },
  { kind: "brew", label: "Formulae" },
  { kind: "cask", label: "Casks" },
  { kind: "mas", label: "Mac App Store" },
  { kind: "service", label: "Services" },
  { kind: "unknown", label: "Unknown" }
];

export function BrewfilePage() {
  const { result, loading, error, exportBrewfile, readBrewfile } = useBrewfile();
  const [path, setPath] = useState("");
  const [copied, setCopied] = useState(false);

  const groupedEntries = useMemo(() => groupEntries(result?.entries ?? []), [result]);

  const copyBrewfile = () => {
    if (!result?.rawContent) return;
    void navigator.clipboard.writeText(result.rawContent);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Brewfile</h1>
          <p className="mt-1 text-sm text-muted-foreground">Export or inspect a local Brewfile without running install actions.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" disabled={!result?.rawContent} onClick={copyBrewfile}>
            <Clipboard className="h-4 w-4" />
            {copied ? "Brewfile copied" : "Copy Brewfile"}
          </Button>
          <Button variant="primary" disabled={loading} onClick={() => void exportBrewfile()}>
            <FileDown className="h-4 w-4" />
            Export current setup
          </Button>
        </div>
      </div>

      <Card>
        <CardContent className="flex items-center gap-2">
          <Input
            placeholder="/absolute/path/to/Brewfile"
            value={path}
            onChange={(event) => setPath(event.target.value)}
            disabled={loading}
          />
          <Button variant="secondary" disabled={loading || path.trim().length === 0} onClick={() => void readBrewfile(path.trim())}>
            <FileText className="h-4 w-4" />
            Read Brewfile
          </Button>
        </CardContent>
      </Card>

      {loading ? <StatePanel kind="loading" title="Exporting Brewfile..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel
          kind="error"
          title={error.code === "BREWFILE_READ_FAILED" || error.code === "INVALID_FILE_PATH" ? "Failed to read Brewfile" : "Failed to export Brewfile"}
          description={<ErrorDescription error={error} />}
        />
      ) : null}
      {!loading && !error && !result ? <StatePanel title="No Brewfile generated yet" /> : null}

      {!loading && !error && result ? (
        <div className="grid grid-cols-[360px_1fr] gap-4">
          <div className="space-y-4">
            <Card>
              <CardContent>
                <div className="text-sm text-muted-foreground">Entries</div>
                <div className="mt-1 text-2xl font-semibold">{result.entries.length}</div>
                {"path" in result && result.path ? <div className="mt-2 truncate text-xs text-muted-foreground">{result.path}</div> : null}
              </CardContent>
            </Card>

            {groups.map(({ kind, label }) => (
              <EntryGroup key={kind} label={label} entries={groupedEntries[kind] ?? []} />
            ))}
          </div>

          <Card className="min-w-0">
            <CardHeader>
              <div className="flex items-center justify-between">
                <h2 className="text-sm font-semibold">Generated Brewfile</h2>
                <Badge>{result.rawContent.split("\n").filter(Boolean).length} lines</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <pre className="max-h-[640px] overflow-auto rounded-md border border-border bg-black/20 p-3 text-xs leading-5 text-muted-foreground">
                {result.rawContent}
              </pre>
            </CardContent>
          </Card>
        </div>
      ) : null}
    </section>
  );
}

function groupEntries(entries: BrewfileEntry[]) {
  return entries.reduce<Record<BrewfileEntryKind, BrewfileEntry[]>>(
    (accumulator, entry) => {
      accumulator[entry.kind].push(entry);
      return accumulator;
    },
    { brew: [], cask: [], tap: [], mas: [], service: [], unknown: [] }
  );
}

function EntryGroup({ entries, label }: { entries: BrewfileEntry[]; label: string }) {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold">{label}</h2>
          <Badge>{entries.length}</Badge>
        </div>
      </CardHeader>
      <CardContent>
        {entries.length > 0 ? (
          <div className="space-y-2">
            {entries.slice(0, 8).map((entry) => (
              <div key={entry.raw} className="truncate text-sm text-muted-foreground">
                {entry.name}
              </div>
            ))}
            {entries.length > 8 ? <div className="text-xs text-muted-foreground">+{entries.length - 8} more</div> : null}
          </div>
        ) : (
          <div className="text-sm text-muted-foreground">None</div>
        )}
      </CardContent>
    </Card>
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

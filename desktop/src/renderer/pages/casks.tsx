import { MoreHorizontal, RefreshCw } from "lucide-react";
import { useMemo, useState } from "react";
import type { Cask } from "@brewwery/shared-types";
import { PackageDetailDrawer } from "@/components/packages/package-detail-drawer";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { Tab, Tabs } from "@/components/ui/tabs";
import { usePackages } from "@/hooks/use-packages";
import { useSystem } from "@/hooks/use-system";

type SortKey = "name" | "version" | "status";

export function CasksPage() {
  const { packages, loading, error, refreshAll: refreshPackages } = usePackages("cask");
  const { refresh: refreshSystem } = useSystem();
  const [query, setQuery] = useState("");
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [selected, setSelected] = useState<Cask | undefined>();
  const rows = packages as Cask[];

  const visibleRows = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return rows
      .filter((pkg) => {
        if (!normalizedQuery) return true;
        return [pkg.token, pkg.name?.[0], pkg.description].some((value) => value?.toLowerCase().includes(normalizedQuery));
      })
      .sort((a, b) => compareCask(a, b, sortKey));
  }, [query, rows, sortKey]);

  const refreshAll = async () => {
    await Promise.all([refreshPackages(), refreshSystem()]);
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Casks</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {loading ? "Loading packages..." : `${visibleRows.length} of ${rows.length} installed casks`}
          </p>
        </div>
        <Button variant="primary" onClick={() => void refreshAll()} disabled={loading}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="flex items-center justify-between gap-3">
        <Input className="max-w-sm" placeholder="Search casks..." value={query} onChange={(event) => setQuery(event.target.value)} />
        <div className="flex items-center gap-2">
          <Tabs>
            <Tab aria-selected>All casks</Tab>
          </Tabs>
          <SortControls value={sortKey} onChange={setSortKey} />
        </div>
      </div>

      {loading ? <StatePanel kind="loading" title="Loading packages..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel
          kind="error"
          title={error.code === "BREW_JSON_PARSE_FAILED" ? "Failed to parse Homebrew output" : "Failed to load casks"}
          description={<ErrorDescription error={error} />}
        />
      ) : null}

      {!loading && !error && rows.length === 0 ? <StatePanel title="No casks installed" /> : null}
      {!loading && !error && rows.length > 0 && visibleRows.length === 0 ? <StatePanel title="No casks match your search" /> : null}

      {!loading && !error && visibleRows.length > 0 ? (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Cask</Th>
                <Th className="w-40">Version</Th>
                <Th className="w-28">Kind</Th>
                <Th>Description</Th>
                <Th className="w-32">Status</Th>
                <Th className="w-24 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {visibleRows.map((pkg) => (
                <tr key={pkg.token} className="cursor-pointer hover:bg-white/[0.025]" onClick={() => setSelected(pkg)}>
                  <Td>
                    <div className="font-medium">{pkg.name?.[0] ?? pkg.token}</div>
                    <div className="mt-1 text-xs text-muted-foreground">{pkg.token}</div>
                  </Td>
                  <Td className="text-muted-foreground">{pkg.installedVersion ?? "Unknown"}</Td>
                  <Td>
                    <Badge className="border-purple-500/25 bg-purple-500/10 text-purple-300">cask</Badge>
                  </Td>
                  <Td className="max-w-md truncate text-muted-foreground">{pkg.description ?? "Installed Homebrew cask"}</Td>
                  <Td>
                    <Badge className="border-emerald-500/25 bg-emerald-500/10 text-emerald-300">Installed</Badge>
                  </Td>
                  <Td className="text-right">
                    <Button
                      variant="ghost"
                      className="h-7 w-7 px-0"
                      aria-label={`Actions for ${pkg.name?.[0] ?? pkg.token}`}
                      onClick={(event) => {
                        event.stopPropagation();
                        setSelected(pkg);
                      }}
                    >
                      <MoreHorizontal className="h-4 w-4" />
                    </Button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </Card>
      ) : null}

      <PackageDetailDrawer detail={selected ? { kind: "cask", item: selected } : undefined} onClose={() => setSelected(undefined)} />
    </section>
  );
}

function SortControls({ onChange, value }: { onChange: (value: SortKey) => void; value: SortKey }) {
  return (
    <Tabs>
      <Tab aria-selected={value === "name"} onClick={() => onChange("name")}>
        Name
      </Tab>
      <Tab aria-selected={value === "version"} onClick={() => onChange("version")}>
        Version
      </Tab>
      <Tab aria-selected={value === "status"} onClick={() => onChange("status")}>
        Status
      </Tab>
    </Tabs>
  );
}

function compareCask(a: Cask, b: Cask, sortKey: SortKey) {
  if (sortKey === "version") {
    return (a.installedVersion ?? "").localeCompare(b.installedVersion ?? "", undefined, { numeric: true });
  }
  return (a.name?.[0] ?? a.token).localeCompare(b.name?.[0] ?? b.token);
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

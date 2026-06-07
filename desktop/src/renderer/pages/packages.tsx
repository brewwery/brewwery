import { MoreHorizontal, RefreshCw } from "lucide-react";
import { useMemo, useState } from "react";
import type { Formula } from "@brewwery/shared-types";
import { PackageDetailDrawer } from "@/components/packages/package-detail-drawer";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { Input } from "@/components/ui/input";
import { OperationProgressPanel } from "@/components/ui/operation-progress-panel";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { Tab, Tabs } from "@/components/ui/tabs";
import { commandFor, usePackageActions } from "@/hooks/use-package-actions";
import { usePackages } from "@/hooks/use-packages";
import { useSystem } from "@/hooks/use-system";
import type { PackageActionRequest } from "@brewwery/shared-types";

type FormulaFilter = "all" | "request" | "dependency";
type SortKey = "name" | "version" | "status";

export function PackagesPage() {
  const { packages, loading, error, refreshAll: refreshPackages } = usePackages("formula");
  const { refresh: refreshSystem } = useSystem();
  const { clearProgress, loading: actionLoading, progress, uninstall } = usePackageActions();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<FormulaFilter>("all");
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [selected, setSelected] = useState<Formula | undefined>();
  const [pendingUninstall, setPendingUninstall] = useState<PackageActionRequest | undefined>();
  const rows = packages as Formula[];

  const visibleRows = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return rows
      .filter((pkg) => {
        if (filter === "request" && pkg.installedOnRequest !== true) return false;
        if (filter === "dependency" && pkg.installedOnRequest !== false) return false;
        if (!normalizedQuery) return true;

        return [pkg.name, pkg.fullName, pkg.description].some((value) => value?.toLowerCase().includes(normalizedQuery));
      })
      .sort((a, b) => compareFormula(a, b, sortKey));
  }, [filter, query, rows, sortKey]);

  const refreshAll = async () => {
    await Promise.all([refreshPackages(), refreshSystem()]);
  };

  const confirmUninstall = async () => {
    if (!pendingUninstall) return;
    await uninstall(pendingUninstall);
    setPendingUninstall(undefined);
    setSelected(undefined);
    await refreshAll();
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Packages</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {loading ? "Loading packages..." : `${visibleRows.length} of ${rows.length} installed formulae`}
          </p>
        </div>
        <Button variant="primary" onClick={() => void refreshAll()} disabled={loading}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="flex items-center justify-between gap-3">
        <Input className="max-w-sm" placeholder="Search formulae..." value={query} onChange={(event) => setQuery(event.target.value)} />
        <div className="flex items-center gap-2">
          <Tabs>
            <Tab aria-selected={filter === "all"} onClick={() => setFilter("all")}>
              All formulae
            </Tab>
            <Tab aria-selected={filter === "request"} onClick={() => setFilter("request")}>
              On request
            </Tab>
            <Tab aria-selected={filter === "dependency"} onClick={() => setFilter("dependency")}>
              Dependencies
            </Tab>
          </Tabs>
          <SortControls value={sortKey} onChange={setSortKey} />
        </div>
      </div>

      {loading ? <StatePanel kind="loading" title="Loading packages..." /> : null}

      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}

      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel
          kind="error"
          title={error.code === "BREW_JSON_PARSE_FAILED" ? "Failed to parse Homebrew output" : "Failed to load formulae"}
          description={<ErrorDescription error={error} />}
        />
      ) : null}

      <OperationProgressPanel progress={progress} onClear={clearProgress} />

      {!loading && !error && rows.length === 0 ? <StatePanel title="No formulae installed" /> : null}
      {!loading && !error && rows.length > 0 && visibleRows.length === 0 ? <StatePanel title="No formulae match your search" /> : null}

      {!loading && !error && visibleRows.length > 0 ? (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Package</Th>
                <Th className="w-40">Version</Th>
                <Th className="w-28">Kind</Th>
                <Th>Description</Th>
                <Th className="w-32">Status</Th>
                <Th className="w-24 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {visibleRows.map((pkg) => (
                <tr
                  key={pkg.fullName ?? pkg.name}
                  className="cursor-pointer hover:bg-[var(--brewwery-card-hover)]"
                  onClick={() => setSelected(pkg)}
                >
                  <Td>
                    <div className="font-medium">{pkg.name}</div>
                    <div className="mt-1 text-xs text-muted-foreground">{pkg.fullName ?? pkg.name}</div>
                  </Td>
                  <Td className="text-muted-foreground">{pkg.installedVersion ?? "Unknown"}</Td>
                  <Td>
                    <Badge>formula</Badge>
                  </Td>
                  <Td className="max-w-md truncate text-muted-foreground">{pkg.description ?? "Installed Homebrew formula"}</Td>
                  <Td>
                    <div className="flex items-center gap-2">
                      <Badge className="border-[color:var(--brewwery-success-border)] bg-[var(--brewwery-success-bg)] text-[var(--brewwery-success)]">Installed</Badge>
                      {pkg.installedOnRequest !== undefined ? <Badge>{pkg.installedOnRequest ? "On request" : "Dependency"}</Badge> : null}
                    </div>
                  </Td>
                  <Td className="text-right">
                    <Button
                      variant="ghost"
                      className="h-7 w-7 px-0"
                      aria-label={`Actions for ${pkg.name}`}
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

      <PackageDetailDrawer
        detail={selected ? { kind: "formula", item: selected } : undefined}
        actionLoading={actionLoading}
        onClose={() => setSelected(undefined)}
        onUninstall={setPendingUninstall}
      />

      <ConfirmationDialog
        open={Boolean(pendingUninstall)}
        title={`Uninstall ${pendingUninstall?.name ?? "package"}?`}
        description={
          <>
            Brewwery will run <span className="font-mono text-foreground">{pendingUninstall ? commandFor("uninstall", pendingUninstall) : ""}</span>.
            <div className="mt-2">
              This may remove the selected package from your Homebrew environment. Dependencies are not automatically removed unless Homebrew
              does it.
            </div>
          </>
        }
        confirmLabel="Uninstall"
        loading={actionLoading}
        onCancel={() => setPendingUninstall(undefined)}
        onConfirm={() => void confirmUninstall()}
      />
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

function compareFormula(a: Formula, b: Formula, sortKey: SortKey) {
  if (sortKey === "version") {
    return (a.installedVersion ?? "").localeCompare(b.installedVersion ?? "", undefined, { numeric: true });
  }
  if (sortKey === "status") {
    return String(b.installedOnRequest).localeCompare(String(a.installedOnRequest));
  }
  return a.name.localeCompare(b.name);
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

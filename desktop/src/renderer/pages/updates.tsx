import { Download, RefreshCw } from "lucide-react";
import { useMemo, useState } from "react";
import type { OutdatedPackage, UpgradeRequest } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { OperationProgressPanel } from "@/components/ui/operation-progress-panel";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { useUpdates } from "@/hooks/use-updates";

type PendingUpgrade = { type: "one"; package: OutdatedPackage } | { type: "all" };

export function UpdatesPage() {
  const {
    updates,
    loading,
    actionLoading,
    clearProgress,
    error,
    lastChecked,
    progress,
    refresh,
    upgradePackage,
    upgradeAll
  } = useUpdates();
  const [pendingUpgrade, setPendingUpgrade] = useState<PendingUpgrade | undefined>();

  const formulaeCount = useMemo(() => updates.filter((item) => item.kind === "formula").length, [updates]);
  const casksCount = updates.length - formulaeCount;

  const confirmUpgrade = async () => {
    if (!pendingUpgrade) return;

    const upgrade = pendingUpgrade;
    setPendingUpgrade(undefined);

    if (upgrade.type === "all") {
      await upgradeAll();
    } else {
      const request: UpgradeRequest = {
        name: upgrade.package.name,
        kind: upgrade.package.kind
      };
      await upgradePackage(request);
    }
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Updates</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {lastChecked ? `Last checked ${lastChecked.toLocaleTimeString()}` : "Check installed formulae and casks for updates."}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" onClick={() => void refresh()} disabled={loading || actionLoading}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
          <Button variant="primary" onClick={() => setPendingUpgrade({ type: "all" })} disabled={loading || actionLoading || updates.length === 0}>
            <Download className="h-4 w-4" />
            Upgrade all
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <SummaryCard label="Total updates" value={updates.length} />
        <SummaryCard label="Formulae" value={formulaeCount} />
        <SummaryCard label="Casks" value={casksCount} />
      </div>

      {loading ? <StatePanel kind="loading" title="Loading updates..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel
          kind="error"
          title={error.code === "UPDATES_PARSE_FAILED" ? "Failed to parse Homebrew updates" : "Failed to load updates"}
          description={<ErrorDescription error={error} />}
        />
      ) : null}
      {!loading && !error && updates.length === 0 ? <StatePanel title="Everything is up to date" /> : null}

      <OperationProgressPanel progress={progress} onClear={clearProgress} />

      {!loading && !error && updates.length > 0 ? (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Package</Th>
                <Th className="w-44">Current</Th>
                <Th className="w-44">Latest</Th>
                <Th className="w-28">Kind</Th>
                <Th className="w-28">Status</Th>
                <Th className="w-32 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {updates.map((item) => (
                <tr key={`${item.kind}:${item.name}`} className="hover:bg-white/[0.025]">
                  <Td>
                    <div className="font-medium">{item.name}</div>
                    {item.installedVersions.length > 1 ? (
                      <div className="mt-1 text-xs text-muted-foreground">{item.installedVersions.join(", ")}</div>
                    ) : null}
                  </Td>
                  <Td className="text-muted-foreground">{item.currentVersion ?? item.installedVersions[0] ?? "Unknown"}</Td>
                  <Td>{item.latestVersion ?? "Unknown"}</Td>
                  <Td>
                    <Badge className={item.kind === "cask" ? "border-purple-500/25 bg-purple-500/10 text-purple-300" : undefined}>
                      {item.kind}
                    </Badge>
                  </Td>
                  <Td>
                    <Badge className="border-amber-500/25 bg-amber-500/10 text-accent">{item.pinned ? "Pinned" : "Outdated"}</Badge>
                  </Td>
                  <Td className="text-right">
                    <Button
                      variant="secondary"
                      className="h-8"
                      disabled={actionLoading}
                      onClick={() => setPendingUpgrade({ type: "one", package: item })}
                    >
                      Upgrade
                    </Button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </Card>
      ) : null}

      <ConfirmationDialog
        open={Boolean(pendingUpgrade)}
        title={pendingUpgrade?.type === "all" ? "Upgrade all packages?" : `Upgrade ${pendingUpgrade?.package.name}?`}
        description={
          pendingUpgrade?.type === "all" ? (
            <>Brewwery will run Homebrew's allowlisted upgrade command for all outdated packages.</>
          ) : (
            <>
              Brewwery will run <span className="font-mono text-foreground">{upgradeCommand(pendingUpgrade?.package)}</span>.
            </>
          )
        }
        confirmLabel="Upgrade"
        loading={actionLoading}
        onCancel={() => setPendingUpgrade(undefined)}
        onConfirm={() => void confirmUpgrade()}
      />
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

function upgradeCommand(pkg?: OutdatedPackage) {
  if (!pkg) return "brew upgrade";
  return pkg.kind === "cask" ? `brew upgrade --cask ${pkg.name}` : `brew upgrade ${pkg.name}`;
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

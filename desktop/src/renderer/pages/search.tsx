import { Info, SearchIcon, Star } from "lucide-react";
import { useState } from "react";
import type { PackageActionRequest, PackageSearchResult } from "@brewwery/shared-types";
import { PackageDetailDrawer } from "@/components/packages/package-detail-drawer";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { Input } from "@/components/ui/input";
import { OperationProgressPanel } from "@/components/ui/operation-progress-panel";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { usePackageActions, commandFor } from "@/hooks/use-package-actions";
import { usePackageDiscovery, usePackageInfo } from "@/hooks/use-package-discovery";
import { isFavoritePackage, useFavoritesStore } from "@/stores/favorites-store";
import { useUiStore } from "@/stores/ui-store";

type PendingAction = { action: "install" | "uninstall"; request: PackageActionRequest };

export function SearchPage() {
  const query = useUiStore((state) => state.searchQuery);
  const setQuery = useUiStore((state) => state.setSearchQuery);
  const { debouncedQuery, error, hydrateInfo, installedLoaded, invalidQuery, loading, results } = usePackageDiscovery(query);
  const { clearInfo, error: infoError, info, loadInfo, loading: infoLoading } = usePackageInfo();
  const { clearProgress, error: actionError, install, loading: actionLoading, progress, uninstall } = usePackageActions();
  const favorites = useFavoritesStore((state) => state.favorites);
  const [pendingAction, setPendingAction] = useState<PendingAction | undefined>();
  const detailInfo = hydrateInfo(info);

  const openResult = async (result: PackageSearchResult) => {
    await loadInfo({ name: result.name, kind: result.kind });
  };

  const confirmAction = async () => {
    if (!pendingAction) return;
    if (pendingAction.action === "install") {
      await install(pendingAction.request);
    } else {
      await uninstall(pendingAction.request);
    }
    await loadInfo(pendingAction.request);
    setPendingAction(undefined);
  };

  const visibleError = error ?? infoError ?? actionError;

  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Search</h1>
        <p className="mt-1 text-sm text-muted-foreground">Discover Homebrew formulae and casks, inspect details, then install safely.</p>
      </div>

      <div className="relative max-w-xl">
        <SearchIcon className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
        <Input className="pl-9" placeholder="Search Homebrew packages..." value={query} onChange={(event) => setQuery(event.target.value)} />
      </div>

      {loading ? <StatePanel kind="loading" title="Searching Homebrew..." /> : null}
      {!loading && invalidQuery ? (
        <StatePanel
          title="Use Latin characters to search Homebrew packages"
          description="Homebrew package search supports letters, numbers, @, -, _, ., and +."
        />
      ) : null}
      {!loading && visibleError?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && !invalidQuery && visibleError && visibleError.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel kind="error" title="Failed to search packages" description={<ErrorDescription error={visibleError} />} />
      ) : null}
      {!loading && !visibleError && !debouncedQuery ? (
        <StatePanel title="Search Homebrew packages" description="Type a package or app name to search formulae and casks." />
      ) : null}
      {!loading && !invalidQuery && !visibleError && debouncedQuery && results.length === 0 ? <StatePanel title="No packages found" /> : null}

      <OperationProgressPanel progress={progress} onClear={clearProgress} />

      {!loading && !invalidQuery && !visibleError && results.length > 0 ? (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Package</Th>
                <Th className="w-32">Kind</Th>
                <Th className="w-32">Status</Th>
                <Th className="w-28 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {results.map((result) => (
                <tr key={`${result.kind}:${result.name}`} className="cursor-pointer hover:bg-[var(--brewwery-card-hover)]" onClick={() => void openResult(result)}>
                  <Td className="font-medium">
                    <div className="flex items-center gap-2">
                      {result.name}
                      {isFavoritePackage(favorites, result.name, result.kind) ? <Star className="h-3.5 w-3.5 fill-accent text-accent" /> : null}
                    </div>
                  </Td>
                  <Td>
                    <Badge className={result.kind === "cask" ? "border-purple-500/25 bg-purple-500/10 text-purple-300" : undefined}>
                      {result.kind}
                    </Badge>
                  </Td>
                  <Td className="text-muted-foreground">
                    {!installedLoaded ? "Checking..." : result.installed ? "Installed" : "Available"}
                  </Td>
                  <Td className="text-right">
                    <Button
                      variant="ghost"
                      className="h-8"
                      disabled={infoLoading}
                      onClick={(event) => {
                        event.stopPropagation();
                        void openResult(result);
                      }}
                    >
                      <Info className="h-4 w-4" />
                      Details
                    </Button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </Card>
      ) : null}

      <PackageDetailDrawer
        detail={detailInfo ? { kind: "info", item: detailInfo } : undefined}
        actionLoading={actionLoading || infoLoading}
        onClose={clearInfo}
        onInstall={(request) => setPendingAction({ action: "install", request })}
        onUninstall={(request) => setPendingAction({ action: "uninstall", request })}
      />

      <ConfirmationDialog
        open={Boolean(pendingAction)}
        title={`${pendingAction?.action === "install" ? "Install" : "Uninstall"} ${pendingAction?.request.name ?? "package"}?`}
        description={
          <>
            Brewwery will run <span className="font-mono text-foreground">{pendingAction ? commandFor(pendingAction.action, pendingAction.request) : ""}</span>.
            {pendingAction?.action === "uninstall" ? (
              <div className="mt-2">
                This may remove the selected package from your Homebrew environment. Dependencies are not automatically removed unless
                Homebrew does it.
              </div>
            ) : null}
          </>
        }
        confirmLabel={pendingAction?.action === "install" ? "Install" : "Uninstall"}
        loading={actionLoading}
        onCancel={() => setPendingAction(undefined)}
        onConfirm={() => void confirmAction()}
      />
    </section>
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

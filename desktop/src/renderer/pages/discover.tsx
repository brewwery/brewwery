import { Info, PackagePlus, Star } from "lucide-react";
import { useMemo, useState } from "react";
import type { Cask, Formula, PackageActionRequest } from "@brewwery/shared-types";
import { PackageDetailDrawer } from "@/components/packages/package-detail-drawer";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { OperationProgressPanel } from "@/components/ui/operation-progress-panel";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { commandFor, usePackageActions } from "@/hooks/use-package-actions";
import { usePackageInfo } from "@/hooks/use-package-discovery";
import { usePackages } from "@/hooks/use-packages";
import { discoverCollections } from "@/lib/discover";
import { cn } from "@/lib/cn";
import { isPackageInstalled } from "@/lib/package-status";
import { isFavoritePackage, useFavoritesStore } from "@/stores/favorites-store";

type PendingAction = { action: "install"; request: PackageActionRequest };

export function DiscoverPage() {
  const { packages: formulaPackages } = usePackages("formula");
  const { packages: caskPackages } = usePackages("cask");
  const { clearInfo, error: infoError, info, loadInfo, loading: infoLoading } = usePackageInfo();
  const { clearProgress, error: actionError, install, loading: actionLoading, progress } = usePackageActions();
  const favorites = useFavoritesStore((state) => state.favorites);
  const toggleFavorite = useFavoritesStore((state) => state.toggleFavorite);
  const [selectedCollection, setSelectedCollection] = useState(discoverCollections[0]?.id ?? "");
  const [pendingAction, setPendingAction] = useState<PendingAction | undefined>();
  const formulae = formulaPackages as Formula[];
  const casks = caskPackages as Cask[];

  const collection = useMemo(
    () => discoverCollections.find((item) => item.id === selectedCollection) ?? discoverCollections[0]!,
    [selectedCollection]
  );

  const visibleError = infoError ?? actionError;

  const openDetails = async (request: PackageActionRequest) => {
    await loadInfo(request);
  };

  const confirmAction = async () => {
    if (!pendingAction) return;
    await install(pendingAction.request);
    await loadInfo(pendingAction.request);
    setPendingAction(undefined);
  };

  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Discover</h1>
        <p className="mt-1 text-sm text-muted-foreground">Discover useful Homebrew packages and casks.</p>
      </div>

      <div className="flex flex-wrap gap-2">
        {discoverCollections.map((item) => (
          <Button
            key={item.id}
            variant={item.id === collection.id ? "primary" : "secondary"}
            className="h-8"
            onClick={() => setSelectedCollection(item.id)}
          >
            {item.title}
          </Button>
        ))}
      </div>

      {visibleError ? <StatePanel kind="error" title="Failed to load package details" description={<ErrorDescription error={visibleError} />} /> : null}

      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="text-base font-semibold">{collection.title}</h2>
              <p className="mt-1 text-sm text-muted-foreground">{collection.description}</p>
            </div>
            <Badge>{collection.items.length} packages</Badge>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {collection.items.map((item) => {
              const installed = isPackageInstalled(item.name, item.kind, formulae, casks);
              const favorite = isFavoritePackage(favorites, item.name, item.kind);
              return (
                <div key={`${item.kind}:${item.name}`} className="rounded-lg border border-border bg-[var(--brewwery-pre)] p-3">
                  <div className="mb-2 flex items-start justify-between gap-3">
                    <div>
                      <div className="flex items-center gap-2 font-medium">
                        {item.name}
                        {favorite ? <Star className="h-3.5 w-3.5 fill-accent text-accent" /> : null}
                      </div>
                      <p className="mt-1 min-h-10 text-xs leading-5 text-muted-foreground">{item.description ?? "Curated Homebrew package."}</p>
                    </div>
                    <Badge className={item.kind === "cask" ? "border-purple-500/25 bg-purple-500/10 text-purple-300" : undefined}>
                      {item.kind}
                    </Badge>
                  </div>
                  <div className="mb-3 flex items-center gap-2">
                    <Badge
                      className={cn(
                        installed
                          ? "border-[color:var(--brewwery-success-border)] bg-[var(--brewwery-success-bg)] text-[var(--brewwery-success)]"
                          : "border-border bg-[var(--brewwery-card)]"
                      )}
                    >
                      {installed ? "Installed" : "Available"}
                    </Badge>
                  </div>
                  <div className="flex gap-2">
                    <Button className="h-8 flex-1" variant="secondary" onClick={() => void openDetails({ name: item.name, kind: item.kind })}>
                      <Info className="h-4 w-4" />
                      Details
                    </Button>
                    {!installed ? (
                      <Button className="h-8 flex-1" variant="primary" onClick={() => setPendingAction({ action: "install", request: item })}>
                        <PackagePlus className="h-4 w-4" />
                        Install
                      </Button>
                    ) : null}
                    <Button
                      className={cn(
                        "h-8 px-2",
                        favorite && "border border-accent/35 bg-[var(--brewwery-accent-soft)] text-accent hover:bg-[var(--brewwery-accent-soft)]"
                      )}
                      variant={favorite ? "secondary" : "ghost"}
                      aria-label={favorite ? `Remove ${item.name} from favorites` : `Add ${item.name} to favorites`}
                      onClick={() => toggleFavorite(item.name, item.kind)}
                    >
                      <Star className={cn("h-4 w-4", favorite && "fill-accent text-accent")} />
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      <OperationProgressPanel progress={progress} onClear={clearProgress} />

      <PackageDetailDrawer
        detail={info ? { kind: "info", item: info } : undefined}
        actionLoading={actionLoading || infoLoading}
        onClose={clearInfo}
        onInstall={(request) => setPendingAction({ action: "install", request })}
      />

      <ConfirmationDialog
        open={Boolean(pendingAction)}
        title={`Install ${pendingAction?.request.name ?? "package"}?`}
        description={
          <>
            Brewwery will run <span className="font-mono text-foreground">{pendingAction ? commandFor("install", pendingAction.request) : ""}</span>.
          </>
        }
        confirmLabel="Install"
        loading={actionLoading}
        onCancel={() => setPendingAction(undefined)}
        onConfirm={() => void confirmAction()}
      />
    </section>
  );
}

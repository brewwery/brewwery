import { Info, Star, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import type { Cask, Formula, PackageActionRequest } from "@brewwery/shared-types";
import { PackageDetailDrawer } from "@/components/packages/package-detail-drawer";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { usePackageInfo } from "@/hooks/use-package-discovery";
import { usePackages } from "@/hooks/use-packages";
import { packageDisplayName, isPackageInstalled } from "@/lib/package-status";
import { useFavoritesStore } from "@/stores/favorites-store";

export function FavoritesPage() {
  const favorites = useFavoritesStore((state) => state.favorites);
  const removeFavorite = useFavoritesStore((state) => state.removeFavorite);
  const { packages: formulaPackages, loading: formulaeLoading } = usePackages("formula");
  const { packages: caskPackages, loading: casksLoading } = usePackages("cask");
  const { clearInfo, error: infoError, info, loadInfo, loading: infoLoading } = usePackageInfo();
  const [checkingName, setCheckingName] = useState<string | undefined>();
  const loading = formulaeLoading || casksLoading;
  const formulae = formulaPackages as Formula[];
  const casks = caskPackages as Cask[];

  const rows = useMemo(
    () =>
      favorites
        .map((favorite) => ({
          ...favorite,
          displayName: packageDisplayName(favorite.name, favorite.kind, formulae, casks),
          installed: isPackageInstalled(favorite.name, favorite.kind, formulae, casks)
        }))
        .sort((a, b) => a.name.localeCompare(b.name)),
    [casks, favorites, formulae]
  );

  const openDetails = async (request: PackageActionRequest) => {
    setCheckingName(`${request.kind}:${request.name}`);
    await loadInfo(request);
    setCheckingName(undefined);
  };

  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Favorites</h1>
        <p className="mt-1 text-sm text-muted-foreground">Saved Homebrew packages and casks.</p>
      </div>

      {infoError ? <StatePanel kind="error" title="Failed to load package details" description={<ErrorDescription error={infoError} />} /> : null}

      {favorites.length === 0 ? (
        <StatePanel
          title="No favorites yet"
          description="Add packages from Search, Discover, Packages, or Casks."
        />
      ) : (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Package</Th>
                <Th className="w-28">Kind</Th>
                <Th className="w-36">Status</Th>
                <Th className="w-40 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((favorite) => {
                const key = `${favorite.kind}:${favorite.name}`;
                return (
                  <tr key={key} className="hover:bg-[var(--brewwery-card-hover)]">
                    <Td>
                      <div className="flex items-center gap-2 font-medium">
                        <Star className="h-3.5 w-3.5 fill-accent text-accent" />
                        {favorite.displayName}
                      </div>
                      <div className="mt-1 text-xs text-muted-foreground">{favorite.name}</div>
                    </Td>
                    <Td>
                      <Badge className={favorite.kind === "cask" ? "border-purple-500/25 bg-purple-500/10 text-purple-300" : undefined}>
                        {favorite.kind}
                      </Badge>
                    </Td>
                    <Td className="text-muted-foreground">
                      {loading ? "Checking..." : favorite.installed ? "Installed" : "Available"}
                    </Td>
                    <Td className="text-right">
                      <div className="inline-flex gap-2">
                        <Button
                          variant="ghost"
                          className="h-8"
                          disabled={infoLoading && checkingName === key}
                          onClick={() => void openDetails({ name: favorite.name, kind: favorite.kind })}
                        >
                          <Info className="h-4 w-4" />
                          Details
                        </Button>
                        <Button
                          variant="ghost"
                          className="h-8 px-2"
                          aria-label={`Remove ${favorite.name} from favorites`}
                          onClick={() => removeFavorite(favorite.name, favorite.kind)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        </Card>
      )}

      <PackageDetailDrawer detail={info ? { kind: "info", item: info } : undefined} actionLoading={infoLoading} onClose={clearInfo} />
    </section>
  );
}

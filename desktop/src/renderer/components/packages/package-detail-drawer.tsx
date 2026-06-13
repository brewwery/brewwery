import { Copy, ExternalLink, PackagePlus, PackageX, Star, Upload } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import type { Cask, Formula, PackageActionRequest, PackageInfo } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/cn";
import { isFavoritePackage, useFavoritesStore } from "@/stores/favorites-store";

type PackageDetail =
  | {
      kind: "formula";
      item: Formula;
    }
  | {
      kind: "cask";
      item: Cask;
    }
  | {
      kind: "info";
      item: PackageInfo;
    };

interface PackageDetailDrawerProps {
  detail?: PackageDetail;
  onClose: () => void;
  onInstall?: (request: PackageActionRequest) => void;
  onUninstall?: (request: PackageActionRequest) => void;
  onUpgrade?: (request: PackageActionRequest) => void;
  actionLoading?: boolean;
}

export function PackageDetailDrawer({ actionLoading, detail, onClose, onInstall, onUninstall, onUpgrade }: PackageDetailDrawerProps) {
  const favorites = useFavoritesStore((state) => state.favorites);
  const toggleFavorite = useFavoritesStore((state) => state.toggleFavorite);

  if (!detail) return null;

  const model = normalizeDetail(detail);
  const favorite = isFavoritePackage(favorites, model.name, model.kind);
  const installCommand = model.kind === "cask" ? `brew install --cask ${model.name}` : `brew install ${model.name}`;
  const uninstallCommand = model.kind === "cask" ? `brew uninstall --cask ${model.name}` : `brew uninstall ${model.name}`;
  const upgradeCommand = model.kind === "cask" ? `brew upgrade --cask ${model.name}` : `brew upgrade ${model.name}`;
  const request: PackageActionRequest = { name: model.name, kind: model.kind };

  return (
    <div className="fixed inset-0 z-40 flex justify-end bg-[var(--brewwery-overlay)]" onClick={onClose}>
      <aside
        className="flex h-full w-[420px] flex-col border-l border-border bg-[var(--brewwery-app-panel)] shadow-panel"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex h-14 shrink-0 items-center justify-between border-b border-border px-5">
          <div>
            <div className="text-sm font-semibold">{model.title}</div>
            <div className="text-xs text-muted-foreground">{model.subtitle}</div>
          </div>
          <Button variant="ghost" className="h-8 px-2" onClick={onClose}>
            Close
          </Button>
        </div>

        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-5">
          <div className="flex items-center gap-2">
            <Badge className={cn(model.kind === "formula" ? "text-accent" : "border-purple-500/25 bg-purple-500/10 text-purple-300")}>
              {model.kind}
            </Badge>
            {favorite ? (
              <Badge className="border-accent/30 bg-[var(--brewwery-accent-soft)] text-accent">
                <Star className="mr-1 h-3 w-3 fill-accent" />
                Favorite
              </Badge>
            ) : null}
            <Badge className={model.installed ? "border-[color:var(--brewwery-success-border)] bg-[var(--brewwery-success-bg)] text-[var(--brewwery-success)]" : "border-border bg-[var(--brewwery-card)]"}>
              {model.installed ? "Installed" : "Available"}
            </Badge>
            {model.installedOnRequest !== undefined ? (
              <Badge>{model.installedOnRequest ? "On request" : "Dependency"}</Badge>
            ) : null}
          </div>

          <Info label="Installed version" value={model.installedVersion ?? "Not installed"} />
          <Info label="Latest version" value={model.latestVersion ?? "Unknown"} />
          <Info label="Description" value={model.description ?? "No description available."} />

          {model.homepage ? (
            <div>
              <div className="mb-1 text-xs text-muted-foreground">Homepage</div>
              <button
                className="inline-flex max-w-full items-center gap-2 truncate text-sm text-accent hover:underline"
                onClick={() => model.homepage && window.open(model.homepage, "_blank", "noopener,noreferrer")}
              >
                <ExternalLink className="h-3.5 w-3.5 shrink-0" />
                <span className="truncate">{model.homepage}</span>
              </button>
            </div>
          ) : null}

          <Dependencies dependencies={model.dependencies ?? []} />
          {model.caveats ? <Info label="Caveats" value={model.caveats} /> : null}

          <div className="space-y-2 border-t border-border pt-5">
            <ActionButton
              icon={Star}
              label={favorite ? "Remove from Favorites" : "Add to Favorites"}
              iconClassName={favorite ? "fill-accent text-accent" : undefined}
              onClick={() => toggleFavorite(model.name, model.kind)}
            />
            {!model.installed ? (
              <ActionButton icon={PackagePlus} label="Install" disabled={!onInstall || actionLoading} onClick={() => onInstall?.(request)} />
            ) : (
              <ActionButton icon={PackageX} label="Uninstall" disabled={!onUninstall || actionLoading} onClick={() => onUninstall?.(request)} />
            )}
            <ActionButton icon={Upload} label="Upgrade" disabled={!onUpgrade || actionLoading} onClick={() => onUpgrade?.(request)} tooltip={!onUpgrade ? "Use Updates page" : undefined} />
            <ActionButton icon={Copy} label="Copy package name" onClick={() => copy(model.name)} />
            <ActionButton icon={Copy} label="Copy install command" onClick={() => copy(installCommand)} />
            <ActionButton icon={Copy} label="Copy uninstall command" disabled={!model.installed} onClick={() => copy(uninstallCommand)} />
            <ActionButton icon={Copy} label="Copy upgrade command" disabled={!model.installed} onClick={() => copy(upgradeCommand)} />
            <ActionButton icon={ExternalLink} label="Open homepage" disabled={!model.homepage} onClick={() => model.homepage && window.open(model.homepage, "_blank", "noopener,noreferrer")} />
          </div>

          {model.rawJson ? (
            <details className="border-t border-border pt-4">
              <summary className="cursor-pointer text-xs font-medium text-accent">Show raw JSON</summary>
              <pre className="mt-2 max-h-64 overflow-auto rounded-md border border-border bg-[var(--brewwery-pre)] p-3 text-xs leading-5 text-muted-foreground">
                {model.rawJson}
              </pre>
            </details>
          ) : null}
        </div>
      </aside>
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="mb-1 text-xs text-muted-foreground">{label}</div>
      <div className="rounded-md border border-border bg-[var(--brewwery-pre)] p-3 text-sm leading-6 text-foreground">{value}</div>
    </div>
  );
}

function Dependencies({ dependencies }: { dependencies: string[] }) {
  return (
    <div>
      <div className="mb-2 text-xs text-muted-foreground">Dependencies</div>
      {dependencies.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          {dependencies.map((dependency) => (
            <Badge key={dependency}>{dependency}</Badge>
          ))}
        </div>
      ) : (
        <div className="rounded-md border border-border bg-[var(--brewwery-pre)] p-3 text-sm text-muted-foreground">No dependencies listed.</div>
      )}
    </div>
  );
}

function ActionButton({
  disabled,
  icon: Icon,
  iconClassName,
  label,
  onClick,
  tooltip
}: {
  disabled?: boolean;
  icon: LucideIcon;
  iconClassName?: string;
  label: string;
  onClick?: () => void;
  tooltip?: string;
}) {
  return (
    <Button className="w-full justify-start" disabled={disabled} onClick={onClick} title={tooltip} variant="secondary">
      <Icon className={cn("h-4 w-4", iconClassName)} />
      {label}
    </Button>
  );
}

function copy(value: string) {
  void navigator.clipboard.writeText(value);
}

function normalizeDetail(detail: PackageDetail) {
  if (detail.kind === "info") {
    const displayTitle = detail.item.displayName?.[0] ?? detail.item.name;
    return {
      title: displayTitle,
      subtitle: detail.item.fullName ?? detail.item.token ?? detail.item.name,
      name: detail.item.token ?? detail.item.name,
      kind: detail.item.kind,
      installed: detail.item.installed,
      installedVersion: detail.item.installedVersion,
      latestVersion: detail.item.latestVersion,
      description: detail.item.description,
      homepage: detail.item.homepage,
      dependencies: detail.item.dependencies,
      caveats: detail.item.caveats,
      rawJson: detail.item.rawJson,
      installedOnRequest: undefined
    };
  }

  if (detail.kind === "formula") {
    return {
      title: detail.item.name,
      subtitle: detail.item.fullName ?? detail.item.name,
      name: detail.item.name,
      kind: "formula" as const,
      installed: true,
      installedVersion: detail.item.installedVersion,
      latestVersion: undefined,
      description: detail.item.description,
      homepage: detail.item.homepage,
      dependencies: detail.item.dependencies,
      caveats: undefined,
      rawJson: undefined,
      installedOnRequest: detail.item.installedOnRequest
    };
  }

  return {
    title: detail.item.name?.[0] ?? detail.item.token,
    subtitle: detail.item.token,
    name: detail.item.token,
    kind: "cask" as const,
    installed: true,
    installedVersion: detail.item.installedVersion,
    latestVersion: undefined,
    description: detail.item.description,
    homepage: detail.item.homepage,
    dependencies: undefined,
    caveats: undefined,
    rawJson: undefined,
    installedOnRequest: undefined
  };
}

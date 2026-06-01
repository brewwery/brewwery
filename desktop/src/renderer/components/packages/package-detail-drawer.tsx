import { Copy, ExternalLink, FolderOpen, Terminal } from "lucide-react";
import type { Cask, Formula } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/cn";

type PackageDetail =
  | {
      kind: "formula";
      item: Formula;
    }
  | {
      kind: "cask";
      item: Cask;
    };

interface PackageDetailDrawerProps {
  detail?: PackageDetail;
  onClose: () => void;
}

export function PackageDetailDrawer({ detail, onClose }: PackageDetailDrawerProps) {
  if (!detail) return null;

  const isFormula = detail.kind === "formula";
  const title = isFormula ? detail.item.name : detail.item.name?.[0] ?? detail.item.token;
  const subtitle = isFormula ? detail.item.fullName : detail.item.token;
  const version = detail.item.installedVersion ?? "Unknown";
  const description = detail.item.description ?? (isFormula ? "Installed Homebrew formula" : "Installed Homebrew cask");
  const homepage = detail.item.homepage;
  const installCommand = isFormula ? `brew install ${detail.item.name}` : `brew install --cask ${detail.item.token}`;
  const copyName = isFormula ? detail.item.name : detail.item.token;

  return (
    <div className="fixed inset-0 z-40 flex justify-end bg-black/30" onClick={onClose}>
      <aside
        className="h-full w-[420px] border-l border-border bg-[#111318] shadow-panel"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex h-14 items-center justify-between border-b border-border px-5">
          <div>
            <div className="text-sm font-semibold">{title}</div>
            <div className="text-xs text-muted-foreground">{subtitle}</div>
          </div>
          <Button variant="ghost" className="h-8 px-2" onClick={onClose}>
            Close
          </Button>
        </div>

        <div className="space-y-5 p-5">
          <div className="flex items-center gap-2">
            <Badge className={cn(isFormula ? "text-accent" : "border-purple-500/25 bg-purple-500/10 text-purple-300")}>
              {detail.kind}
            </Badge>
            <Badge className="border-emerald-500/25 bg-emerald-500/10 text-emerald-300">Installed</Badge>
            {isFormula && detail.item.installedOnRequest !== undefined ? (
              <Badge>{detail.item.installedOnRequest ? "On request" : "Dependency"}</Badge>
            ) : null}
          </div>

          <Info label="Installed version" value={version} />
          <Info label="Description" value={description} />

          {homepage ? (
            <div>
              <div className="mb-1 text-xs text-muted-foreground">Homepage</div>
              <button
                className="inline-flex max-w-full items-center gap-2 truncate text-sm text-accent hover:underline"
                onClick={() => window.open(homepage, "_blank", "noopener,noreferrer")}
              >
                <ExternalLink className="h-3.5 w-3.5 shrink-0" />
                <span className="truncate">{homepage}</span>
              </button>
            </div>
          ) : null}

          {isFormula ? <Dependencies dependencies={detail.item.dependencies ?? []} /> : null}

          <div className="space-y-2 border-t border-border pt-5">
            <ActionButton icon={Copy} label="Copy package name" onClick={() => copy(copyName)} />
            <ActionButton icon={Copy} label="Copy install command" onClick={() => copy(installCommand)} />
            <ActionButton icon={ExternalLink} label="Open homepage" disabled={!homepage} onClick={() => homepage && window.open(homepage, "_blank", "noopener,noreferrer")} />
            <ActionButton icon={FolderOpen} label="Open package path" disabled tooltip="Coming later" />
            <ActionButton icon={Terminal} label="Open Terminal" disabled tooltip="Coming later" />
          </div>
        </div>
      </aside>
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="mb-1 text-xs text-muted-foreground">{label}</div>
      <div className="rounded-md border border-border bg-black/15 p-3 text-sm leading-6 text-foreground">{value}</div>
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
        <div className="rounded-md border border-border bg-black/15 p-3 text-sm text-muted-foreground">No dependencies listed.</div>
      )}
    </div>
  );
}

function ActionButton({
  disabled,
  icon: Icon,
  label,
  onClick,
  tooltip
}: {
  disabled?: boolean;
  icon: typeof Copy;
  label: string;
  onClick?: () => void;
  tooltip?: string;
}) {
  return (
    <Button className="w-full justify-start" disabled={disabled} onClick={onClick} title={tooltip} variant="secondary">
      <Icon className="h-4 w-4" />
      {label}
    </Button>
  );
}

function copy(value: string) {
  void navigator.clipboard.writeText(value);
}

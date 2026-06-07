import { usePackages } from "@/hooks/use-packages";
import { useSystem } from "@/hooks/use-system";
import { APP_VERSION } from "@/lib/constants";

export function StatusBar() {
  const { detection, system, loading } = useSystem();
  const { packages: formulae } = usePackages("formula");
  const { packages: casks } = usePackages("cask");

  return (
    <footer className="flex items-center justify-between border-l border-t border-border bg-[var(--brewwery-titlebar)] px-4 text-xs text-muted-foreground">
      <div className="flex items-center gap-4">
        <span className="flex items-center gap-2">
          <span className={detection?.found ? "h-2 w-2 rounded-full bg-[var(--brewwery-success)]" : "h-2 w-2 rounded-full bg-[var(--brewwery-warning)]"} />
          {loading ? "Loading Homebrew..." : detection?.found ? "Homebrew running" : "Homebrew not found"}
        </span>
        <span>{system?.version ?? "unknown"}</span>
        <span>{system?.prefix ?? "No prefix detected"}</span>
        <span>{system?.architecture ?? "unknown"}</span>
        <span>{formulae.length} formulae</span>
        <span>{casks.length} casks</span>
      </div>
      <div className="flex items-center gap-3">
        <span>Brewwery {APP_VERSION}</span>
      </div>
    </footer>
  );
}

import { Terminal } from "lucide-react";
import { Button } from "@/components/ui/button";
import { usePackages } from "@/hooks/use-packages";
import { useSystem } from "@/hooks/use-system";

export function StatusBar() {
  const { detection, system, loading } = useSystem();
  const { packages: formulae } = usePackages("formula");
  const { packages: casks } = usePackages("cask");

  return (
    <footer className="flex items-center justify-between border-l border-t border-border bg-[#101216] px-4 text-xs text-muted-foreground">
      <div className="flex items-center gap-4">
        <span className="flex items-center gap-2">
          <span className={detection?.found ? "h-2 w-2 rounded-full bg-emerald-400" : "h-2 w-2 rounded-full bg-amber-400"} />
          {loading ? "Loading Homebrew..." : detection?.found ? "Homebrew running" : "Homebrew not found"}
        </span>
        <span>{system?.version ?? "unknown"}</span>
        <span>{system?.prefix ?? "No prefix detected"}</span>
        <span>{system?.architecture ?? "unknown"}</span>
        <span>{formulae.length} formulae</span>
        <span>{casks.length} casks</span>
      </div>
      <Button variant="ghost" className="h-7 px-2 text-xs" disabled title="Terminal handoff is planned for a later release.">
        <Terminal className="h-3.5 w-3.5" />
        Open Terminal
      </Button>
    </footer>
  );
}

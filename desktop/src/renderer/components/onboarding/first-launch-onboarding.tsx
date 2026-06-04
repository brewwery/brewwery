import { ExternalLink } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { useSystem } from "@/hooks/use-system";
import { HOME_BREW_URL } from "@/lib/constants";
import { useSettingsStore } from "@/stores/settings-store";
import { useUiStore } from "@/stores/ui-store";

export function FirstLaunchOnboarding() {
  const { detection, error, loading, system } = useSystem();
  const completeFirstLaunch = useSettingsStore((state) => state.completeFirstLaunch);
  const setActivePage = useUiStore((state) => state.setActivePage);
  const found = detection?.found && system;

  const openSettings = () => {
    completeFirstLaunch();
    setActivePage("settings");
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-6 backdrop-blur-sm">
      <Card className="w-full max-w-xl overflow-hidden border-border bg-[#15181d] shadow-2xl">
        <CardHeader>
          <div className="text-lg font-semibold">Welcome to Brewwery</div>
          <p className="text-sm text-muted-foreground">Homebrew, without the terminal.</p>
        </CardHeader>
        <CardContent className="space-y-5">
          {loading ? (
            <div className="rounded-md border border-border bg-background/60 p-4 text-sm text-muted-foreground">Detecting Homebrew...</div>
          ) : found ? (
            <div className="grid gap-3 rounded-md border border-border bg-background/60 p-4 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Detected Homebrew</span>
                <Badge className="border-emerald-500/25 bg-emerald-500/10 text-emerald-300">Found</Badge>
              </div>
              <InfoRow label="Version" value={system.version} />
              <InfoRow label="Prefix" value={system.prefix} />
              <InfoRow label="Architecture" value={system.architecture} />
              <InfoRow label="Executable" value={system.path} />
            </div>
          ) : (
            <div className="rounded-md border border-border bg-background/60 p-4 text-sm">
              <div className="font-medium">Homebrew not found</div>
              <p className="mt-1 text-muted-foreground">Brewwery checked:</p>
              {(detection?.checkedPaths ?? ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]).map((path) => (
                <div key={path} className="mt-1 font-mono text-xs text-foreground">
                  {path}
                </div>
              ))}
              {error?.message ? <p className="mt-3 text-xs text-red-300">{error.message}</p> : null}
            </div>
          )}

          <div className="flex items-center justify-end gap-2">
            {!found ? (
              <Button variant="secondary" onClick={() => window.open(HOME_BREW_URL, "_blank", "noopener,noreferrer")}>
                <ExternalLink className="h-4 w-4" />
                Open Homebrew website
              </Button>
            ) : null}
            {!found ? (
              <Button variant="ghost" onClick={openSettings}>
                Set custom path later
              </Button>
            ) : null}
            <Button variant="primary" onClick={completeFirstLaunch}>
              Continue
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[120px_1fr] gap-3">
      <span className="text-muted-foreground">{label}</span>
      <span className="truncate font-mono text-xs text-foreground">{value}</span>
    </div>
  );
}

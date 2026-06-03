import { Activity, Archive, Download, Package } from "lucide-react";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { StatePanel } from "@/components/ui/state-panel";
import { usePackages } from "@/hooks/use-packages";
import { useServices } from "@/hooks/use-services";
import { useSystem } from "@/hooks/use-system";
import { useUpdates } from "@/hooks/use-updates";

export function DashboardPage() {
  const { detection, system, loading } = useSystem();
  const { packages } = usePackages("formula");
  const { packages: casks } = usePackages("cask");
  const { updates } = useUpdates();
  const { services } = useServices();

  const stats = [
    { label: "Formulae", value: packages.length, icon: Package },
    { label: "Casks", value: casks.length, icon: Archive },
    { label: "Updates", value: updates.length, icon: Download },
    { label: "Services", value: services.length, icon: Activity }
  ];

  return (
    <section className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Dashboard</h1>
        <p className="mt-1 text-sm text-muted-foreground">A quick read on this Mac's Homebrew installation.</p>
      </div>

      {loading ? <StatePanel kind="loading" title="Loading Homebrew..." /> : null}

      {!loading && detection && !detection.found ? (
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
      ) : null}

      <div className="grid grid-cols-4 gap-4">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <Card key={stat.label}>
              <CardContent className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-muted-foreground">{stat.label}</div>
                  <div className="mt-1 text-2xl font-semibold">{stat.value}</div>
                </div>
                <Icon className="h-5 w-5 text-accent" />
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card>
        <CardHeader>
          <h2 className="text-sm font-semibold">Homebrew</h2>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm">
          <Info label="Status" value={detection?.found ? "Detected" : "Not detected"} />
          <Info label="Version" value={system?.version ?? "Unknown"} />
          <Info label="Prefix" value={system?.prefix ?? "Unknown"} />
          <Info label="Executable" value={system?.path ?? "Unknown"} />
          <Info label="Architecture" value={system?.architecture ?? "unknown"} />
          <Info label="Formulae" value={String(packages.length)} />
          <Info label="Casks" value={String(casks.length)} />
          <Info label="Updates" value={String(updates.length)} />
          <Info label="Services" value={String(services.length)} />
        </CardContent>
      </Card>
    </section>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-border bg-black/15 p-3">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 truncate text-foreground">{value}</div>
    </div>
  );
}

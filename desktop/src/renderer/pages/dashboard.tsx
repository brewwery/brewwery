import { Activity, Archive, Download, Package, RefreshCw, Server } from "lucide-react";
import type { BrewService, OutdatedPackage } from "@brewwery/shared-types";
import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { StatePanel } from "@/components/ui/state-panel";
import { usePackages } from "@/hooks/use-packages";
import { useServices } from "@/hooks/use-services";
import { useSystem } from "@/hooks/use-system";
import { useUpdates } from "@/hooks/use-updates";
import { cn } from "@/lib/cn";
import { useUiStore } from "@/stores/ui-store";

export function DashboardPage() {
  const [lastRefreshed, setLastRefreshed] = useState<Date>();
  const { detection, error: systemError, loading: systemLoading, refresh: refreshSystem, system } = useSystem();
  const { error: formulaeError, loading: formulaeLoading, packages, refresh: refreshFormulae } = usePackages("formula");
  const { error: casksError, loading: casksLoading, packages: casks, refresh: refreshCasks } = usePackages("cask");
  const { error: updatesError, loading: updatesLoading, refresh: refreshUpdates, updates } = useUpdates();
  const { error: servicesError, loading: servicesLoading, refresh: refreshServices, services } = useServices();
  const setActivePage = useUiStore((state) => state.setActivePage);

  const loadingSomething = systemLoading || formulaeLoading || casksLoading || updatesLoading || servicesLoading;
  const homebrewMissing = detection && !detection.found;
  const runningServices = services.filter((service) => service.status === "started");
  const stoppedServices = services.filter((service) => service.status === "stopped");
  const errorServices = services.filter((service) => service.status === "error");
  const previewServices = [...runningServices, ...services.filter((service) => service.status !== "started")].slice(0, 5);
  const formulaUpdates = updates.filter((item) => item.kind === "formula");
  const caskUpdates = updates.filter((item) => item.kind === "cask");

  const stats = [
    { label: "Formulae", value: packages.length, loading: formulaeLoading, icon: Package },
    { label: "Casks", value: casks.length, loading: casksLoading, icon: Archive },
    { label: "Updates", value: updates.length, loading: updatesLoading, icon: Download },
    { label: "Services", value: services.length, loading: servicesLoading, icon: Activity }
  ];

  const refreshAll = async () => {
    await Promise.all([refreshSystem(), refreshFormulae(), refreshCasks(), refreshUpdates(), refreshServices()]);
    setLastRefreshed(new Date());
  };

  return (
    <section className="space-y-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Dashboard</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            A quick read on this Mac's Homebrew installation.
            <span className="ml-2">{loadingSomething ? "Refreshing..." : formatLastRefreshed(lastRefreshed)}</span>
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button title="Reloads current Homebrew data without running brew update" variant="secondary" onClick={() => void refreshAll()} disabled={loadingSomething}>
            <RefreshCw className={cn("h-4 w-4", loadingSomething ? "animate-spin" : "")} />
            Refresh data
          </Button>
        </div>
      </div>

      {homebrewMissing ? (
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

      <Card>
        <CardContent className="flex flex-wrap items-center gap-3 py-3 text-sm">
          <StatusDot tone={systemError ? "error" : detection?.found ? "success" : systemLoading ? "loading" : "neutral"} />
          <span>{systemLoading ? "Checking Homebrew..." : detection?.found ? "Homebrew running" : "Homebrew not found"}</span>
          <span className="text-muted-foreground">{system?.version ?? "Version pending"}</span>
          <span className="text-muted-foreground">{system?.prefix ?? "Prefix pending"}</span>
          <span className="text-muted-foreground">{system?.architecture ?? "arch pending"}</span>
          {loadingSomething ? <Badge className="ml-auto">Updating</Badge> : <Badge className="ml-auto">Live data</Badge>}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-4">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <Card key={stat.label}>
              <CardContent className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-muted-foreground">{stat.label}</div>
                  <div className="mt-1 text-2xl font-semibold">{stat.loading ? "..." : stat.value}</div>
                </div>
                <Icon className="h-5 w-5 text-accent" />
              </CardContent>
            </Card>
          );
        })}
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_1fr]">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between gap-3">
            <div>
              <h2 className="text-sm font-semibold">Services</h2>
              <p className="mt-1 text-xs text-muted-foreground">
                {servicesLoading ? "Loading services..." : `${runningServices.length} running, ${stoppedServices.length} stopped`}
              </p>
            </div>
            <Button variant="ghost" className="h-8" onClick={() => setActivePage("services")}>
              View all
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex flex-wrap gap-2 text-xs">
              <ServicePill label="Started" value={runningServices.length} tone="started" />
              <ServicePill label="Stopped" value={stoppedServices.length} tone="stopped" />
              <ServicePill label="Errors" value={errorServices.length} tone="error" />
            </div>
            {servicesError ? <InlineError message="Failed to load services" /> : null}
            {!servicesError && !servicesLoading && services.length === 0 ? <EmptyLine text="No Homebrew services found" /> : null}
            {servicesLoading && services.length === 0 ? <SkeletonRows count={4} /> : null}
            {previewServices.map((service) => (
              <ServiceRow key={service.name} service={service} />
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between gap-3">
            <div>
              <h2 className="text-sm font-semibold">Updates</h2>
              <p className="mt-1 text-xs text-muted-foreground">
                {updatesLoading ? "Checking outdated packages..." : `${updates.length} available updates`}
              </p>
            </div>
            <Button variant="ghost" className="h-8" onClick={() => setActivePage("updates")}>
              View all
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <MiniBars
              items={[
                { label: "Formulae", value: formulaUpdates.length, className: "bg-[var(--brewwery-warning)]" },
                { label: "Casks", value: caskUpdates.length, className: "bg-purple-400" }
              ]}
            />
            {updatesError ? <InlineError message="Failed to load updates" /> : null}
            {!updatesError && !updatesLoading && updates.length === 0 ? <EmptyLine text="Everything is up to date" /> : null}
            {updatesLoading && updates.length === 0 ? <SkeletonRows count={4} /> : null}
            {updates.slice(0, 6).map((update) => (
              <UpdateRow key={`${update.kind}:${update.name}`} update={update} />
            ))}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <h2 className="text-sm font-semibold">Homebrew</h2>
        </CardHeader>
        <CardContent className="grid gap-4 text-sm md:grid-cols-2 xl:grid-cols-3">
          <Info label="Status" value={systemLoading ? "Checking..." : detection?.found ? "Detected" : "Not detected"} />
          <Info label="Version" value={system?.version ?? "Unknown"} />
          <Info label="Prefix" value={system?.prefix ?? "Unknown"} />
          <Info label="Executable" value={system?.path ?? "Unknown"} />
          <Info label="Architecture" value={system?.architecture ?? "unknown"} />
          <Info label="Formulae / Casks" value={`${packages.length} / ${casks.length}`} />
        </CardContent>
      </Card>

    </section>
  );
}

function formatLastRefreshed(value?: Date) {
  return value ? `Last refreshed ${value.toLocaleTimeString()}` : "Live data ready";
}

function StatusDot({ tone }: { tone: "success" | "error" | "loading" | "neutral" }) {
  return (
    <span
      className={cn(
        "h-2.5 w-2.5 rounded-full",
        tone === "success" ? "bg-[var(--brewwery-success)]" : "",
        tone === "error" ? "bg-[var(--brewwery-danger)]" : "",
        tone === "loading" ? "animate-pulse bg-accent" : "",
        tone === "neutral" ? "bg-muted-foreground" : ""
      )}
    />
  );
}

function MiniBars({ items }: { items: Array<{ label: string; value: number; className: string }> }) {
  const max = Math.max(...items.map((item) => item.value), 1);
  return (
    <div className="space-y-2">
      {items.map((item) => (
        <div key={item.label} className="grid grid-cols-[90px_1fr_40px] items-center gap-3 text-xs">
          <span className="text-muted-foreground">{item.label}</span>
          <div className="h-2 overflow-hidden rounded-full bg-muted">
            <div className={cn("h-full rounded-full", item.className)} style={{ width: `${Math.max((item.value / max) * 100, item.value ? 8 : 0)}%` }} />
          </div>
          <span className="text-right text-foreground">{item.value}</span>
        </div>
      ))}
    </div>
  );
}

function ServiceRow({ service }: { service: BrewService }) {
  return (
    <div className="flex items-center gap-3 rounded-md border border-border bg-background/45 px-3 py-2.5">
      <Server className="h-4 w-4 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{service.name}</div>
        <div className="truncate text-xs text-muted-foreground">{service.file ?? service.user ?? "Homebrew service"}</div>
      </div>
      <ServiceBadge status={service.status} />
    </div>
  );
}

function ServicePill({ label, tone, value }: { label: string; tone: "started" | "stopped" | "error"; value: number }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 rounded-full border px-2.5 py-1",
        tone === "started" ? "border-[color:var(--brewwery-success-border)] bg-[var(--brewwery-success-bg)] text-[var(--brewwery-success)]" : "",
        tone === "stopped" ? "border-border bg-[var(--brewwery-card)] text-muted-foreground" : "",
        tone === "error" ? "border-[color:var(--brewwery-danger-border)] bg-[var(--brewwery-danger-bg)] text-[var(--brewwery-danger)]" : ""
      )}
    >
      {label}
      <span className="font-medium text-foreground">{value}</span>
    </span>
  );
}

function ServiceBadge({ status }: { status: BrewService["status"] }) {
  const className =
    status === "started"
      ? "border-[color:var(--brewwery-success-border)] bg-[var(--brewwery-success-bg)] text-[var(--brewwery-success)]"
      : status === "error"
        ? "border-[color:var(--brewwery-danger-border)] bg-[var(--brewwery-danger-bg)] text-[var(--brewwery-danger)]"
        : "border-border bg-[var(--brewwery-card)] text-muted-foreground";
  return <Badge className={className}>{status}</Badge>;
}

function UpdateRow({ update }: { update: OutdatedPackage }) {
  return (
    <div className="flex items-center gap-3 rounded-md border border-border bg-background/45 p-3">
      <Download className="h-4 w-4 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{update.name}</div>
        <div className="truncate text-xs text-muted-foreground">
          {update.currentVersion ?? update.installedVersions[0] ?? "unknown"} {"->"} {update.latestVersion ?? "unknown"}
        </div>
      </div>
      <Badge className={update.kind === "cask" ? "border-purple-500/25 bg-purple-500/10 text-purple-300" : undefined}>
        {update.kind}
      </Badge>
    </div>
  );
}

function SkeletonRows({ count }: { count: number }) {
  return (
    <>
      {Array.from({ length: count }).map((_, index) => (
        <div key={index} className="h-[66px] animate-pulse rounded-md border border-border bg-[var(--brewwery-card)]" />
      ))}
    </>
  );
}

function EmptyLine({ text }: { text: string }) {
  return <div className="rounded-md border border-border bg-background/45 p-3 text-sm text-muted-foreground">{text}</div>;
}

function InlineError({ message }: { message: string }) {
  return <div className="rounded-md border border-[color:var(--brewwery-danger-border)] bg-[var(--brewwery-danger-bg)] p-3 text-sm text-[var(--brewwery-danger)]">{message}</div>;
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-border bg-[var(--brewwery-pre)] p-3">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 truncate text-foreground">{value}</div>
    </div>
  );
}

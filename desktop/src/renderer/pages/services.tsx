import { RefreshCw } from "lucide-react";
import { useMemo, useState } from "react";
import type { BrewService } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { Table, Td, Th } from "@/components/ui/table";
import { useServices } from "@/hooks/use-services";
import { cn } from "@/lib/cn";

type ServiceAction = "start" | "stop" | "restart";
type PendingServiceAction = { service: BrewService; action: ServiceAction };

export function ServicesPage() {
  const { services, loading, actionLoading, error, refresh, runAction } = useServices();
  const [pendingAction, setPendingAction] = useState<PendingServiceAction | undefined>();

  const counts = useMemo(
    () => ({
      total: services.length,
      running: services.filter((service) => service.status === "started").length,
      stopped: services.filter((service) => service.status === "stopped").length,
      error: services.filter((service) => service.status === "error").length
    }),
    [services]
  );

  const confirmAction = async () => {
    if (!pendingAction) return;
    await runAction(pendingAction.action, { name: pendingAction.service.name });
    setPendingAction(undefined);
  };

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Services</h1>
          <p className="mt-1 text-sm text-muted-foreground">Inspect and manage Homebrew services with explicit confirmation.</p>
        </div>
        <Button variant="secondary" onClick={() => void refresh()} disabled={loading || actionLoading}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <SummaryCard label="Total services" value={counts.total} />
        <SummaryCard label="Running" value={counts.running} />
        <SummaryCard label="Stopped" value={counts.stopped} />
        <SummaryCard label="Errors" value={counts.error} />
      </div>

      {loading ? <StatePanel kind="loading" title="Loading services..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel kind="error" title="Failed to load services" description={<ErrorDescription error={error} />} />
      ) : null}
      {!loading && !error && services.length === 0 ? <StatePanel title="No Homebrew services found" /> : null}

      {!loading && !error && services.length > 0 ? (
        <Card className="overflow-hidden">
          <Table>
            <thead>
              <tr>
                <Th>Service</Th>
                <Th className="w-32">Status</Th>
                <Th className="w-40">User</Th>
                <Th>File</Th>
                <Th className="w-56 text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {services.map((service) => (
                <tr key={service.name} className="hover:bg-[var(--brewwery-card-hover)]">
                  <Td>
                    <div className="font-medium">{service.name}</div>
                    {service.command ? <div className="mt-1 max-w-md truncate text-xs text-muted-foreground">{service.command}</div> : null}
                  </Td>
                  <Td>
                    <ServiceStatusBadge status={service.status} />
                  </Td>
                  <Td className="text-muted-foreground">{service.user ?? "Unknown"}</Td>
                  <Td className="max-w-md truncate text-muted-foreground">{service.file ?? "No launch agent file"}</Td>
                  <Td className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        variant="secondary"
                        className="h-8"
                        disabled={actionLoading || service.status === "started"}
                        onClick={() => setPendingAction({ service, action: "start" })}
                      >
                        Start
                      </Button>
                      <Button
                        variant="secondary"
                        className="h-8"
                        disabled={actionLoading || service.status === "stopped"}
                        onClick={() => setPendingAction({ service, action: "stop" })}
                      >
                        Stop
                      </Button>
                      <Button
                        variant="secondary"
                        className="h-8"
                        disabled={actionLoading}
                        onClick={() => setPendingAction({ service, action: "restart" })}
                      >
                        Restart
                      </Button>
                    </div>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </Card>
      ) : null}

      <ConfirmationDialog
        open={Boolean(pendingAction)}
        title={`${capitalize(pendingAction?.action ?? "restart")} ${pendingAction?.service.name ?? "service"}?`}
        description={
          <>
            Brewwery will run{" "}
            <span className="font-mono text-foreground">
              brew services {pendingAction?.action ?? "restart"} {pendingAction?.service.name}
            </span>
            .
          </>
        }
        confirmLabel={capitalize(pendingAction?.action ?? "Run")}
        loading={actionLoading}
        onCancel={() => setPendingAction(undefined)}
        onConfirm={() => void confirmAction()}
      />
    </section>
  );
}

function SummaryCard({ label, value }: { label: string; value: number }) {
  return (
    <Card>
      <CardContent>
        <div className="text-sm text-muted-foreground">{label}</div>
        <div className="mt-1 text-2xl font-semibold">{value}</div>
      </CardContent>
    </Card>
  );
}

function ServiceStatusBadge({ status }: { status: BrewService["status"] }) {
  return (
    <Badge
      className={cn(
        status === "started" && "border-emerald-500/25 bg-emerald-500/10 text-emerald-300",
        status === "stopped" && "border-border bg-[var(--brewwery-card)] text-muted-foreground",
        status === "error" && "border-red-500/25 bg-red-500/10 text-red-300",
        status === "unknown" && "border-zinc-500/25 bg-zinc-500/10 text-zinc-300"
      )}
    >
      {status}
    </Badge>
  );
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
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

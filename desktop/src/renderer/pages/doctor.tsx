import { Clipboard, Stethoscope } from "lucide-react";
import type { DoctorDiagnostic } from "@brewwery/shared-types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ErrorDescription, StatePanel } from "@/components/ui/state-panel";
import { useDoctor } from "@/hooks/use-doctor";
import { cn } from "@/lib/cn";

export function DoctorPage() {
  const { result, loading, error, runDoctor } = useDoctor();
  const hasWarnings = Boolean(result && result.diagnostics.length > 0);

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal">Doctor</h1>
          <p className="mt-1 text-sm text-muted-foreground">Run brew doctor and review diagnostics without leaving Brewwery.</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="secondary" disabled={!result?.rawOutput} onClick={() => result?.rawOutput && copy(result.rawOutput)}>
            <Clipboard className="h-4 w-4" />
            Copy diagnostics
          </Button>
          <Button variant="primary" disabled={loading} onClick={() => void runDoctor()}>
            <Stethoscope className="h-4 w-4" />
            Run Doctor
          </Button>
        </div>
      </div>

      {loading ? <StatePanel kind="loading" title="Running brew doctor..." /> : null}
      {!loading && error?.code === "HOMEBREW_NOT_FOUND" ? <HomebrewNotFound /> : null}
      {!loading && error && error.code !== "HOMEBREW_NOT_FOUND" ? (
        <StatePanel kind="error" title="Failed to run brew doctor" description={<ErrorDescription error={error} />} />
      ) : null}
      {!loading && !error && !result ? <StatePanel title="No doctor run yet" /> : null}
      {!loading && !error && result?.healthy ? (
        <StatePanel title="Your Homebrew installation looks healthy" description={result.rawOutput ? <RawOutput output={result.rawOutput} /> : undefined} />
      ) : null}

      {!loading && !error && result && hasWarnings ? (
        <div className="space-y-4">
          <Card>
            <CardContent className="flex items-center justify-between">
              <div>
                <div className="text-sm text-muted-foreground">Health status</div>
                <div className="mt-1 text-xl font-semibold">Warnings found</div>
              </div>
              <Badge className="border-amber-500/25 bg-amber-500/10 text-accent">{result.diagnostics.length} diagnostics</Badge>
            </CardContent>
          </Card>

          <div className="space-y-3">
            {result.diagnostics.map((diagnostic, index) => (
              <DiagnosticCard key={`${diagnostic.title}:${index}`} diagnostic={diagnostic} />
            ))}
          </div>

          {result.rawOutput ? <RawOutput output={result.rawOutput} /> : null}
        </div>
      ) : null}
    </section>
  );
}

function DiagnosticCard({ diagnostic }: { diagnostic: DoctorDiagnostic }) {
  return (
    <Card>
      <CardContent>
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-sm font-semibold">{diagnostic.title}</h2>
            {diagnostic.message ? <pre className="mt-2 whitespace-pre-wrap text-sm leading-6 text-muted-foreground">{diagnostic.message}</pre> : null}
          </div>
          <SeverityBadge severity={diagnostic.severity} />
        </div>
      </CardContent>
    </Card>
  );
}

function SeverityBadge({ severity }: { severity: DoctorDiagnostic["severity"] }) {
  return (
    <Badge
      className={cn(
        severity === "warning" && "border-amber-500/25 bg-amber-500/10 text-accent",
        severity === "error" && "border-red-500/25 bg-red-500/10 text-red-300",
        severity === "info" && "border-sky-500/25 bg-sky-500/10 text-sky-300"
      )}
    >
      {severity}
    </Badge>
  );
}

function RawOutput({ output }: { output: string }) {
  return (
    <details className="text-left">
      <summary className="cursor-pointer text-xs font-medium text-accent">Show raw output</summary>
      <pre className="mt-2 max-h-80 overflow-auto rounded-md border border-border bg-black/20 p-3 text-xs leading-5 text-muted-foreground">
        {output}
      </pre>
    </details>
  );
}

function copy(value: string) {
  void navigator.clipboard.writeText(value);
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

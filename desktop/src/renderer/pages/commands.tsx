import { ArrowUpRight, BookOpen, Check, Clipboard, Terminal } from "lucide-react";
import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { api } from "@/lib/api";
import { brewCommandSections, documentationLinks, type BrewCommandEntry } from "@/lib/brew-commands";

export function CommandsPage() {
  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">Commands</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          A reference of common Homebrew commands. Brewwery runs the same logic for you — nothing here is hidden.
        </p>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-2">
            <BookOpen className="h-4 w-4 text-accent" />
            <h2 className="text-sm font-semibold">Documentation</h2>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {documentationLinks.map((link) => (
              <button
                key={link.url}
                type="button"
                className="group flex flex-col gap-1 rounded-lg border border-border bg-[var(--brewwery-pre)] p-3 text-left transition-colors hover:bg-[var(--brewwery-card-hover)]"
                onClick={() => void api.system.openExternal(link.url)}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-sm font-medium text-foreground">{link.label}</span>
                  <ArrowUpRight className="h-3.5 w-3.5 text-muted-foreground transition-colors group-hover:text-accent" />
                </div>
                <span className="text-xs leading-5 text-muted-foreground">{link.description}</span>
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {brewCommandSections.map((section) => (
          <Card key={section.id}>
            <CardHeader>
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <Terminal className="h-4 w-4 text-accent" />
                    <h2 className="text-sm font-semibold">{section.title}</h2>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">{section.description}</p>
                </div>
                <Badge>{section.commands.length}</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {section.commands.map((command) => (
                  <CommandRow key={command.command} command={command} />
                ))}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
}

function CommandRow({ command }: { command: BrewCommandEntry }) {
  const [copied, setCopied] = useState(false);

  const copy = () => {
    void navigator.clipboard.writeText(command.command);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="flex items-center justify-between gap-3 rounded-md border border-border bg-[var(--brewwery-pre)] p-3">
      <div className="min-w-0">
        <code className="block truncate font-mono text-sm text-accent">{command.command}</code>
        <p className="mt-1 text-xs leading-5 text-muted-foreground">{command.description}</p>
      </div>
      <Button variant="secondary" className="h-8 shrink-0" aria-label={`Copy command: ${command.command}`} onClick={copy}>
        {copied ? <Check className="h-4 w-4 text-[var(--brewwery-success)]" /> : <Clipboard className="h-4 w-4" />}
        {copied ? "Copied" : "Copy"}
      </Button>
    </div>
  );
}

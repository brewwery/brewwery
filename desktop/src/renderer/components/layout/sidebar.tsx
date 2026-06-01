import { Activity, Archive, Boxes, Download, FileText, Gauge, History, Package, Settings, Sparkles, Stethoscope } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";
import { useSystem } from "@/hooks/use-system";
import { type PageId, useUiStore } from "@/stores/ui-store";
import logotype from "../../../../assets/brewwery-logotype.svg?asset";

const sections: Array<{ title: string; items: Array<{ id: PageId; label: string; icon: LucideIcon }> }> = [
  {
    title: "Library",
    items: [
      { id: "dashboard", label: "Dashboard", icon: Gauge },
      { id: "packages", label: "Packages", icon: Package },
      { id: "updates", label: "Updates", icon: Download },
      { id: "casks", label: "Casks", icon: Archive }
    ]
  },
  {
    title: "System",
    items: [
      { id: "services", label: "Services", icon: Activity },
      { id: "cleanup", label: "Cleanup", icon: Sparkles },
      { id: "doctor", label: "Doctor", icon: Stethoscope },
      { id: "brewfile", label: "Brewfile", icon: FileText }
    ]
  },
  {
    title: "App",
    items: [
      { id: "history", label: "History", icon: History },
      { id: "settings", label: "Settings", icon: Settings }
    ]
  }
];

export function Sidebar() {
  const activePage = useUiStore((state) => state.activePage);
  const setActivePage = useUiStore((state) => state.setActivePage);
  const { detection, system, loading } = useSystem();

  return (
    <aside className="row-span-2 flex min-h-0 flex-col bg-[#0f1115] p-4">
      <div className="mb-7 flex h-16 items-center pt-2">
        <img className="h-12 w-auto max-w-[210px]" src={logotype} alt="Brewwery" />
      </div>

      <nav className="flex-1 space-y-5">
        {sections.map((section) => (
          <div key={section.title}>
            <div className="mb-2 px-2 text-[11px] font-semibold uppercase tracking-[0.08em] text-muted-foreground">
              {section.title}
            </div>
            <div className="space-y-1">
              {section.items.map((item) => {
                const Icon = item.icon;
                const active = activePage === item.id;
                return (
                  <button
                    key={item.id}
                    className={cn(
                      "flex h-9 w-full items-center gap-3 rounded-md px-2 text-sm transition-colors",
                      active ? "bg-amber-500/12 text-accent" : "text-muted-foreground hover:bg-white/[0.05] hover:text-foreground"
                    )}
                    onClick={() => setActivePage(item.id)}
                  >
                    <Icon className="h-4 w-4" />
                    {item.label}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      <div className="rounded-lg border border-border bg-white/[0.035] p-3 text-xs">
        <div className="mb-1 flex items-center gap-2 font-medium text-foreground">
          <Boxes className="h-3.5 w-3.5 text-accent" />
          Homebrew
        </div>
        <div className="text-muted-foreground">{loading ? "Loading Homebrew..." : system?.version ?? "Homebrew not found"}</div>
        <div className={cn("mt-2", detection?.found ? "text-emerald-400" : "text-amber-400")}>
          {detection?.found ? "Detected" : "Not detected"}
        </div>
      </div>
    </aside>
  );
}

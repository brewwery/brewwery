import type { PropsWithChildren } from "react";
import { Sidebar } from "./sidebar";
import { StatusBar } from "./status-bar";
import { Titlebar } from "./titlebar";
import { ToastViewport } from "@/components/ui/toast-viewport";

export function AppShell({ children }: PropsWithChildren) {
  return (
    <div className="grid h-screen grid-cols-[260px_1fr] grid-rows-[48px_1fr_34px] overflow-hidden bg-background text-foreground">
      <Titlebar />
      <Sidebar />
      <main className="overflow-hidden border-l border-border bg-[var(--brewwery-app-panel)]">
        <div className="h-full overflow-auto p-6">{children}</div>
      </main>
      <StatusBar />
      <ToastViewport />
    </div>
  );
}

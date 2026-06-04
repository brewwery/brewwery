import { Search, Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useUiStore } from "@/stores/ui-store";

export function Titlebar() {
  const setActivePage = useUiStore((state) => state.setActivePage);
  const searchQuery = useUiStore((state) => state.searchQuery);
  const setSearchQuery = useUiStore((state) => state.setSearchQuery);

  return (
    <header className="col-span-2 grid grid-cols-[260px_1fr_auto] items-center border-b border-border bg-[#101216] pl-24 pr-4 [-webkit-app-region:drag]">
      <div className="text-sm font-semibold tracking-normal text-foreground">Brewwery</div>
      <div className="relative max-w-md [-webkit-app-region:no-drag]">
        <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
        <Input
          className="w-full pl-9"
          placeholder="Search Homebrew..."
          value={searchQuery}
          onChange={(event) => {
            setSearchQuery(event.target.value);
            setActivePage("search");
          }}
          onFocus={() => setActivePage("search")}
        />
      </div>
      <Button className="[-webkit-app-region:no-drag]" variant="ghost" onClick={() => setActivePage("settings")} aria-label="Settings">
        <Settings className="h-4 w-4" />
      </Button>
    </header>
  );
}

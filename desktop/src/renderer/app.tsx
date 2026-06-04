import { useEffect, useState } from "react";
import { AppShell } from "./components/layout/app-shell";
import { FirstLaunchOnboarding } from "./components/onboarding/first-launch-onboarding";
import { BrewfilePage } from "./pages/brewfile";
import { CasksPage } from "./pages/casks";
import { CleanupPage } from "./pages/cleanup";
import { DashboardPage } from "./pages/dashboard";
import { DoctorPage } from "./pages/doctor";
import { HistoryPage } from "./pages/history";
import { PackagesPage } from "./pages/packages";
import { SearchPage } from "./pages/search";
import { ServicesPage } from "./pages/services";
import { SettingsPage } from "./pages/settings";
import { UpdatesPage } from "./pages/updates";
import { api } from "./lib/api";
import { useSettingsStore } from "./stores/settings-store";
import { useUiStore } from "./stores/ui-store";

const pages = {
  dashboard: <DashboardPage />,
  search: <SearchPage />,
  packages: <PackagesPage />,
  updates: <UpdatesPage />,
  casks: <CasksPage />,
  services: <ServicesPage />,
  cleanup: <CleanupPage />,
  doctor: <DoctorPage />,
  brewfile: <BrewfilePage />,
  history: <HistoryPage />,
  settings: <SettingsPage />
};

export function App() {
  const activePage = useUiStore((state) => state.activePage);
  const setActivePage = useUiStore((state) => state.setActivePage);
  const setSearchQuery = useUiStore((state) => state.setSearchQuery);
  const firstLaunchComplete = useSettingsStore((state) => state.firstLaunchComplete);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    return api.app.onShortcut((shortcut) => {
      if (shortcut === "search") {
        setActivePage("search");
        setSearchQuery("");
        return;
      }
      if (shortcut === "settings") {
        setActivePage("settings");
        return;
      }
      if (shortcut === "updates") {
        setActivePage("updates");
        return;
      }
      if (shortcut === "doctor") {
        setActivePage("doctor");
        return;
      }
      if (shortcut === "refresh") {
        setRefreshKey((value) => value + 1);
      }
    });
  }, [setActivePage, setSearchQuery]);

  return (
    <AppShell>
      <div key={`${activePage}:${refreshKey}`}>{pages[activePage]}</div>
      {!firstLaunchComplete ? <FirstLaunchOnboarding /> : null}
    </AppShell>
  );
}

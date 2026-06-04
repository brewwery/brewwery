import { AppShell } from "./components/layout/app-shell";
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
  return <AppShell>{pages[activePage]}</AppShell>;
}

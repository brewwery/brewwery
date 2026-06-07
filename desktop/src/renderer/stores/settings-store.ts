import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SettingsState {
  firstLaunchComplete: boolean;
  theme: "system" | "dark" | "light";
  showPrereleaseUpdates: boolean;
  customHomebrewPath: string;
  completeFirstLaunch: () => void;
  setTheme: (theme: SettingsState["theme"]) => void;
  setShowPrereleaseUpdates: (value: boolean) => void;
  setCustomHomebrewPath: (value: string) => void;
  resetCustomHomebrewPath: () => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      firstLaunchComplete: false,
      theme: "dark",
      showPrereleaseUpdates: false,
      customHomebrewPath: "",
      completeFirstLaunch: () => set({ firstLaunchComplete: true }),
      setTheme: (theme) => set({ theme }),
      setShowPrereleaseUpdates: (showPrereleaseUpdates) => set({ showPrereleaseUpdates }),
      setCustomHomebrewPath: (customHomebrewPath) => set({ customHomebrewPath }),
      resetCustomHomebrewPath: () => set({ customHomebrewPath: "" })
    }),
    {
      name: "brewwery-settings",
      version: 2
    }
  )
);

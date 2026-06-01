import { create } from "zustand";

interface SettingsState {
  showPrereleaseUpdates: boolean;
  setShowPrereleaseUpdates: (value: boolean) => void;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  showPrereleaseUpdates: false,
  setShowPrereleaseUpdates: (showPrereleaseUpdates) => set({ showPrereleaseUpdates })
}));

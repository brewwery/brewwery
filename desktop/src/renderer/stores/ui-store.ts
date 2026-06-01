import { create } from "zustand";

export type PageId =
  | "dashboard"
  | "packages"
  | "updates"
  | "casks"
  | "services"
  | "cleanup"
  | "doctor"
  | "brewfile"
  | "history"
  | "settings";

interface UiState {
  activePage: PageId;
  setActivePage: (page: PageId) => void;
}

export const useUiStore = create<UiState>((set) => ({
  activePage: "dashboard",
  setActivePage: (page) => set({ activePage: page })
}));

import { create } from "zustand";

export type PageId =
  | "dashboard"
  | "discover"
  | "search"
  | "favorites"
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
  searchQuery: string;
  setActivePage: (page: PageId) => void;
  setSearchQuery: (query: string) => void;
}

export const useUiStore = create<UiState>((set) => ({
  activePage: "dashboard",
  searchQuery: "",
  setActivePage: (page) => set({ activePage: page }),
  setSearchQuery: (query) => set({ searchQuery: query })
}));

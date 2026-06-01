import { create } from "zustand";
import type { Cask, Formula } from "@brewwery/shared-types";

interface PackageState {
  formulae: Formula[];
  casks: Cask[];
  setFormulae: (formulae: Formula[]) => void;
  setCasks: (casks: Cask[]) => void;
}

export const usePackageStore = create<PackageState>((set) => ({
  formulae: [],
  casks: [],
  setFormulae: (formulae) => set({ formulae }),
  setCasks: (casks) => set({ casks })
}));

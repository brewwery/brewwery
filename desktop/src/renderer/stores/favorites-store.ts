import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { FavoritePackage, PackageKind } from "@brewwery/shared-types";

interface FavoritesState {
  favorites: FavoritePackage[];
  addFavorite: (name: string, kind: PackageKind) => void;
  removeFavorite: (name: string, kind: PackageKind) => void;
  toggleFavorite: (name: string, kind: PackageKind) => void;
  isFavorite: (name: string, kind: PackageKind) => boolean;
  clearFavorites: () => void;
}

export function favoriteKey(name: string, kind: PackageKind) {
  return `${kind}:${name.toLowerCase().trim()}`;
}

export function isFavoritePackage(favorites: FavoritePackage[], name: string, kind: PackageKind) {
  return favorites.some((favorite) => favoriteKey(favorite.name, favorite.kind) === favoriteKey(name, kind));
}

export const useFavoritesStore = create<FavoritesState>()(
  persist(
    (set, get) => ({
      favorites: [],
      addFavorite: (name, kind) =>
        set((state) => {
          const normalizedName = name.trim();
          const key = favoriteKey(normalizedName, kind);
          if (!normalizedName || state.favorites.some((favorite) => favoriteKey(favorite.name, favorite.kind) === key)) {
            return state;
          }

          return {
            favorites: [
              ...state.favorites,
              {
                name: normalizedName,
                kind,
                addedAt: new Date().toISOString()
              }
            ]
          };
        }),
      removeFavorite: (name, kind) =>
        set((state) => ({
          favorites: state.favorites.filter((favorite) => favoriteKey(favorite.name, favorite.kind) !== favoriteKey(name, kind))
        })),
      toggleFavorite: (name, kind) => {
        if (get().isFavorite(name, kind)) {
          get().removeFavorite(name, kind);
        } else {
          get().addFavorite(name, kind);
        }
      },
      isFavorite: (name, kind) => isFavoritePackage(get().favorites, name, kind),
      clearFavorites: () => set({ favorites: [] })
    }),
    {
      name: "brewwery-favorites",
      version: 1
    }
  )
);

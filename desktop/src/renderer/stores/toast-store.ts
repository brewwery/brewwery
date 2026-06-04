import { create } from "zustand";

export type ToastTone = "success" | "error" | "info";

export interface ToastEntry {
  id: string;
  title: string;
  description?: string;
  tone: ToastTone;
}

interface ToastState {
  toasts: ToastEntry[];
  showToast: (toast: Omit<ToastEntry, "id">) => void;
  dismissToast: (id: string) => void;
}

export const useToastStore = create<ToastState>((set) => ({
  toasts: [],
  showToast: (toast) => {
    const id = createId();
    set((state) => ({
      toasts: [{ id, ...toast }, ...state.toasts].slice(0, 3)
    }));
    window.setTimeout(() => {
      set((state) => ({
        toasts: state.toasts.filter((item) => item.id !== id)
      }));
    }, 4200);
  },
  dismissToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((item) => item.id !== id)
    }))
}));

function createId() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

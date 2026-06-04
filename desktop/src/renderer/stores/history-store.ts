import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { IpcError } from "@brewwery/shared-types";
import { useToastStore } from "./toast-store";

export type OperationKind = "upgrade" | "service" | "cleanup" | "doctor" | "brewfile_export";
export type OperationStatus = "success" | "failed";

export interface OperationLogEntry {
  id: string;
  kind: OperationKind;
  status: OperationStatus;
  title: string;
  command?: string;
  target?: string;
  timestamp: string;
  stdout?: string;
  stderr?: string;
  details?: string;
  error?: IpcError;
}

type OperationLogInput = Omit<OperationLogEntry, "id" | "timestamp"> & {
  timestamp?: string;
};

interface HistoryState {
  entries: OperationLogEntry[];
  addEntry: (entry: OperationLogInput) => void;
  clearEntries: () => void;
}

const maxEntries = 100;

export const useHistoryStore = create<HistoryState>()(
  persist(
    (set) => ({
      entries: [],
      addEntry: (entry) => {
        set((state) => ({
          entries: [
            {
              id: createId(),
              timestamp: entry.timestamp ?? new Date().toISOString(),
              ...entry
            },
            ...state.entries
          ].slice(0, maxEntries)
        }));
        useToastStore.getState().showToast({
          tone: entry.status === "success" ? "success" : "error",
          title: entry.title,
          description: entry.command
        });
      },
      clearEntries: () => set({ entries: [] })
    }),
    {
      name: "brewwery-operation-history",
      version: 1
    }
  )
);

function createId() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

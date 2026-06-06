import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { IpcError } from "@brewwery/shared-types";
import { useToastStore } from "./toast-store";

export type OperationKind = "install" | "uninstall" | "upgrade" | "brew_update" | "service" | "cleanup" | "doctor" | "brewfile_export";
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
const maxOutputChars = 20_000;

export const useHistoryStore = create<HistoryState>()(
  persist(
    (set) => ({
      entries: [],
      addEntry: (entry) => {
        const safeEntry = compactEntry(entry);
        set((state) => ({
          entries: [
            {
              id: createId(),
              timestamp: safeEntry.timestamp ?? new Date().toISOString(),
              ...safeEntry
            },
            ...state.entries
          ].slice(0, maxEntries)
        }));
        useToastStore.getState().showToast({
          tone: safeEntry.status === "success" ? "success" : "error",
          title: safeEntry.title,
          description: safeEntry.command
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

function compactEntry(entry: OperationLogInput): OperationLogInput {
  return {
    ...entry,
    stdout: compactOutput(entry.stdout),
    stderr: compactOutput(entry.stderr),
    details: compactOutput(entry.details),
    error: entry.error
      ? {
          ...entry.error,
          raw: compactOutput(entry.error.raw)
        }
      : undefined
  };
}

function compactOutput(value?: string) {
  if (!value || value.length <= maxOutputChars) return value;
  const head = value.slice(0, Math.floor(maxOutputChars * 0.65));
  const tail = value.slice(-Math.floor(maxOutputChars * 0.25));
  return `${head}\n\n[Brewwery trimmed ${value.length - head.length - tail.length} characters to keep History fast.]\n\n${tail}`;
}

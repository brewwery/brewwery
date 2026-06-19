import { useCallback, useEffect, useRef, useState } from "react";
import type { IpcError, ProgressEvent, ProgressOperationKind, ProgressOperationStart } from "@brewwery/shared-types";
import { api } from "@/lib/api";

export interface OperationProgressLine {
  stream: "stdout" | "stderr";
  text: string;
  timestamp: string;
}

export interface OperationProgressState {
  operationId: string;
  kind: ProgressOperationKind;
  command: string;
  target?: string;
  status: "running" | "success" | "failed";
  stdout: string;
  stderr: string;
  lines: OperationProgressLine[];
  error?: IpcError;
}

const MAX_LIVE_OUTPUT_CHARS = 120_000;
const OUTPUT_TRIM_MARKER = "\n\n[Brewwery trimmed earlier live output.]\n\n";

export function useProgressOperation() {
  const [progress, setProgress] = useState<OperationProgressState | undefined>();
  const resolvers = useRef(new Map<string, (event: ProgressEvent) => void>());

  useEffect(() => {
    return api.progress.onEvent((event) => {
      setProgress((current) => reduceProgress(current, event));

      if (event.type === "completed" || event.type === "failed") {
        const resolve = resolvers.current.get(event.operationId);
        if (resolve) {
          resolvers.current.delete(event.operationId);
          resolve(event);
        }
      }
    });
  }, []);

  const track = useCallback((start: ProgressOperationStart) => {
    setProgress({
      operationId: start.operationId,
      kind: start.kind,
      command: start.command,
      target: start.target,
      status: "running",
      stdout: "",
      stderr: "",
      lines: []
    });
  }, []);

  const waitForCompletion = useCallback(
    (operationId: string) =>
      new Promise<ProgressEvent>((resolve) => {
        resolvers.current.set(operationId, resolve);
      }),
    []
  );

  const clear = useCallback(() => setProgress(undefined), []);

  return { progress, track, waitForCompletion, clear };
}

function reduceProgress(current: OperationProgressState | undefined, event: ProgressEvent): OperationProgressState {
  const base =
    current?.operationId === event.operationId
      ? current
      : {
          operationId: event.operationId,
          kind: event.kind,
          command: event.command,
          target: event.target,
          status: "running" as const,
          stdout: "",
          stderr: "",
          lines: []
        };

  if (event.type === "stdout" || event.type === "stderr") {
    const chunk = event.chunk ?? "";
    return {
      ...base,
      stdout: event.type === "stdout" ? appendBoundedOutput(base.stdout, chunk) : base.stdout,
      stderr: event.type === "stderr" ? appendBoundedOutput(base.stderr, chunk) : base.stderr,
      lines: [...base.lines, { stream: event.type, text: compactChunk(chunk), timestamp: event.timestamp }].slice(-80)
    };
  }

  if (event.type === "completed") {
    return {
      ...base,
      status: "success",
      stdout: event.stdout ?? base.stdout,
      stderr: event.stderr ?? base.stderr
    };
  }

  if (event.type === "failed") {
    return {
      ...base,
      status: "failed",
      stdout: event.stdout ?? base.stdout,
      stderr: event.stderr ?? base.stderr,
      error: event.error
    };
  }

  return base;
}

function compactChunk(chunk: string) {
  const max = 4_000;
  if (chunk.length <= max) return chunk;
  return `${chunk.slice(0, max)}\n[Brewwery trimmed ${chunk.length - max} characters from this live output chunk.]`;
}

function appendBoundedOutput(current: string, chunk: string) {
  const combined = current + chunk;
  if (combined.length <= MAX_LIVE_OUTPUT_CHARS) return combined;

  const headLength = Math.floor(MAX_LIVE_OUTPUT_CHARS * 0.35);
  const tailLength = MAX_LIVE_OUTPUT_CHARS - headLength - OUTPUT_TRIM_MARKER.length;
  return `${combined.slice(0, headLength)}${OUTPUT_TRIM_MARKER}${combined.slice(-tailLength)}`;
}

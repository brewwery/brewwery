export interface CleanupCandidate {
  path: string;
  sizeBytes?: number;
  kind: "cache" | "download" | "old-version" | "unknown";
}

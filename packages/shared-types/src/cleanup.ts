export interface CleanupPreview {
  items: CleanupItem[];
  totalSize?: string;
  rawOutput?: string;
}

export interface CleanupItem {
  name?: string;
  path?: string;
  size?: string;
  kind?: "cache" | "old_version" | "download" | "unknown";
}

export interface CleanupResult {
  success: boolean;
  removedItems?: number;
  freedSpace?: string;
  stdout?: string;
  stderr?: string;
}

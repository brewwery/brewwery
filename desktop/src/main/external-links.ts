/**
 * Allowlist for external links the app is permitted to open.
 *
 * Brewwery deliberately avoids a generic "open any URL" capability. Only the
 * URLs that match an entry below can be opened, and only over HTTPS. This keeps
 * the renderer from being able to launch arbitrary external targets.
 */
interface AllowedTarget {
  /** Exact hostname match (no wildcards). */
  host: string;
  /** Optional path prefix the URL must start with. */
  pathPrefix?: string;
}

const ALLOWED_TARGETS: AllowedTarget[] = [
  { host: "www.brewwery.com" },
  { host: "brewwery.com" },
  { host: "docs.brewwery.com" },
  { host: "brew.sh" },
  { host: "docs.brew.sh" },
  // Only the Brewwery repository on GitHub, not all of github.com.
  { host: "github.com", pathPrefix: "/brewwery/brewwery" }
];

export function isAllowedExternalUrl(rawUrl: string): boolean {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    return false;
  }

  if (url.protocol !== "https:") {
    return false;
  }

  return ALLOWED_TARGETS.some((target) => {
    if (url.hostname !== target.host) {
      return false;
    }
    if (!target.pathPrefix) {
      return true;
    }
    return url.pathname === target.pathPrefix || url.pathname.startsWith(`${target.pathPrefix}/`);
  });
}

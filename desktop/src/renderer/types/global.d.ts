import type { BrewweryApi } from "@brewwery/shared-types";

declare global {
  interface Window {
    brewwery: BrewweryApi;
  }
}

export {};

export interface BrewTap {
  name: string;
  official: boolean;
}

export interface TapActionRequest {
  name: string;
}

export interface TapActionResult {
  name: string;
  action: "tap" | "untap";
  success: boolean;
  stdout?: string;
  stderr?: string;
}

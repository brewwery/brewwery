export interface BrewService {
  name: string;
  status: "started" | "stopped" | "unknown";
  user?: string;
  file?: string;
}

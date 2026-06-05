import { rmSync } from "node:fs";
import { join } from "node:path";

const home = process.env.HOME;

const targets = [
  join(process.cwd(), "desktop/dist-packages/mac-arm64/Brewwery.app"),
  "/Applications/Brewwery.app"
];

if (home) {
  targets.push(
    join(home, "Applications/Brewwery.app"),
    join(home, "Library/Application Support/Brewwery"),
    join(home, "Library/Preferences/com.brewwery.app.plist"),
    join(home, "Library/Saved Application State/com.brewwery.app.savedState")
  );
}

for (const target of targets) {
  rmSync(target, { recursive: true, force: true });
  console.log(`removed ${target}`);
}

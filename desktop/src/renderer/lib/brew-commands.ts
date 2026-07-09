export interface BrewCommandEntry {
  command: string;
  description: string;
}

export interface BrewCommandSection {
  id: string;
  title: string;
  description: string;
  commands: BrewCommandEntry[];
}

/**
 * A read-only reference of common Homebrew commands. Brewwery runs equivalents
 * of these through validated, typed channels — this list keeps the underlying
 * terminal logic visible rather than hidden.
 */
export const brewCommandSections: BrewCommandSection[] = [
  {
    id: "packages",
    title: "Packages",
    description: "Install, inspect, and remove command-line formulae.",
    commands: [
      { command: "brew install git", description: "Install a command-line formula." },
      { command: "brew uninstall git", description: "Remove an installed formula." },
      { command: "brew list", description: "List installed formulae." },
      { command: "brew info redis", description: "Show details, dependencies, and caveats for a formula." }
    ]
  },
  {
    id: "casks",
    title: "Casks",
    description: "Install and manage macOS applications.",
    commands: [
      { command: "brew install --cask visual-studio-code", description: "Install a macOS application distributed as a cask." },
      { command: "brew uninstall --cask visual-studio-code", description: "Remove an installed cask." },
      { command: "brew list --cask", description: "List installed casks." },
      { command: "brew info --cask visual-studio-code", description: "Show details for a cask." }
    ]
  },
  {
    id: "updates",
    title: "Updates",
    description: "Refresh metadata and upgrade installed packages.",
    commands: [
      { command: "brew update", description: "Fetch the latest package metadata from Homebrew." },
      { command: "brew outdated", description: "List installed packages that have newer versions." },
      { command: "brew upgrade", description: "Upgrade all outdated formulae and casks." },
      { command: "brew upgrade redis", description: "Upgrade a single package." }
    ]
  },
  {
    id: "services",
    title: "Services",
    description: "Manage background processes like databases.",
    commands: [
      { command: "brew services list", description: "Show the status of all managed services." },
      { command: "brew services start redis", description: "Start a service and launch it at login." },
      { command: "brew services stop redis", description: "Stop a running service." },
      { command: "brew services restart postgresql@16", description: "Restart a service." }
    ]
  },
  {
    id: "cleanup",
    title: "Cleanup",
    description: "Reclaim disk space from old versions and caches.",
    commands: [
      { command: "brew cleanup -n", description: "Preview what Homebrew can remove without deleting anything." },
      { command: "brew cleanup", description: "Remove old versions and stale downloads." }
    ]
  },
  {
    id: "doctor",
    title: "Doctor",
    description: "Check the health of your Homebrew installation.",
    commands: [{ command: "brew doctor", description: "Report common problems. It only diagnoses — it changes nothing." }]
  },
  {
    id: "brewfile",
    title: "Brewfile",
    description: "Describe and reproduce your setup as a file.",
    commands: [
      { command: "brew bundle dump", description: "Write your current setup to a Brewfile." },
      { command: "brew bundle install", description: "Install everything listed in a Brewfile." }
    ]
  }
];

export interface DocumentationLink {
  label: string;
  description: string;
  url: string;
}

/**
 * Documentation targets. Every URL here must also pass the main-process
 * allowlist in src/main/external-links.ts — there is no generic "open any URL".
 */
export const documentationLinks: DocumentationLink[] = [
  { label: "Getting Started", description: "Set up Brewwery and connect your Homebrew install.", url: "https://docs.brewwery.com/getting-started" },
  { label: "Brew Commands", description: "The full Homebrew command reference.", url: "https://docs.brewwery.com/brew-commands" },
  { label: "What is Homebrew?", description: "A plain-English guide to the macOS package manager.", url: "https://docs.brewwery.com/what-is-homebrew" },
  { label: "Security Model", description: "How Brewwery runs commands safely and locally.", url: "https://docs.brewwery.com/security" },
  { label: "Troubleshooting", description: "Fixes for common Homebrew and Brewwery issues.", url: "https://docs.brewwery.com/troubleshooting" },
  { label: "Report Issue", description: "Open a bug report on GitHub.", url: "https://github.com/brewwery/brewwery/issues/new" }
];

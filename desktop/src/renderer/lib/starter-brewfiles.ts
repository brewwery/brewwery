export interface StarterBrewfile {
  id: string;
  title: string;
  description: string;
  content: string;
}

/**
 * Local, open-source starter Brewfiles. These are plain templates a user can
 * copy and adapt — Brewwery does not install them automatically or push them to
 * any device.
 */
export const starterBrewfiles: StarterBrewfile[] = [
  {
    id: "backend",
    title: "Backend Developer",
    description: "Runtimes, a database, and container tooling for backend work.",
    content: [
      'tap "homebrew/services"',
      'brew "git"',
      'brew "node"',
      'brew "go"',
      'brew "postgresql@16"',
      'brew "redis"',
      'brew "httpie"',
      'cask "docker"',
      'cask "visual-studio-code"'
    ].join("\n")
  },
  {
    id: "frontend",
    title: "Frontend Developer",
    description: "Modern JavaScript tooling, a browser, and a design app.",
    content: [
      'brew "git"',
      'brew "node"',
      'brew "pnpm"',
      'brew "deno"',
      'cask "visual-studio-code"',
      'cask "google-chrome"',
      'cask "figma"'
    ].join("\n")
  },
  {
    id: "python",
    title: "Python Developer",
    description: "A Python toolchain with version and environment management.",
    content: [
      'brew "git"',
      'brew "python@3.13"',
      'brew "pyenv"',
      'brew "pipx"',
      'brew "ruff"',
      'cask "visual-studio-code"'
    ].join("\n")
  },
  {
    id: "ai-ml",
    title: "AI / ML Developer",
    description: "Local model runtimes and notebooks for AI and ML work.",
    content: [
      'brew "git"',
      'brew "python@3.13"',
      'brew "ollama"',
      'brew "llm"',
      'brew "jupyterlab"',
      'cask "lm-studio"'
    ].join("\n")
  },
  {
    id: "macos-productivity",
    title: "macOS Productivity",
    description: "Launchers, window management, and note-taking for daily use.",
    content: [
      'brew "mas"',
      'cask "raycast"',
      'cask "rectangle"',
      'cask "obsidian"',
      'cask "notion"'
    ].join("\n")
  }
];

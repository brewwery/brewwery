import type { PackageKind } from "@brewwery/shared-types";

export interface DiscoverItem {
  name: string;
  kind: PackageKind;
  description?: string;
}

export interface DiscoverCollection {
  id: string;
  title: string;
  description: string;
  items: DiscoverItem[];
}

export const discoverCollections: DiscoverCollection[] = [
  {
    id: "essential-cli",
    title: "Essential CLI",
    description: "Useful command-line tools for everyday development.",
    items: [
      { name: "git", kind: "formula", description: "Distributed version control system." },
      { name: "wget", kind: "formula", description: "Internet file retriever." },
      { name: "jq", kind: "formula", description: "Lightweight JSON processor." },
      { name: "ripgrep", kind: "formula", description: "Fast recursive search tool." },
      { name: "fd", kind: "formula", description: "Simple, fast alternative to find." },
      { name: "bat", kind: "formula", description: "Cat clone with syntax highlighting." },
      { name: "fzf", kind: "formula", description: "Command-line fuzzy finder." }
    ]
  },
  {
    id: "development",
    title: "Development",
    description: "Build tools and developer workflow essentials.",
    items: [
      { name: "gh", kind: "formula", description: "GitHub command-line tool." },
      { name: "git-lfs", kind: "formula", description: "Git extension for large files." },
      { name: "cmake", kind: "formula", description: "Cross-platform build system." },
      { name: "mas", kind: "formula", description: "Mac App Store command-line interface." },
      { name: "visual-studio-code", kind: "cask", description: "Code editor from Microsoft." },
      { name: "iterm2", kind: "cask", description: "Terminal emulator for macOS." }
    ]
  },
  {
    id: "languages",
    title: "Languages",
    description: "Popular runtimes and language toolchains.",
    items: [
      { name: "node", kind: "formula", description: "JavaScript runtime." },
      { name: "python@3.13", kind: "formula", description: "Python programming language." },
      { name: "go", kind: "formula", description: "Go programming language." },
      { name: "rust", kind: "formula", description: "Rust toolchain." },
      { name: "php", kind: "formula", description: "PHP scripting language." },
      { name: "ruby", kind: "formula", description: "Ruby programming language." }
    ]
  },
  {
    id: "backend",
    title: "Backend",
    description: "Tools and runtimes for building and running backend services.",
    items: [
      { name: "node", kind: "formula", description: "JavaScript runtime." },
      { name: "go", kind: "formula", description: "Go programming language." },
      { name: "redis", kind: "formula", description: "In-memory data structure store." },
      { name: "postgresql@16", kind: "formula", description: "Object-relational database system." },
      { name: "docker", kind: "cask", description: "Container runtime and tooling." },
      { name: "httpie", kind: "formula", description: "Friendly command-line HTTP client." }
    ]
  },
  {
    id: "frontend",
    title: "Frontend",
    description: "Essentials for modern frontend and web development.",
    items: [
      { name: "node", kind: "formula", description: "JavaScript runtime." },
      { name: "pnpm", kind: "formula", description: "Fast, disk-efficient package manager." },
      { name: "deno", kind: "formula", description: "Secure runtime for JavaScript and TypeScript." },
      { name: "visual-studio-code", kind: "cask", description: "Code editor from Microsoft." },
      { name: "google-chrome", kind: "cask", description: "Browser with developer tools." },
      { name: "figma", kind: "cask", description: "Collaborative interface design tool." }
    ]
  },
  {
    id: "databases",
    title: "Databases",
    description: "Popular local databases and data tools.",
    items: [
      { name: "postgresql@16", kind: "formula", description: "Object-relational database system." },
      { name: "mysql", kind: "formula", description: "Open-source relational database." },
      { name: "redis", kind: "formula", description: "In-memory data structure store." },
      { name: "sqlite", kind: "formula", description: "Lightweight SQL database engine." },
      { name: "mongodb-community", kind: "formula", description: "MongoDB community server." }
    ]
  },
  {
    id: "ai-tools",
    title: "AI Tools",
    description: "Command-line tools and apps for working with AI models.",
    items: [
      { name: "ollama", kind: "formula", description: "Run large language models locally." },
      { name: "llm", kind: "formula", description: "CLI for interacting with language models." },
      { name: "huggingface-cli", kind: "formula", description: "Hugging Face Hub command-line interface." },
      { name: "chatgpt", kind: "cask", description: "Official ChatGPT desktop app." },
      { name: "lm-studio", kind: "cask", description: "Discover and run local LLMs." }
    ]
  },
  {
    id: "productivity",
    title: "Productivity",
    description: "Small tools that make macOS workflows smoother.",
    items: [
      { name: "raycast", kind: "cask", description: "Launcher and productivity command center." },
      { name: "rectangle", kind: "cask", description: "Window management for macOS." },
      { name: "notion", kind: "cask", description: "Workspace notes and docs app." },
      { name: "obsidian", kind: "cask", description: "Local-first markdown notes app." }
    ]
  },
  {
    id: "browsers",
    title: "Browsers",
    description: "Common browsers available through Homebrew casks.",
    items: [
      { name: "google-chrome", kind: "cask", description: "Google Chrome browser." },
      { name: "firefox", kind: "cask", description: "Mozilla Firefox browser." },
      { name: "brave-browser", kind: "cask", description: "Privacy-focused Chromium browser." },
      { name: "arc", kind: "cask", description: "Modern browser for macOS." }
    ]
  },
  {
    id: "media",
    title: "Media",
    description: "Media playback, recording, and conversion tools.",
    items: [
      { name: "ffmpeg", kind: "formula", description: "Audio and video conversion toolkit." },
      { name: "yt-dlp", kind: "formula", description: "Video downloader." },
      { name: "vlc", kind: "cask", description: "Media player." },
      { name: "obs", kind: "cask", description: "Recording and streaming studio." }
    ]
  },
  {
    id: "security",
    title: "Security",
    description: "Security and privacy tools for local development.",
    items: [
      { name: "gnupg", kind: "formula", description: "GNU Privacy Guard." },
      { name: "openssl@3", kind: "formula", description: "Cryptography and SSL/TLS toolkit." },
      { name: "age", kind: "formula", description: "Simple file encryption tool." },
      { name: "wireshark", kind: "cask", description: "Network protocol analyzer." }
    ]
  },
  {
    id: "utilities",
    title: "Utilities",
    description: "Useful system and desktop utilities.",
    items: [
      { name: "tree", kind: "formula", description: "Display directories as trees." },
      { name: "htop", kind: "formula", description: "Interactive process viewer." },
      { name: "watch", kind: "formula", description: "Run commands repeatedly." },
      { name: "orbstack", kind: "cask", description: "Containers and Linux machines on macOS." },
      { name: "keepingyouawake", kind: "cask", description: "Prevent your Mac from sleeping." }
    ]
  }
];

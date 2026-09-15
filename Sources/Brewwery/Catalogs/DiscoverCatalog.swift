import BrewweryCore
import Foundation

/// `renderer/lib/discover.ts` — a local, bundled registry. Discover makes no network
/// request of its own; it only names packages the user can then inspect or install.
struct DiscoverItem: Identifiable, Hashable {
    let name: String
    let kind: PackageKind
    let description: String?

    var id: String { "\(kind.rawValue):\(name)" }
    var reference: PackageReference { PackageReference(name: name, kind: kind) }

    init(_ name: String, _ kind: PackageKind, _ description: String) {
        self.name = name
        self.kind = kind
        self.description = description
    }
}

struct DiscoverCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let items: [DiscoverItem]
}

enum DiscoverCatalog {
    static let collections: [DiscoverCollection] = [
        DiscoverCollection(
            id: "essential-cli",
            title: "Essential CLI",
            description: "Useful command-line tools for everyday development.",
            items: [
                DiscoverItem("git", .formula, "Distributed version control system."),
                DiscoverItem("wget", .formula, "Internet file retriever."),
                DiscoverItem("jq", .formula, "Lightweight JSON processor."),
                DiscoverItem("ripgrep", .formula, "Fast recursive search tool."),
                DiscoverItem("fd", .formula, "Simple, fast alternative to find."),
                DiscoverItem("bat", .formula, "Cat clone with syntax highlighting."),
                DiscoverItem("fzf", .formula, "Command-line fuzzy finder.")
            ]
        ),
        DiscoverCollection(
            id: "development",
            title: "Development",
            description: "Build tools and developer workflow essentials.",
            items: [
                DiscoverItem("gh", .formula, "GitHub command-line tool."),
                DiscoverItem("git-lfs", .formula, "Git extension for large files."),
                DiscoverItem("cmake", .formula, "Cross-platform build system."),
                DiscoverItem("mas", .formula, "Mac App Store command-line interface."),
                DiscoverItem("visual-studio-code", .cask, "Code editor from Microsoft."),
                DiscoverItem("iterm2", .cask, "Terminal emulator for macOS.")
            ]
        ),
        DiscoverCollection(
            id: "languages",
            title: "Languages",
            description: "Popular runtimes and language toolchains.",
            items: [
                DiscoverItem("node", .formula, "JavaScript runtime."),
                DiscoverItem("python@3.13", .formula, "Python programming language."),
                DiscoverItem("go", .formula, "Go programming language."),
                DiscoverItem("rust", .formula, "Rust toolchain."),
                DiscoverItem("php", .formula, "PHP scripting language."),
                DiscoverItem("ruby", .formula, "Ruby programming language.")
            ]
        ),
        DiscoverCollection(
            id: "backend",
            title: "Backend",
            description: "Tools and runtimes for building and running backend services.",
            items: [
                DiscoverItem("node", .formula, "JavaScript runtime."),
                DiscoverItem("go", .formula, "Go programming language."),
                DiscoverItem("redis", .formula, "In-memory data structure store."),
                DiscoverItem("postgresql@16", .formula, "Object-relational database system."),
                DiscoverItem("docker", .cask, "Container runtime and tooling."),
                DiscoverItem("httpie", .formula, "Friendly command-line HTTP client.")
            ]
        ),
        DiscoverCollection(
            id: "frontend",
            title: "Frontend",
            description: "Essentials for modern frontend and web development.",
            items: [
                DiscoverItem("node", .formula, "JavaScript runtime."),
                DiscoverItem("pnpm", .formula, "Fast, disk-efficient package manager."),
                DiscoverItem("deno", .formula, "Secure runtime for JavaScript and TypeScript."),
                DiscoverItem("visual-studio-code", .cask, "Code editor from Microsoft."),
                DiscoverItem("google-chrome", .cask, "Browser with developer tools."),
                DiscoverItem("figma", .cask, "Collaborative interface design tool.")
            ]
        ),
        DiscoverCollection(
            id: "databases",
            title: "Databases",
            description: "Popular local databases and data tools.",
            items: [
                DiscoverItem("postgresql@16", .formula, "Object-relational database system."),
                DiscoverItem("mysql", .formula, "Open-source relational database."),
                DiscoverItem("redis", .formula, "In-memory data structure store."),
                DiscoverItem("sqlite", .formula, "Lightweight SQL database engine."),
                DiscoverItem("mongodb-community", .formula, "MongoDB community server.")
            ]
        ),
        DiscoverCollection(
            id: "ai-tools",
            title: "AI Tools",
            description: "Command-line tools and apps for working with AI models.",
            items: [
                DiscoverItem("ollama", .formula, "Run large language models locally."),
                DiscoverItem("llm", .formula, "CLI for interacting with language models."),
                DiscoverItem("huggingface-cli", .formula, "Hugging Face Hub command-line interface."),
                DiscoverItem("chatgpt", .cask, "Official ChatGPT desktop app."),
                DiscoverItem("lm-studio", .cask, "Discover and run local LLMs.")
            ]
        ),
        DiscoverCollection(
            id: "productivity",
            title: "Productivity",
            description: "Small tools that make macOS workflows smoother.",
            items: [
                DiscoverItem("raycast", .cask, "Launcher and productivity command center."),
                DiscoverItem("rectangle", .cask, "Window management for macOS."),
                DiscoverItem("notion", .cask, "Workspace notes and docs app."),
                DiscoverItem("obsidian", .cask, "Local-first markdown notes app.")
            ]
        ),
        DiscoverCollection(
            id: "browsers",
            title: "Browsers",
            description: "Common browsers available through Homebrew casks.",
            items: [
                DiscoverItem("google-chrome", .cask, "Google Chrome browser."),
                DiscoverItem("firefox", .cask, "Mozilla Firefox browser."),
                DiscoverItem("brave-browser", .cask, "Privacy-focused Chromium browser."),
                DiscoverItem("arc", .cask, "Modern browser for macOS.")
            ]
        ),
        DiscoverCollection(
            id: "media",
            title: "Media",
            description: "Media playback, recording, and conversion tools.",
            items: [
                DiscoverItem("ffmpeg", .formula, "Audio and video conversion toolkit."),
                DiscoverItem("yt-dlp", .formula, "Video downloader."),
                DiscoverItem("vlc", .cask, "Media player."),
                DiscoverItem("obs", .cask, "Recording and streaming studio.")
            ]
        ),
        DiscoverCollection(
            id: "security",
            title: "Security",
            description: "Security and privacy tools for local development.",
            items: [
                DiscoverItem("gnupg", .formula, "GNU Privacy Guard."),
                DiscoverItem("openssl@3", .formula, "Cryptography and SSL/TLS toolkit."),
                DiscoverItem("age", .formula, "Simple file encryption tool."),
                DiscoverItem("wireshark", .cask, "Network protocol analyzer.")
            ]
        ),
        DiscoverCollection(
            id: "utilities",
            title: "Utilities",
            description: "Useful system and desktop utilities.",
            items: [
                DiscoverItem("tree", .formula, "Display directories as trees."),
                DiscoverItem("htop", .formula, "Interactive process viewer."),
                DiscoverItem("watch", .formula, "Run commands repeatedly."),
                DiscoverItem("orbstack", .cask, "Containers and Linux machines on macOS."),
                DiscoverItem("keepingyouawake", .cask, "Prevent your Mac from sleeping.")
            ]
        )
    ]
}

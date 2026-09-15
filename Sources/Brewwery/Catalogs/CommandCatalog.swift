import Foundation

/// `renderer/lib/brew-commands.ts` — a read-only reference of the Homebrew commands
/// Brewwery runs on the user's behalf. Nothing here is executed; the page exists so the
/// underlying terminal logic stays visible rather than hidden.
struct BrewCommandEntry: Identifiable, Hashable {
    let command: String
    let description: String
    var id: String { command }

    init(_ command: String, _ description: String) {
        self.command = command
        self.description = description
    }
}

struct BrewCommandSection: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let commands: [BrewCommandEntry]
}

struct DocumentationLink: Identifiable, Hashable {
    let label: String
    let description: String
    let url: String
    var id: String { url }
}

enum CommandCatalog {
    static let sections: [BrewCommandSection] = [
        BrewCommandSection(
            id: "packages",
            title: "Packages",
            description: "Install, inspect, and remove command-line formulae.",
            commands: [
                BrewCommandEntry("brew install git", "Install a command-line formula."),
                BrewCommandEntry("brew uninstall git", "Remove an installed formula."),
                BrewCommandEntry("brew list", "List installed formulae."),
                BrewCommandEntry("brew info redis", "Show details, dependencies, and caveats for a formula.")
            ]
        ),
        BrewCommandSection(
            id: "casks",
            title: "Casks",
            description: "Install and manage macOS applications.",
            commands: [
                BrewCommandEntry("brew install --cask visual-studio-code", "Install a macOS application distributed as a cask."),
                BrewCommandEntry("brew uninstall --cask visual-studio-code", "Remove an installed cask."),
                BrewCommandEntry("brew list --cask", "List installed casks."),
                BrewCommandEntry("brew info --cask visual-studio-code", "Show details for a cask.")
            ]
        ),
        BrewCommandSection(
            id: "updates",
            title: "Updates",
            description: "Refresh metadata and upgrade installed packages.",
            commands: [
                BrewCommandEntry("brew update", "Fetch the latest package metadata from Homebrew."),
                BrewCommandEntry("brew outdated", "List installed packages that have newer versions."),
                BrewCommandEntry("brew upgrade", "Upgrade all outdated formulae and casks."),
                BrewCommandEntry("brew upgrade redis", "Upgrade a single package.")
            ]
        ),
        BrewCommandSection(
            id: "services",
            title: "Services",
            description: "Manage background processes like databases.",
            commands: [
                BrewCommandEntry("brew services list", "Show the status of all managed services."),
                BrewCommandEntry("brew services start redis", "Start a service and launch it at login."),
                BrewCommandEntry("brew services stop redis", "Stop a running service."),
                BrewCommandEntry("brew services restart postgresql@16", "Restart a service.")
            ]
        ),
        BrewCommandSection(
            id: "cleanup",
            title: "Cleanup",
            description: "Reclaim disk space from old versions and caches.",
            commands: [
                BrewCommandEntry("brew cleanup -n", "Preview what Homebrew can remove without deleting anything."),
                BrewCommandEntry("brew cleanup", "Remove old versions and stale downloads.")
            ]
        ),
        BrewCommandSection(
            id: "doctor",
            title: "Doctor",
            description: "Check the health of your Homebrew installation.",
            commands: [
                BrewCommandEntry("brew doctor", "Report common problems. It only diagnoses — it changes nothing.")
            ]
        ),
        BrewCommandSection(
            id: "brewfile",
            title: "Brewfile",
            description: "Describe and reproduce your setup as a file.",
            commands: [
                BrewCommandEntry("brew bundle dump", "Write your current setup to a Brewfile."),
                BrewCommandEntry("brew bundle install", "Install everything listed in a Brewfile.")
            ]
        )
    ]

    /// Every URL here must also pass `ExternalLinkPolicy` — there is no generic "open any
    /// URL" capability.
    static let documentationLinks: [DocumentationLink] = [
        DocumentationLink(
            label: "Getting Started",
            description: "Set up Brewwery and connect your Homebrew install.",
            url: "https://docs.brewwery.com/getting-started"
        ),
        DocumentationLink(
            label: "Brew Commands",
            description: "The full Homebrew command reference.",
            url: "https://docs.brewwery.com/brew-commands"
        ),
        DocumentationLink(
            label: "What is Homebrew?",
            description: "A plain-English guide to the macOS package manager.",
            url: "https://docs.brewwery.com/what-is-homebrew"
        ),
        DocumentationLink(
            label: "Security Model",
            description: "How Brewwery runs commands safely and locally.",
            url: "https://docs.brewwery.com/security"
        ),
        DocumentationLink(
            label: "Troubleshooting",
            description: "Fixes for common Homebrew and Brewwery issues.",
            url: "https://docs.brewwery.com/troubleshooting"
        ),
        DocumentationLink(
            label: "Report Issue",
            description: "Open a bug report on GitHub.",
            url: "https://github.com/brewwery/brewwery/issues/new"
        )
    ]
}

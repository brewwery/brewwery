import BrewweryCore
import SwiftUI

/// Installed formulae, casks and leaves.
///
/// Replaces the legacy Zustand `package-store` plus `hooks/use-packages.ts`. Shared by the
/// Dashboard, Packages, Casks, Discover, Search and Favorites screens so the installed
/// state they show cannot diverge.
@MainActor
@Observable
final class PackageLibrary {
    private(set) var formulae: [Formula] = []
    private(set) var casks: [Cask] = []
    private(set) var leaves: Set<String> = []

    private(set) var formulaeError: BrewweryError?
    private(set) var casksError: BrewweryError?
    private(set) var isLoadingFormulae = true
    private(set) var isLoadingCasks = true

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    var isLoading: Bool { isLoadingFormulae || isLoadingCasks }

    func error(for kind: PackageKind) -> BrewweryError? {
        kind == .formula ? formulaeError : casksError
    }

    func isLoading(_ kind: PackageKind) -> Bool {
        kind == .formula ? isLoadingFormulae : isLoadingCasks
    }

    func loadFormulae() async {
        isLoadingFormulae = true
        defer { isLoadingFormulae = false }

        do {
            formulae = try await client.installedFormulae()
            formulaeError = nil
            // Leaves only make sense once the formula list loaded; a failure here is not
            // worth failing the page over, so it degrades the filter rather than the list.
            leaves = Set((try? await client.leaves())?.map { $0.lowercased() } ?? [])
        } catch {
            formulaeError = error
        }
    }

    func loadCasks() async {
        isLoadingCasks = true
        defer { isLoadingCasks = false }

        do {
            casks = try await client.installedCasks()
            casksError = nil
        } catch {
            casksError = error
        }
    }

    func loadAll() async {
        async let formulae: Void = loadFormulae()
        async let casks: Void = loadCasks()
        _ = await (formulae, casks)
    }

    /// `isPackageInstalled` — case-insensitive lookup against the installed caches.
    func isInstalled(name: String, kind: PackageKind) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return switch kind {
        case .formula: formulae.contains { $0.name.lowercased() == normalized }
        case .cask: casks.contains { $0.token.lowercased() == normalized }
        }
    }

    /// `packageDisplayName` — the friendlier label when the package is installed.
    func displayName(for name: String, kind: PackageKind) -> String {
        let normalized = name.lowercased()
        return switch kind {
        case .formula:
            formulae.first { $0.name.lowercased() == normalized }?.fullName ?? name
        case .cask:
            casks.first { $0.token.lowercased() == normalized }?.name?.first ?? name
        }
    }

    func installedVersion(for name: String, kind: PackageKind) -> String? {
        let normalized = name.lowercased()
        return switch kind {
        case .formula: formulae.first { $0.name.lowercased() == normalized }?.installedVersion
        case .cask: casks.first { $0.token.lowercased() == normalized }?.installedVersion
        }
    }

    func isLeaf(_ formula: Formula) -> Bool {
        leaves.contains(formula.name.lowercased())
    }
}

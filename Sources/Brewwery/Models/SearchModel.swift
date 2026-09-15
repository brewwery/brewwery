import BrewweryCore
import SwiftUI

/// `hooks/use-package-discovery.ts` — debounced Homebrew search with stale-response
/// suppression.
///
/// The legacy hook debounced by 350 ms and tracked a monotonic request id so a slow earlier
/// search could not overwrite a newer one. Natively that is a single `Task` that is
/// cancelled when the query changes: the sleep is the debounce, and cancellation makes stale
/// responses impossible rather than merely ignored.
@MainActor
@Observable
final class SearchModel {
    private(set) var results: [PackageSearchResult] = []
    private(set) var isSearching = false
    private(set) var error: BrewweryError?
    /// `true` when the typed query contains characters Homebrew search does not accept.
    private(set) var hasInvalidQuery = false
    /// The query the currently displayed results belong to.
    private(set) var activeQuery = ""

    private let client: HomebrewClient
    private var searchTask: Task<Void, Never>?

    static let debounce = Duration.milliseconds(350)

    init(client: HomebrewClient) {
        self.client = client
    }

    func search(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !query.isEmpty else {
            results = []
            error = nil
            hasInvalidQuery = false
            isSearching = false
            activeQuery = ""
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        guard HomebrewIdentifier.isValidSearchQuery(query) else {
            hasInvalidQuery = true
            results = []
            error = nil
            isSearching = false
            activeQuery = query
            return
        }

        hasInvalidQuery = false
        isSearching = true
        error = nil

        do {
            let results = try await client.search(query)
            guard !Task.isCancelled else { return }
            self.results = results
            self.activeQuery = query
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
        }
        isSearching = false
    }

    func clear() {
        searchTask?.cancel()
        results = []
        error = nil
        hasInvalidQuery = false
        isSearching = false
        activeQuery = ""
    }
}

/// `usePackageInfo` — loads `brew info` for the detail drawer.
@MainActor
@Observable
final class PackageInfoModel {
    private(set) var info: PackageInfo?
    private(set) var isLoading = false
    private(set) var error: BrewweryError?
    private(set) var dependents: [String] = []
    private(set) var isLoadingDependents = false

    private let client: HomebrewClient
    private var dependentsTask: Task<Void, Never>?

    init(client: HomebrewClient) {
        self.client = client
    }

    func load(_ reference: PackageReference) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            info = try await client.packageInfo(for: reference)
        } catch {
            self.error = error
        }
    }

    /// Installed dependents are only meaningful for an installed formula, so the query is
    /// skipped entirely for casks and for packages that are not installed.
    func loadDependents(for reference: PackageReference?) {
        dependentsTask?.cancel()
        dependents = []

        guard let reference, reference.kind == .formula else {
            isLoadingDependents = false
            return
        }

        isLoadingDependents = true
        dependentsTask = Task { [weak self] in
            guard let self else { return }
            let found = (try? await client.dependents(of: reference.name)) ?? []
            guard !Task.isCancelled else { return }
            dependents = found
            isLoadingDependents = false
        }
    }

    func clear() {
        dependentsTask?.cancel()
        info = nil
        error = nil
        dependents = []
        isLoadingDependents = false
    }

    /// Fills in installed state from the local caches, which know about packages Homebrew's
    /// `info` output does not mark as installed.
    func hydrated(with library: PackageLibrary) -> PackageInfo? {
        guard var info else { return nil }
        let key = info.token ?? info.name

        guard library.isInstalled(name: key, kind: info.kind) else { return info }
        info.installed = true
        info.installedVersion = info.installedVersion ?? library.installedVersion(for: key, kind: info.kind)
        return info
    }
}

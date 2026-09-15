import Foundation
import Observation

/// Locally saved favourite packages (`brewwery-favorites`).
///
/// Keys are kind-scoped, trimmed and case-insensitive, so `Redis` and `redis` are the same
/// favourite and a formula and a cask with the same name are not.
@MainActor
@Observable
public final class FavoritesStore {
    public private(set) var favorites: [FavoritePackage] = []

    private let store: JSONFileStore<[FavoritePackage]>

    public init(fileName: String = "favorites.json", directory: URL? = nil) {
        self.store = JSONFileStore(fileName: fileName, directory: directory ?? brewweryApplicationSupportDirectory())
        self.favorites = store.load() ?? []
    }

    public func isFavorite(name: String, kind: PackageKind) -> Bool {
        let key = FavoritePackage.key(name: name, kind: kind)
        return favorites.contains { FavoritePackage.key(name: $0.name, kind: $0.kind) == key }
    }

    public func add(name: String, kind: PackageKind) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isFavorite(name: trimmed, kind: kind) else { return }
        favorites.append(FavoritePackage(name: trimmed, kind: kind))
        store.save(favorites)
    }

    public func remove(name: String, kind: PackageKind) {
        let key = FavoritePackage.key(name: name, kind: kind)
        favorites.removeAll { FavoritePackage.key(name: $0.name, kind: $0.kind) == key }
        store.save(favorites)
    }

    public func toggle(name: String, kind: PackageKind) {
        isFavorite(name: name, kind: kind) ? remove(name: name, kind: kind) : add(name: name, kind: kind)
    }

    public func clear() {
        favorites = []
        store.save(favorites)
    }
}

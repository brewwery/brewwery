import BrewweryCore
import SwiftUI

/// Sidebar destinations, in the order and grouping the legacy sidebar used.
enum Page: String, CaseIterable, Identifiable, Hashable {
    case dashboard, discover, search, favorites, packages, casks, taps, updates
    case services, cleanup, doctor, brewfile, commands
    case history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .discover: "Discover"
        case .search: "Search"
        case .favorites: "Favorites"
        case .packages: "Packages"
        case .casks: "Casks"
        case .taps: "Taps"
        case .updates: "Updates"
        case .services: "Services"
        case .cleanup: "Cleanup"
        case .doctor: "Doctor"
        case .brewfile: "Brewfile"
        case .commands: "Commands"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    /// SF Symbols chosen to match the lucide icons the legacy sidebar used.
    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.33percent"
        case .discover: "safari"
        case .search: "magnifyingglass"
        case .favorites: "star"
        case .packages: "shippingbox"
        case .casks: "archivebox"
        case .taps: "arrow.triangle.branch"
        case .updates: "arrow.down.circle"
        case .services: "waveform.path.ecg"
        case .cleanup: "sparkles"
        case .doctor: "stethoscope"
        case .brewfile: "doc.text"
        case .commands: "terminal"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    struct Section: Identifiable {
        let title: String
        let pages: [Page]
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "Library", pages: [.dashboard, .discover, .search, .favorites, .packages, .casks, .taps, .updates]),
        Section(title: "System", pages: [.services, .cleanup, .doctor, .brewfile, .commands]),
        Section(title: "App", pages: [.history, .settings])
    ]
}

/// A transient notification (`toast-store`).
struct Toast: Identifiable, Equatable {
    enum Tone {
        case success
        case error
        case info
    }

    let id = UUID()
    let tone: Tone
    let title: String
    let description: String?
}

/// Navigation and other transient UI state.
///
/// Deliberately small: the legacy Zustand `ui-store` held only the active page and the
/// search query, and everything else lived with its feature.
@MainActor
@Observable
final class AppState {
    var page: Page = .dashboard
    var searchQuery: String = ""
    /// Bumped by ⌘R so pages can re-run their load, matching the legacy remount-on-refresh.
    private(set) var refreshToken = 0
    /// Raised by ⌘K and consumed by whichever search field appears next. A counter would not
    /// do: ⌘K also switches page, so the field that receives focus is a freshly built one
    /// that never saw the change.
    var pendingSearchFocus = false

    private(set) var toasts: [Toast] = []
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    static let toastLimit = 3
    static let toastDuration = Duration.milliseconds(4_200)

    func select(_ page: Page) {
        self.page = page
    }

    func requestRefresh() {
        refreshToken += 1
    }

    func beginSearch() {
        page = .search
        pendingSearchFocus = true
    }

    func show(_ toast: Toast) {
        toasts.insert(toast, at: 0)
        if toasts.count > Self.toastLimit {
            let removed = toasts.suffix(from: Self.toastLimit)
            removed.forEach { dismissTasks.removeValue(forKey: $0.id)?.cancel() }
            toasts = Array(toasts.prefix(Self.toastLimit))
        }

        dismissTasks[toast.id] = Task { [weak self] in
            try? await Task.sleep(for: Self.toastDuration)
            guard !Task.isCancelled else { return }
            self?.dismiss(toast.id)
        }
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
        dismissTasks.removeValue(forKey: id)?.cancel()
    }

    /// Every completed operation raises a toast, exactly as `history-store.addEntry` did.
    func show(historyEntry entry: HistoryEntry) {
        let tone: Toast.Tone = switch entry.status {
        case .success: .success
        case .cancelled: .info
        case .failed: .error
        }
        show(Toast(tone: tone, title: entry.title, description: entry.command))
    }
}

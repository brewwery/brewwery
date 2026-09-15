import BrewweryCore
import SwiftUI

/// The application shell: a fixed 260 pt sidebar, the content area, and a status bar.
///
/// There is no title bar. The window opens with a hidden one and the top of the shell is an
/// empty strip that clears the traffic lights and drags the window; search and Settings live
/// in each page's header instead. A `NavigationSplitView` would bring a collapsible,
/// translucent sidebar Brewwery never had, so the shell is composed explicitly — see
/// `docs/ARCHITECTURE-DECISIONS.md`.
struct RootView: View {
    var body: some View {
        VStack(spacing: 0) {
            WindowTopStrip()

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: Metrics.sidebarWidth)
                Divider().overlay(BrewweryColor.border)
                contentArea
            }

            Divider().overlay(BrewweryColor.border)
            StatusBarView()
        }
        .background(BrewweryColor.appPanel)
        .foregroundStyle(BrewweryColor.foreground)
        .overlay(alignment: .bottomTrailing) { ToastViewport() }
        // The window's hidden title bar still reserves a safe area; the shell draws under it
        // and `WindowTopStrip` provides the clearance instead.
        .ignoresSafeArea(.container, edges: .top)
    }

    private var contentArea: some View {
        ScrollView {
            PageContainer()
                .padding(.horizontal, Metrics.contentPadding)
                .padding(.top, Metrics.tightSpacing)
                .padding(.bottom, Metrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(BrewweryColor.appPanel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

/// Routes to the active page. The `id` forces a fresh view identity on ⌘R, which is how the
/// legacy shell re-ran a page's data loading.
private struct PageContainer: View {
    @Environment(AppEnvironment.self) private var brewwery

    var body: some View {
        Group {
            switch brewwery.state.page {
            case .dashboard: DashboardView()
            case .discover: DiscoverView()
            case .search: SearchView()
            case .favorites: FavoritesView()
            case .packages: PackagesView()
            case .casks: CasksView()
            case .taps: TapsView()
            case .updates: UpdatesView()
            case .services: ServicesView()
            case .cleanup: CleanupView()
            case .doctor: DoctorView()
            case .brewfile: BrewfileView()
            case .commands: CommandsView()
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .id("\(brewwery.state.page.rawValue):\(brewwery.state.refreshToken)")
    }
}

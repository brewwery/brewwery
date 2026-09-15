import BrewweryCore
import SwiftUI

/// The app-wide package search, living in every page header next to that page's own actions.
///
/// It stays narrow so it never dominates the header, and widens while the user is typing so a
/// long package name is still readable. ⌘K focuses it from anywhere.
///
/// Return moves to the Search page rather than each keystroke doing so: switching pages
/// rebuilds the header, which would pull focus out of the field mid-word. Once the Search
/// page is open the field is not rebuilt, so results update live as the user keeps typing.
struct GlobalSearchField: View {
    @Environment(AppEnvironment.self) private var brewwery
    @FocusState private var isFocused: Bool

    static let restingWidth: CGFloat = 200
    static let focusedWidth: CGFloat = 320

    var body: some View {
        BrewweryTextField(
            placeholder: "Search packages...",
            text: Binding(
                get: { brewwery.state.searchQuery },
                set: { brewwery.state.searchQuery = $0 }
            ),
            leadingSystemImage: "magnifyingglass",
            showsClearButton: true,
            onSubmit: {
                guard !brewwery.state.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                brewwery.state.select(.search)
            },
            focus: $isFocused
        )
        .frame(maxWidth: isFocused ? Self.focusedWidth : Self.restingWidth)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .onAppear(perform: takeRequestedFocus)
        .onChange(of: brewwery.state.pendingSearchFocus) { takeRequestedFocus() }
        .accessibilityLabel("Search Homebrew packages")
    }

    private func takeRequestedFocus() {
        guard brewwery.state.pendingSearchFocus else { return }
        brewwery.state.pendingSearchFocus = false
        isFocused = true
    }
}

/// The page-local filter that takes the global search field's place on screens that list
/// something already installed — Packages, Casks, History — so a page never shows two search
/// boxes with different meanings.
struct HeaderFilterField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        BrewweryTextField(
            placeholder: placeholder,
            text: $text,
            leadingSystemImage: "line.3.horizontal.decrease",
            showsClearButton: true,
            focus: $isFocused
        )
        .frame(maxWidth: isFocused ? GlobalSearchField.focusedWidth : GlobalSearchField.restingWidth)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .accessibilityLabel(placeholder)
    }
}

/// The Settings shortcut that used to sit in the title bar.
struct SettingsButton: View {
    @Environment(AppEnvironment.self) private var brewwery

    var body: some View {
        IconButton("Settings", systemImage: "gearshape") {
            brewwery.state.select(.settings)
        }
    }
}

/// The strip of empty space at the top of the window.
///
/// With the title bar gone, this is what keeps the sidebar wordmark and the page title clear
/// of the traffic lights, and it is the window's drag handle.
struct WindowTopStrip: View {
    static let height: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            BrewweryColor.sidebar.frame(width: Metrics.sidebarWidth)
            Divider().overlay(BrewweryColor.border)
            BrewweryColor.appPanel
        }
        .frame(height: Self.height)
        .background(WindowDragArea())
    }
}

/// Lets the empty strip drag the window, the way a title bar would.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        /// Controls placed on top keep their own hit testing; only bare space drags.
        override func hitTest(_ point: NSPoint) -> NSView? {
            super.hitTest(point) === self ? self : nil
        }
    }
}


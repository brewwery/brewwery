import SwiftUI

/// Column description for `BrewweryTable`.
struct TableColumnSpec<Item: Identifiable>: Identifiable {
    let id = UUID()
    let header: String
    /// Mirrors the CSS `grid-template-columns` track for this column.
    let width: TableColumnWidth
    let alignment: Alignment
    let content: (Item) -> AnyView

    init(
        _ header: String,
        width: TableColumnWidth,
        alignment: Alignment = .leading,
        @ViewBuilder content: @escaping (Item) -> some View
    ) {
        self.header = header
        self.width = width
        self.alignment = alignment
        self.content = { AnyView(content($0)) }
    }
}

enum TableColumnWidth {
    case fixed(CGFloat)
    /// `minmax(min, weight fr)`
    case flexible(minimum: CGFloat, weight: CGFloat)
}

/// The bordered grid used by Packages, Casks, Updates, Services, Cleanup, Search, Favorites
/// and History.
///
/// Rows are laid out lazily inside a scroll view, so a library of thousands of formulae only
/// materialises the rows on screen — the native equivalent of the legacy
/// `@tanstack/react-virtual` table. Keyboard support matches the original: arrow keys and
/// Home/End move the selection, Return activates it.
struct BrewweryTable<Item: Identifiable & Hashable>: View {
    let accessibilityLabel: String
    let items: [Item]
    let columns: [TableColumnSpec<Item>]
    var rowHeight: CGFloat = Metrics.virtualizedRowHeight
    var maxHeight: CGFloat?
    var onActivate: (Item) -> Void

    @State private var selection: Item.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(BrewweryColor.border)
            rows
        }
        .background(BrewweryColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        TrackLayout(tracks: columns.map(\.width)) {
            ForEach(columns) { column in
                Text(column.header)
                    .font(BrewweryFont.captionEmphasis)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .lineLimit(1)
                    .padding(.horizontal, Metrics.tableCellPaddingHorizontal)
                    .padding(.vertical, Metrics.tableCellPaddingVertical)
                    .frame(maxWidth: .infinity, alignment: column.alignment)
            }
        }
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        row(for: item)
                            .id(item.id)
                    }
                }
            }
            .frame(maxHeight: maxHeight)
            .focusable()
            // Clicking a row's button focuses the table; the system ring would then outline the
            // whole table. The selected-row highlight already shows keyboard position.
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(.upArrow) { move(by: -1, proxy: proxy) }
            .onKeyPress(.downArrow) { move(by: 1, proxy: proxy) }
            .onKeyPress(.home) { moveTo(0, proxy: proxy) }
            .onKeyPress(.end) { moveTo(items.count - 1, proxy: proxy) }
            .onKeyPress(.return) { activateSelection() }
            .onKeyPress(.space) { activateSelection() }
        }
    }

    private func row(for item: Item) -> some View {
        let isSelected = selection == item.id

        return TrackLayout(tracks: columns.map(\.width)) {
            ForEach(columns) { column in
                column.content(item)
                    .padding(.horizontal, Metrics.tableCellPaddingHorizontal)
                    .padding(.vertical, Metrics.tableCellPaddingVertical)
                    .frame(maxWidth: .infinity, alignment: column.alignment)
            }
        }
        .frame(height: rowHeight)
        .background(isSelected ? BrewweryColor.cardHover : Color.clear)
        .modifier(RowHoverHighlight(isSelected: isSelected))
        .overlay(alignment: .bottom) { Divider().overlay(BrewweryColor.border) }
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item.id
            onActivate(item)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func move(by offset: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        let current = items.firstIndex { $0.id == selection }
        return apply(TableNavigation.index(from: current, moving: offset, count: items.count), proxy: proxy)
    }

    @discardableResult
    private func moveTo(_ index: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        apply(TableNavigation.index(jumpingTo: index, count: items.count), proxy: proxy)
    }

    private func apply(_ index: Int?, proxy: ScrollViewProxy) -> KeyPress.Result {
        guard let index else { return .ignored }
        selection = items[index].id
        proxy.scrollTo(items[index].id)
        return .handled
    }

    private func activateSelection() -> KeyPress.Result {
        guard let item = items.first(where: { $0.id == selection }) else { return .ignored }
        onActivate(item)
        return .handled
    }
}

/// Row selection rules for the arrow, Home and End keys, kept free of SwiftUI so they can be
/// tested directly.
enum TableNavigation {
    /// Moving from the current row. With nothing selected, Down lands on the first row and
    /// Up on the first row too, matching the legacy table's `activeIndex = 0` start.
    static func index(from current: Int?, moving offset: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let start = current ?? (offset > 0 ? -1 : 0)
        return min(max(start + offset, 0), count - 1)
    }

    /// Home and End.
    static func index(jumpingTo target: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(max(target, 0), count - 1)
    }
}

private struct RowHoverHighlight: ViewModifier {
    let isSelected: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering && !isSelected ? BrewweryColor.cardHover : Color.clear)
            .onHover { isHovering = $0 }
    }
}

/// Lays a row out like the CSS `grid-template-columns` the legacy tables used: fixed tracks
/// take their exact width, and `minmax(min, N fr)` tracks share the remaining space in
/// proportion to their weight, never dropping below their minimum.
struct TrackLayout: Layout {
    let tracks: [TableColumnWidth]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let widths = resolve(totalWidth: width)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, resolve(totalWidth: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width
        }
    }

    private func resolve(totalWidth: CGFloat) -> [CGFloat] {
        Self.widths(for: tracks, totalWidth: totalWidth)
    }

    static func widths(for tracks: [TableColumnWidth], totalWidth: CGFloat) -> [CGFloat] {
        var widths = tracks.map { track -> CGFloat in
            switch track {
            case .fixed(let width): width
            case .flexible(let minimum, _): minimum
            }
        }

        let used = widths.reduce(0, +)
        let remaining = totalWidth - used

        // Narrower than the tracks require: scale everything down rather than overflowing
        // the table's border, which is how the legacy HTML tables behaved.
        guard remaining > 0 else {
            guard used > 0, totalWidth > 0 else { return widths }
            let scale = totalWidth / used
            return widths.map { $0 * scale }
        }

        let totalWeight = tracks.reduce(0.0) { partial, track in
            if case .flexible(_, let weight) = track { return partial + weight }
            return partial
        }
        guard totalWeight > 0 else { return widths }

        for (index, track) in tracks.enumerated() {
            if case .flexible(_, let weight) = track {
                widths[index] += remaining * (weight / totalWeight)
            }
        }
        return widths
    }
}

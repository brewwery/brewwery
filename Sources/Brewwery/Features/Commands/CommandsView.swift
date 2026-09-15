import BrewweryCore
import SwiftUI

/// `pages/commands.tsx` — the Homebrew command reference and documentation links.
struct CommandsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Commands",
                subtitle: "A reference of common Homebrew commands. Brewwery runs the same logic for you — nothing here is hidden."
            )

            documentation

            ForEach(CommandCatalog.sections) { section in
                sectionCard(section)
            }
        }
    }

    private var documentation: some View {
        BrewweryHeaderCard {
            HStack(spacing: Metrics.tightSpacing) {
                Image(systemName: "book")
                    .font(.system(size: 13))
                    .foregroundStyle(BrewweryColor.accent)
                Text("Documentation")
                    .font(BrewweryFont.panelTitle)
                    .foregroundStyle(BrewweryColor.foreground)
            }
        } content: {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 3),
                spacing: Metrics.rowSpacing
            ) {
                ForEach(CommandCatalog.documentationLinks) { link in
                    Button {
                        ExternalLink.open(link.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(link.label)
                                    .font(BrewweryFont.controlLabel)
                                    .foregroundStyle(BrewweryColor.foreground)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(BrewweryColor.mutedForeground)
                            }
                            Text(link.description)
                                .font(BrewweryFont.caption)
                                .foregroundStyle(BrewweryColor.mutedForeground)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.rowSpacing)
                        .background(BrewweryColor.pre)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                                .strokeBorder(BrewweryColor.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionCard(_ section: BrewCommandSection) -> some View {
        BrewweryHeaderCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Metrics.tightSpacing) {
                        Image(systemName: "terminal")
                            .font(.system(size: 13))
                            .foregroundStyle(BrewweryColor.accent)
                        Text(section.title)
                            .font(BrewweryFont.panelTitle)
                            .foregroundStyle(BrewweryColor.foreground)
                    }
                    Text(section.description)
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }
                Spacer()
                BrewweryBadge(text: String(section.commands.count))
            }
        } content: {
            VStack(spacing: Metrics.tightSpacing) {
                ForEach(section.commands) { command in
                    CommandRow(entry: command)
                }
            }
        }
    }
}

private struct CommandRow: View {
    let entry: BrewCommandEntry
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.command)
                    .font(BrewweryFont.mono)
                    .foregroundStyle(BrewweryColor.accent)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(entry.description)
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .lineSpacing(3)
            }

            Spacer(minLength: Metrics.tightSpacing)

            ActionButton(
                title: didCopy ? "Copied" : "Copy",
                systemImage: didCopy ? "checkmark" : "doc.on.clipboard",
                height: Metrics.compactControlHeight
            ) {
                Clipboard.copy(entry.command)
                didCopy = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1_600))
                    didCopy = false
                }
            }
            .accessibilityLabel("Copy command: \(entry.command)")
        }
        .padding(Metrics.rowSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrewweryColor.pre)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

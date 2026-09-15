import BrewweryCore
import SwiftUI
import UniformTypeIdentifiers

/// `pages/brewfile.tsx` — export the current environment, or read an existing Brewfile.
///
/// The legacy page asked the user to type an absolute path; natively that is an `NSOpenPanel`,
/// which is both more convenient and the only way a sandboxed build could read the file. The
/// typed-path field is kept alongside it so the original workflow still works.
struct BrewfileView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var path = ""
    @State private var didCopy = false

    private var model: BrewfileModel { brewwery.brewfile }

    private static let groups: [(kind: BrewfileEntryKind, label: String)] = [
        (.tap, "Taps"),
        (.brew, "Formulae"),
        (.cask, "Casks"),
        (.mas, "Mac App Store"),
        (.service, "Services"),
        (.unknown, "Unknown")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Brewfile",
                subtitle: "Export or inspect a local Brewfile without running install actions."
            ) {
                ActionButton(title: didCopy ? "Brewfile copied" : "Copy Brewfile", systemImage: "doc.on.clipboard") {
                    guard let content = model.document?.rawContent else { return }
                    Clipboard.copy(content)
                    flashCopied()
                }
                .disabled(model.document?.rawContent == nil)

                ActionButton(title: "Export Brewfile", systemImage: "square.and.arrow.down", variant: .primary) {
                    Task { await brewwery.exportBrewfile() }
                }
                .disabled(model.isWorking)
            }

            readCard
            starterBrewfiles
            content
        }
    }

    private var readCard: some View {
        BrewweryCard {
            HStack(spacing: Metrics.tightSpacing) {
                BrewweryTextField(placeholder: "/absolute/path/to/Brewfile", text: $path)
                ActionButton(title: "Choose...", systemImage: "folder", action: chooseFile)
                    .disabled(model.isWorking)
                ActionButton(title: "Read Brewfile", systemImage: "doc.text") {
                    Task { await model.read(at: path.trimmingCharacters(in: .whitespacesAndNewlines)) }
                }
                .disabled(model.isWorking || path.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var starterBrewfiles: some View {
        BrewweryHeaderCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Starter Brewfiles")
                    .font(BrewweryFont.panelTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                Text("Local, open-source templates you can copy and adapt. Nothing is installed automatically.")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        } content: {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 3),
                spacing: Metrics.rowSpacing
            ) {
                ForEach(StarterBrewfileCatalog.all) { starter in
                    StarterCard(starter: starter)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isWorking {
            StatePanel(title: "Exporting Brewfile...", kind: .loading)
        } else if let error = model.error {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(
                    title: error.code == .brewfileReadFailed || error.code == .invalidFilePath
                        ? "Failed to read Brewfile"
                        : "Failed to export Brewfile",
                    kind: .error
                ) {
                    ErrorDescriptionView(error: error)
                }
            }
        } else if let document = model.document {
            HStack(alignment: .top, spacing: Metrics.cardSpacing) {
                summaryColumn(document)
                    .frame(width: 360)
                generatedColumn(document)
            }
        } else {
            StatePanel(title: "No Brewfile generated yet")
        }
    }

    private func summaryColumn(_ document: BrewfileDocument) -> some View {
        VStack(spacing: Metrics.cardSpacing) {
            BrewweryCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entries")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                    Text(String(document.entries.count))
                        .font(BrewweryFont.statValue)
                        .foregroundStyle(BrewweryColor.foreground)
                    if let path = document.path {
                        Text(path)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }

            ForEach(Self.groups, id: \.kind) { group in
                let entries = model.groupedEntries()[group.kind] ?? []
                BrewweryHeaderCard {
                    HStack {
                        Text(group.label)
                            .font(BrewweryFont.panelTitle)
                            .foregroundStyle(BrewweryColor.foreground)
                        Spacer()
                        BrewweryBadge(text: String(entries.count))
                    }
                } content: {
                    if entries.isEmpty {
                        Text("None")
                            .font(BrewweryFont.body)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                    } else {
                        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                            ForEach(entries.prefix(8)) { entry in
                                Text(entry.name)
                                    .font(BrewweryFont.body)
                                    .foregroundStyle(BrewweryColor.mutedForeground)
                                    .lineLimit(1)
                            }
                            if entries.count > 8 {
                                Text("+\(entries.count - 8) more")
                                    .font(BrewweryFont.caption)
                                    .foregroundStyle(BrewweryColor.mutedForeground)
                            }
                        }
                    }
                }
            }
        }
    }

    private func generatedColumn(_ document: BrewfileDocument) -> some View {
        BrewweryHeaderCard {
            HStack {
                Text("Generated Brewfile")
                    .font(BrewweryFont.panelTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                Spacer()
                BrewweryBadge(
                    text: "\(document.rawContent.split(separator: "\n").count { !$0.isEmpty }) lines"
                )
            }
        } content: {
            MonospacedOutputView(text: document.rawContent, maxHeight: 640)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Brewfile to inspect."
        panel.prompt = "Read"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        path = url.path
        Task { await model.read(at: url.path) }
    }

    private func flashCopied() {
        didCopy = true
        Task {
            try? await Task.sleep(for: .milliseconds(1_600))
            didCopy = false
        }
    }
}

private struct StarterCard: View {
    let starter: StarterBrewfile
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            HStack(alignment: .top) {
                Text(starter.title)
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                Spacer(minLength: Metrics.tightSpacing)
                BrewweryBadge(text: "\(starter.entryCount) entries")
            }

            Text(starter.description)
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            MonospacedOutputView(text: starter.content, maxHeight: 160)

            ActionButton(
                title: didCopy ? "Copied" : "Copy Brewfile",
                systemImage: "doc.on.clipboard",
                height: Metrics.compactControlHeight
            ) {
                Clipboard.copy(starter.content)
                didCopy = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1_600))
                    didCopy = false
                }
            }
        }
        .padding(Metrics.rowSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrewweryColor.pre)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(BrewweryColor.border, lineWidth: 1)
        )
    }
}

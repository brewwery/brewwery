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
    @State private var confirmation: ConfirmationRequest?

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
                subtitle: "Export your setup, open a Brewfile, and install what it lists that this Mac is missing."
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
            OperationProgressPanel()
            content
            starterBrewfiles
        }
        // Re-compare whenever a different Brewfile is opened.
        .task(id: model.document?.rawContent) {
            if model.document != nil { await brewwery.checkBrewfile() }
        }
        .confirmation($confirmation, isWorking: brewwery.operations.isRunning) { _ in
            Task { await brewwery.installMissingFromBrewfile() }
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
                Text("Local, open-source templates. Open one to see what this Mac is missing, or copy it to adapt.")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
        } content: {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.rowSpacing), count: 3),
                spacing: Metrics.rowSpacing
            ) {
                ForEach(StarterBrewfileCatalog.all) { starter in
                    StarterCard(starter: starter) { model.open(starter: starter) }
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
            comparisonCard
            HStack(alignment: .top, spacing: Metrics.cardSpacing) {
                summaryColumn(document)
                    .frame(width: 360)
                generatedColumn(document)
            }
        } else {
            StatePanel(title: "No Brewfile open yet") {
                Text("Export this Mac's setup, choose a Brewfile, or open one of the starters below.")
            }
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        BrewweryHeaderCard {
            HStack(alignment: .center, spacing: Metrics.rowSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compared with this Mac")
                        .font(BrewweryFont.panelTitle)
                        .foregroundStyle(BrewweryColor.foreground)
                    if let source = model.source {
                        Text(source.displayName)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: Metrics.tightSpacing)
                if let plan = model.plan, !plan.isSatisfied {
                    ActionButton(
                        title: plan.missing.count == 1 ? "Install 1 missing item" : "Install \(plan.missing.count) missing items",
                        systemImage: "arrow.down.circle",
                        variant: .primary
                    ) {
                        confirmation = .brewfileInstall(plan)
                    }
                    .disabled(brewwery.operations.isRunning || model.isChecking)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                if model.isChecking || model.plan == nil {
                    Text("Checking what is installed...")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                } else if let plan = model.plan {
                    comparisonSummary(plan)
                    if !plan.missing.isEmpty { missingList(plan) }
                    if !plan.skipped.isEmpty { skippedNote(plan) }
                }
            }
        }
    }

    private func comparisonSummary(_ plan: BrewfilePlan) -> some View {
        HStack(spacing: Metrics.tightSpacing) {
            Image(systemName: plan.isSatisfied ? "checkmark.circle" : "arrow.down.circle")
                .foregroundStyle(plan.isSatisfied ? BrewweryColor.success : BrewweryColor.accent)
            Text(
                plan.isSatisfied
                    ? (plan.checkedCount == 0
                        ? "Nothing in this Brewfile is something Brewwery can install."
                        : "Everything this Brewfile lists is installed.")
                    : "\(plan.missing.count) of \(plan.checkedCount) items are missing on this Mac."
            )
            .font(BrewweryFont.body)
            .foregroundStyle(BrewweryColor.foreground)
        }
    }

    private func missingList(_ plan: BrewfilePlan) -> some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            FlowLayout(spacing: 6) {
                ForEach(plan.missing.prefix(24)) { item in
                    HStack(spacing: 6) {
                        Text(item.kind.rawValue)
                            .font(BrewweryFont.caption)
                            .foregroundStyle(item.kind == .cask ? BrewweryColor.caskAccent : BrewweryColor.accent)
                        Text(item.name)
                            .font(BrewweryFont.monoCaption)
                            .foregroundStyle(BrewweryColor.foreground)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BrewweryColor.pre)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(BrewweryColor.border, lineWidth: 1))
                }
            }
            if plan.missing.count > 24 {
                Text("and \(plan.missing.count - 24) more")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            Text("Installing adds only these. Nothing already installed is upgraded, and options on Brewfile lines — restart_service, args, link — are not applied.")
                .font(BrewweryFont.caption)
                .foregroundStyle(BrewweryColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func skippedNote(_ plan: BrewfilePlan) -> some View {
        let notHandled = plan.skipped.filter { $0.reason == .notHandled }
        let invalid = plan.skipped.filter { $0.reason == .invalidName }
        let ruby = plan.skipped.filter { $0.reason == .rubyCode }

        return VStack(alignment: .leading, spacing: 4) {
            if !notHandled.isEmpty {
                Text("\(notHandled.count) \(notHandled.count == 1 ? "entry is" : "entries are") not handled here — Mac App Store apps, editor extensions and similar. Use brew bundle in Terminal for those: \(notHandled.prefix(5).map(\.entry.name).joined(separator: ", "))\(notHandled.count > 5 ? ", …" : "").")
            }
            if !ruby.isEmpty {
                Text("This Brewfile also contains Ruby — if, end, variables. Brewwery never runs it, and lists every tap, brew and cask line whatever the conditions say, so check the list above before installing.")
                    .foregroundStyle(BrewweryColor.warning)
            }
            if !invalid.isEmpty {
                Text("Skipped because the name is not a valid Homebrew name: \(invalid.prefix(5).map(\.entry.name).joined(separator: ", ")).")
                    .foregroundStyle(BrewweryColor.warning)
            }
        }
        .font(BrewweryFont.caption)
        .foregroundStyle(BrewweryColor.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
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
                Text(model.source?.contentsTitle ?? "Brewfile contents")
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
    let onOpen: () -> Void
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

            HStack(spacing: Metrics.tightSpacing) {
                ActionButton(
                    title: "Open",
                    systemImage: "arrow.down.circle",
                    height: Metrics.compactControlHeight,
                    action: onOpen
                )
                .help("Compare this starter with what is installed")
                ActionButton(
                    title: didCopy ? "Copied" : "Copy",
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

extension ConfirmationRequest {
    /// The Brewfile install, spelled out: the command, and exactly which items.
    static func brewfileInstall(_ plan: BrewfilePlan) -> ConfirmationRequest {
        let count = plan.missing.count
        let list = plan.missing.prefix(12).map { "\($0.kind.rawValue) \($0.name)" }.joined(separator: ", ")
        let more = count > 12 ? " and \(count - 12) more" : ""
        return ConfirmationRequest(
            title: count == 1 ? "Install 1 item from this Brewfile?" : "Install \(count) items from this Brewfile?",
            message: "Brewwery will run",
            command: "brew bundle install --no-upgrade",
            note: "It installs from a list Brewwery writes containing only \(list)\(more). Your Brewfile itself is never run, and nothing already installed is upgraded.",
            confirmLabel: "Install"
        )
    }
}

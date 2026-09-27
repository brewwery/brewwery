import BrewweryCore
import SwiftUI

/// The "Report a problem" window.
///
/// Nothing is sent from here. The user sees the whole report, decides what goes in it, and
/// then hands it to their browser (a pre-filled GitHub issue) or their mail client, where
/// they press Send themselves. That keeps the promise the privacy page makes: Brewwery has
/// no server and no background reporting.
struct ReportProblemView: View {
    @Environment(AppEnvironment.self) private var brewwery
    @State var draft: ProblemReportDraft
    let onClose: () -> Void

    @FocusState private var isEditingDescription: Bool

    var body: some View {
        ZStack {
            BrewweryColor.overlay
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
                header
                descriptionField
                toggles
                preview
                actions
            }
            .padding(Metrics.cardSpacing)
            .frame(maxWidth: 620)
            .background(BrewweryColor.background)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
            .shadow(color: BrewweryColor.panelShadow, radius: 25, x: 0, y: 16)
            .padding(Metrics.sectionSpacing)
        }
        .onAppear { isEditingDescription = true }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(draft.heading)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: Metrics.rowSpacing) {
            Image(systemName: "ladybug")
                .font(.system(size: 14))
                .foregroundStyle(BrewweryColor.accent)
                .frame(width: Metrics.controlHeight, height: Metrics.controlHeight)
                .background(BrewweryColor.warningBackground)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                        .strokeBorder(BrewweryColor.warningBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.heading)
                    .font(BrewweryFont.cardTitle)
                    .foregroundStyle(BrewweryColor.foreground)
                Text("Nothing is sent automatically. Review the report, then open it as a GitHub issue or an email — you press Send.")
                    .font(BrewweryFont.body)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            Text("What happened?")
                .font(BrewweryFont.controlLabel)
                .foregroundStyle(BrewweryColor.foreground)

            ZStack(alignment: .topLeading) {
                if draft.report.description.isEmpty {
                    Text(draft.report.failure == nil
                         ? "What you did, what you expected, and what happened instead."
                         : "Anything that helps: what you were doing, whether it happens every time.")
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft.report.description)
                    .font(BrewweryFont.body)
                    .scrollContentBackground(.hidden)
                    .focused($isEditingDescription)
                    .padding(.vertical, 4)
                    .accessibilityLabel("What happened?")
            }
            .frame(height: 96)
            .padding(.horizontal, Metrics.tightSpacing)
            .background(BrewweryColor.input)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(isEditingDescription ? BrewweryColor.focusRing : BrewweryColor.border, lineWidth: 1)
            )
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Include environment details — versions, Mac model, package counts", isOn: $draft.report.includeDiagnostics)
            if draft.report.failure != nil {
                Toggle(
                    "Include the last \(ProblemReport.outputLineLimit) lines of Homebrew output",
                    isOn: $draft.report.includeOutput
                )
            }
        }
        .toggleStyle(.checkbox)
        .font(BrewweryFont.body)
        .foregroundStyle(BrewweryColor.foreground)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            HStack {
                Text("Preview")
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                Spacer()
                Text("Paths in your home folder appear as ~")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }

            ScrollView {
                Text(draft.report.markdown())
                    .font(BrewweryFont.monoCaption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Metrics.rowSpacing)
            }
            .frame(height: 180)
            .background(BrewweryColor.pre)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
            .accessibilityLabel("Report preview")
        }
    }

    private var actions: some View {
        HStack(spacing: Metrics.tightSpacing) {
            ActionButton(title: "Copy", systemImage: "doc.on.clipboard", action: copy)
                .help("Copy the report as Markdown")
            ActionButton(title: "Email…", systemImage: "envelope", action: email)
                .help("Open a new message to \(ProblemReport.supportAddress)")

            Spacer(minLength: Metrics.tightSpacing)

            Button("Cancel", action: onClose)
                .brewweryButton(.secondary)
                .keyboardShortcut(.cancelAction)
            Button(action: openIssue) {
                Label("Open GitHub issue", systemImage: "arrow.up.right.square")
            }
            .brewweryButton(.primary)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Opens a pre-filled issue in your browser (⌘↩)")
        }
    }

    // MARK: - Actions

    private func copy() {
        Clipboard.copy(draft.report.markdown())
        finish(title: "Report copied", description: "Paste it into an issue, an email, or a message.")
    }

    private func email() {
        let (url, truncated) = draft.report.mailURL()
        ExternalLink.openMail(url)
        finish(truncated: truncated, title: "Opened in Mail", description: "Review it there and press Send.")
    }

    private func openIssue() {
        let (url, truncated) = draft.report.githubIssueURL()
        ExternalLink.open(url.absoluteString)
        finish(truncated: truncated, title: "Opened on GitHub", description: "Review the issue there and press Submit.")
    }

    /// Links have a length limit. When the report did not fit, the complete version goes
    /// on the clipboard so nothing the user saw in the preview is lost.
    private func finish(truncated: Bool = false, title: String, description: String) {
        if truncated {
            Clipboard.copy(draft.report.markdown())
            brewwery.state.show(Toast(
                tone: .info,
                title: title,
                description: "The report was too long for a link, so its output was shortened. The full report is on your clipboard."
            ))
        } else {
            brewwery.state.show(Toast(tone: .success, title: title, description: description))
        }
        onClose()
    }
}

extension View {
    /// Shows the report window whenever `AppState.problemReport` is set.
    func problemReportPresenter(_ brewwery: AppEnvironment) -> some View {
        overlay {
            if let draft = brewwery.state.problemReport {
                ReportProblemView(draft: draft) { brewwery.state.problemReport = nil }
                    .id(draft.id)
            }
        }
    }
}

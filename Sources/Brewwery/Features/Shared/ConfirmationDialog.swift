import BrewweryCore
import SwiftUI

/// A pending confirmation. Every mutating Homebrew operation goes through one of these.
struct ConfirmationRequest: Identifiable, Equatable {
    let id = UUID()
    let title: String
    /// Leading prose shown before the command.
    let message: String
    /// The exact command Brewwery will run, rendered monospaced.
    let command: String?
    /// Extra consequence text, e.g. the dependency note on uninstall.
    let note: String?
    let confirmLabel: String

    init(title: String, message: String, command: String? = nil, note: String? = nil, confirmLabel: String) {
        self.title = title
        self.message = message
        self.command = command
        self.note = note
        self.confirmLabel = confirmLabel
    }
}

/// `components/ui/confirmation-dialog.tsx`.
///
/// Kept as a custom sheet rather than a system alert because showing the exact command
/// Brewwery is about to run — monospaced, in full — is part of the product's contract with
/// the user. Keyboard behaviour is the native one: Escape cancels, Return confirms.
struct ConfirmationDialogView: View {
    let request: ConfirmationRequest
    var isWorking = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            BrewweryColor.overlay
                .ignoresSafeArea()
                .onTapGesture { if !isWorking { onCancel() } }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Metrics.rowSpacing) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14))
                        .foregroundStyle(BrewweryColor.accent)
                        .frame(width: Metrics.controlHeight, height: Metrics.controlHeight)
                        .background(BrewweryColor.warningBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                                .strokeBorder(BrewweryColor.warningBorder, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                        Text(request.title)
                            .font(BrewweryFont.cardTitle)
                            .foregroundStyle(BrewweryColor.foreground)

                        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                            commandSentence
                            if let note = request.note {
                                Text(note)
                            }
                        }
                        .font(BrewweryFont.body)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: Metrics.tightSpacing) {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .brewweryButton(.secondary)
                        .keyboardShortcut(.cancelAction)
                        .disabled(isWorking)
                    Button(isWorking ? "Working..." : request.confirmLabel, action: onConfirm)
                        .brewweryButton(.primary)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isWorking)
                }
                .padding(.top, Metrics.sectionSpacing)
            }
            .padding(Metrics.cardSpacing)
            .frame(maxWidth: 448)
            .background(BrewweryColor.background)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(BrewweryColor.border, lineWidth: 1)
            )
            .shadow(color: BrewweryColor.panelShadow, radius: 25, x: 0, y: 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(request.title)
    }

    /// "Brewwery will run `brew install redis`." with the command in monospace.
    @ViewBuilder
    private var commandSentence: some View {
        if let command = request.command {
            (
                Text(request.message + " ")
                    + Text(command)
                    .font(BrewweryFont.mono)
                    .foregroundColor(BrewweryColor.foreground)
                    + Text(".")
            )
        } else {
            Text(request.message)
        }
    }
}

extension View {
    /// Presents a confirmation over the page.
    func confirmation(
        _ request: Binding<ConfirmationRequest?>,
        isWorking: Bool = false,
        onConfirm: @escaping (ConfirmationRequest) -> Void
    ) -> some View {
        overlay {
            if let value = request.wrappedValue {
                ConfirmationDialogView(
                    request: value,
                    isWorking: isWorking,
                    onCancel: { request.wrappedValue = nil },
                    onConfirm: {
                        request.wrappedValue = nil
                        onConfirm(value)
                    }
                )
            }
        }
    }
}

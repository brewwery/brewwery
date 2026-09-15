import BrewweryCore
import SwiftUI

/// `pages/taps.tsx` — list, add and remove Homebrew taps, both mutations confirmed.
struct TapsView: View {
    @Environment(AppEnvironment.self) private var brewwery

    @State private var newTap = ""
    @State private var confirmation: ConfirmationRequest?
    @State private var pending: (action: TapAction, name: String)?

    private var model: TapsModel { brewwery.taps }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Taps",
                subtitle: "Manage additional Homebrew formula and cask repositories."
            ) {
                ActionButton(title: "Refresh list", systemImage: "arrow.clockwise") {
                    Task { await model.refresh() }
                }
                .disabled(model.isLoading)
            }

            addTapCard
            content
        }
        .task { if model.taps.isEmpty { await model.refresh() } }
        .confirmation($confirmation, isWorking: model.isWorking) { _ in
            Task {
                guard let pending else { return }
                await brewwery.performTapAction(pending.action, name: pending.name)
                if pending.action == .tap, model.error == nil { newTap = "" }
                self.pending = nil
            }
        }
    }

    private var addTapCard: some View {
        BrewweryCard {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a tap")
                        .font(BrewweryFont.controlLabel)
                        .foregroundStyle(BrewweryColor.foreground)
                    Text("Use the owner/repository format, for example user/homebrew-tools.")
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                }

                HStack(spacing: Metrics.tightSpacing) {
                    BrewweryTextField(
                        placeholder: "owner/repository",
                        text: $newTap,
                        onSubmit: submit
                    )
                    .accessibilityLabel("Tap name")

                    ActionButton(title: "Add tap", systemImage: "plus", variant: .primary, action: submit)
                        .disabled(newTap.trimmingCharacters(in: .whitespaces).isEmpty || model.isWorking)
                }
                .frame(maxWidth: 576)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            StatePanel(title: "Loading taps...", kind: .loading)
        } else if let error = model.error {
            StatePanel(title: "Homebrew tap operation failed", kind: .error) {
                ErrorDescriptionView(error: error)
            } action: {
                Button("Retry") { Task { await model.refresh() } }.brewweryButton()
            }
        } else if model.taps.isEmpty {
            StatePanel(title: "No additional taps installed") {
                Text("Homebrew can still use its built-in repositories.")
            }
        } else {
            tapList
        }
    }

    private var tapList: some View {
        BrewweryCard(padding: nil) {
            VStack(spacing: 0) {
                ForEach(Array(model.sortedTaps.enumerated()), id: \.element.id) { index, tap in
                    if index > 0 { Divider().overlay(BrewweryColor.border) }
                    row(for: tap)
                }
            }
        }
    }

    private func row(for tap: BrewTap) -> some View {
        HStack(spacing: Metrics.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Metrics.tightSpacing) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 13))
                        .foregroundStyle(BrewweryColor.accent)
                    Text(tap.name)
                        .font(BrewweryFont.controlLabel)
                        .foregroundStyle(BrewweryColor.foreground)
                }
                Text("Installed Homebrew tap")
                    .font(BrewweryFont.caption)
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }

            Spacer(minLength: Metrics.tightSpacing)

            BrewweryBadge(text: tap.official ? "Official" : "Third-party")

            IconButton("Remove \(tap.name)", systemImage: "trash", height: Metrics.compactControlHeight) {
                pending = (.untap, tap.name)
                confirmation = confirmationRequest(for: .untap, name: tap.name)
            }
        }
        .padding(.horizontal, Metrics.cardSpacing)
        .padding(.vertical, Metrics.rowSpacing)
        .frame(minHeight: 64)
    }

    private func submit() {
        let name = newTap.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        pending = (.tap, name)
        confirmation = confirmationRequest(for: .tap, name: name)
    }

    private func confirmationRequest(for action: TapAction, name: String) -> ConfirmationRequest {
        let command = action == .tap
            ? HomebrewCommand.addTap(name: name)
            : HomebrewCommand.removeTap(name: name)

        return ConfirmationRequest(
            title: action == .tap ? "Add \(name)?" : "Remove \(name)?",
            message: "Brewwery will run",
            command: command.displayCommand(),
            note: "Removing a tap can make its installed formulae unavailable for future upgrades.",
            confirmLabel: action == .tap ? "Add tap" : "Remove tap"
        )
    }
}

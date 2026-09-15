import BrewweryCore
import SwiftUI

/// `pages/doctor.tsx` — parsed diagnostics rather than a raw terminal dump.
struct DoctorView: View {
    @Environment(AppEnvironment.self) private var brewwery

    private var model: DoctorModel { brewwery.doctor }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            PageHeader(
                title: "Doctor",
                subtitle: "Run brew doctor and review diagnostics without leaving Brewwery."
            ) {
                ActionButton(title: "Copy diagnostics", systemImage: "doc.on.clipboard") {
                    if let output = model.result?.rawOutput { Clipboard.copy(output) }
                }
                .disabled(model.result?.rawOutput == nil)

                ActionButton(title: "Run doctor", systemImage: "stethoscope", variant: .primary) {
                    Task { await brewwery.runDoctor() }
                }
                .disabled(model.isRunning)
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isRunning {
            StatePanel(title: "Running brew doctor...", kind: .loading)
        } else if let error = model.error {
            if error.code == .homebrewNotFound {
                HomebrewNotFoundPanel()
            } else {
                StatePanel(title: "Failed to run brew doctor", kind: .error) {
                    ErrorDescriptionView(error: error)
                } action: {
                    Button("Retry") { Task { await brewwery.runDoctor() } }.brewweryButton()
                }
            }
        } else if let result = model.result {
            if result.healthy {
                StatePanel(title: "Your Homebrew installation looks healthy") {
                    if let output = result.rawOutput {
                        OutputDisclosure(label: "Show raw output", content: output, maxHeight: 320)
                    }
                }
            } else if !result.diagnostics.isEmpty {
                diagnostics(result)
            } else if let output = result.rawOutput {
                StatePanel(title: "Doctor finished") {
                    OutputDisclosure(label: "Show raw output", content: output, maxHeight: 320)
                }
            }
        } else {
            StatePanel(title: "No doctor run yet")
        }
    }

    private func diagnostics(_ result: DoctorResult) -> some View {
        VStack(alignment: .leading, spacing: Metrics.cardSpacing) {
            BrewweryCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health status")
                            .font(BrewweryFont.body)
                            .foregroundStyle(BrewweryColor.mutedForeground)
                        Text("Warnings found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(BrewweryColor.foreground)
                    }
                    Spacer()
                    BrewweryBadge(text: "\(result.diagnostics.count) diagnostics", tone: .warning)
                }
            }

            VStack(spacing: Metrics.rowSpacing) {
                ForEach(result.diagnostics) { diagnostic in
                    BrewweryCard {
                        HStack(alignment: .top, spacing: Metrics.cardSpacing) {
                            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                                Text(diagnostic.title)
                                    .font(BrewweryFont.panelTitle)
                                    .foregroundStyle(BrewweryColor.foreground)
                                if !diagnostic.message.isEmpty {
                                    Text(diagnostic.message)
                                        .font(BrewweryFont.body)
                                        .foregroundStyle(BrewweryColor.mutedForeground)
                                        .lineSpacing(4)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: Metrics.tightSpacing)
                            BrewweryBadge(text: diagnostic.severity.rawValue, tone: tone(for: diagnostic.severity))
                        }
                    }
                }
            }

            if let output = result.rawOutput {
                OutputDisclosure(label: "Show raw output", content: output, maxHeight: 320)
            }
        }
    }

    private func tone(for severity: DoctorSeverity) -> BrewweryBadge.Tone {
        switch severity {
        case .warning: .warning
        case .error: .danger
        case .info: .info
        }
    }
}

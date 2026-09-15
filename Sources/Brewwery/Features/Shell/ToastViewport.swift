import SwiftUI

/// `components/ui/toast-viewport.tsx` — up to three stacked notifications above the status
/// bar, each dismissed automatically after 4.2 s.
struct ToastViewport: View {
    @Environment(AppEnvironment.self) private var brewwery

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
            ForEach(brewwery.state.toasts) { toast in
                ToastRow(toast: toast) { brewwery.state.dismiss(toast.id) }
            }
        }
        .frame(width: 360)
        .padding(.trailing, Metrics.cardSpacing)
        .padding(.bottom, Metrics.statusBarHeight + Metrics.rowSpacing)
        .animation(.spring(duration: 0.25), value: brewwery.state.toasts)
    }
}

private struct ToastRow: View {
    let toast: Toast
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.rowSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(BrewweryFont.controlLabel)
                    .foregroundStyle(BrewweryColor.foreground)
                    .lineLimit(1)
                if let description = toast.description {
                    Text(description)
                        .font(BrewweryFont.caption)
                        .foregroundStyle(BrewweryColor.mutedForeground)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BrewweryColor.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(Metrics.rowSpacing)
        .background(.regularMaterial)
        .background(BrewweryColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .shadow(color: BrewweryColor.panelShadow, radius: 25, x: 0, y: 16)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch toast.tone {
        case .success: "checkmark.circle"
        case .error: "xmark.circle"
        case .info: "info.circle"
        }
    }

    private var tint: Color {
        switch toast.tone {
        case .success: BrewweryColor.success
        case .error: BrewweryColor.danger
        case .info: BrewweryColor.accent
        }
    }

    private var border: Color {
        switch toast.tone {
        case .success: BrewweryColor.successBorder
        case .error: BrewweryColor.dangerBorder
        case .info: BrewweryColor.border
        }
    }
}

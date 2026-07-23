import SwiftUI

struct OverlayView: View {
    let state: StatusOverlayController.State

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .shadow(radius: 8, y: 2)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .working:
            ProgressView()
                .controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var message: String {
        switch state {
        case .working: return String(localized: "Rephrasing…")
        case .success: return String(localized: "Done")
        case .failure(let detail): return detail
        }
    }
}

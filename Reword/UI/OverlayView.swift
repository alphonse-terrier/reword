import AppKit
import SwiftUI

struct OverlayView: View {
    let state: StatusOverlayController.State
    var onClose: () -> Void = {}

    @State private var justCopied = false

    var body: some View {
        switch state {
        case .working, .success, .failure:
            statusBadge
        case .result(let text):
            resultPanel(text: text)
        }
    }

    // MARK: - Transient status badge (working/success/failure)

    private var statusBadge: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusMessage)
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
        .accessibilityLabel(Text(statusMessage))
    }

    @ViewBuilder
    private var statusIcon: some View {
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
        case .result:
            EmptyView()
        }
    }

    private var statusMessage: String {
        switch state {
        case .working: return String(localized: "Rephrasing…")
        case .success: return String(localized: "Done")
        case .failure(let detail): return detail
        case .result: return ""
        }
    }

    // MARK: - Read-only result panel (interactive, stays open)

    private func resultPanel(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Read-only — copy the result manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 320)
            .frame(maxHeight: 400)

            Button(action: copy) {
                Label(justCopied ? String(localized: "Copied") : String(localized: "Copy"), systemImage: justCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .shadow(radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if case .result(let text) = state {
            pasteboard.setString(text, forType: .string)
        }
        justCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            justCopied = false
        }
    }
}

import SwiftUI

struct ConsoleView: View {
    @StateObject private var logger = AppLogger.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Developer Console")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Button("Clear") { logger.clear() }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))

            Divider().background(Color.green.opacity(0.3))

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logger.logs.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: logger.logs.count) { _, _ in
                    if let last = logger.logs.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

    private func color(for line: String) -> Color {
        if line.contains("❌") { return .red }
        if line.contains("⚠️") { return Color(red: 1, green: 0.8, blue: 0) }
        if line.contains("✅") { return .green }
        return Color.green.opacity(0.85)
    }
}

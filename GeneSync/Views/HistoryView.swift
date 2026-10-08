import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var session: GeneSyncSession
    var onRestore: () -> Void = {}

    var body: some View {
        PageScaffold(title: "Saved History", subtitle: "Recent local alignment runs.") {
            if session.history.isEmpty {
                EmptyStateView(
                    title: "History is empty",
                    message: "Completed alignments are saved locally on this device.",
                    symbol: "clock.badge.questionmark"
                )
            } else {
                ForEach(session.history) { summary in
                    Button {
                        session.restore(summary)
                        onRestore()
                    } label: {
                        HistorySummaryCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    session.clearHistory()
                } label: {
                    Label("Clear history", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }
}

private struct HistorySummaryCard: View {
    let summary: RunSummary

    var body: some View {
        SurfacePanel {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(summary.createdAt.shortGeneSyncFormat)
                            .font(GeneSyncTheme.body(15, weight: .semibold))
                            .foregroundStyle(GeneSyncTheme.text)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(GeneSyncTheme.secondaryText)
                    }

                    HStack {
                        Chip(text: summary.kind.rawValue)
                        Chip(text: "Score \(summary.score)")
                        Chip(text: summary.identity.percentageString, foreground: GeneSyncTheme.success, background: GeneSyncTheme.success.opacity(0.12))
                    }

                    Text("\(summary.sequenceA.prefix(36)) / \(summary.sequenceB.prefix(36))")
                        .font(GeneSyncTheme.mono(12))
                        .foregroundStyle(GeneSyncTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}

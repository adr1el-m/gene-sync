import SwiftUI

struct LearnView: View {
    var body: some View {
        PageScaffold(title: "Algorithm Guide", subtitle: "GeneSync project paper notes.") {
            SurfacePanel {
                SectionHeading(title: "Needleman-Wunsch Core", symbol: "function")

                Text("F(i,j) stores the best global alignment score for the first i symbols of Sequence A and the first j symbols of Sequence B.")
                    .font(GeneSyncTheme.body(14))
                    .foregroundStyle(GeneSyncTheme.text)

                Text("F(i,j) = max(diagonal + substitution, up + gap, left + gap)")
                    .font(GeneSyncTheme.mono(13, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GeneSyncTheme.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            SurfacePanel {
                SectionHeading(title: "System Phases", symbol: "square.stack.3d.up")

                GuideRow(title: "Ingestion and Validation", detail: "FASTA headers, whitespace, and numbers are cleaned before alphabet validation.")
                GuideRow(title: "Algorithmic Execution", detail: "The app initializes the matrix, fills every DP cell, and records traceback moves.")
                GuideRow(title: "Analytics and Reporting", detail: "Identity, Monte Carlo shuffling, and sliding-window hotspot density are computed from the final alignment.")
                GuideRow(title: "Presentation Layer", detail: "Matrix cells, traceback path, aligned strings, and diagnostics are rendered for review.")
            }

            SurfacePanel {
                SectionHeading(title: "Boundaries", symbol: "ruler")

                GuideRow(title: "Complexity", detail: "O(m x n) time and O(m x n) space because the full matrix is retained for visualization.")
                GuideRow(title: "Input cap", detail: "Each sequence accepts up to 5,000 biological characters.")
                GuideRow(title: "Accepted alphabets", detail: "DNA: A T C G N. RNA: A U C G. Protein: 20 standard amino acid letters.")
            }
        }
    }
}

private struct GuideRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(GeneSyncTheme.body(15, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.text)

            Text(detail)
                .font(GeneSyncTheme.body(13))
                .foregroundStyle(GeneSyncTheme.secondaryText)
        }
        .padding(.vertical, 5)
    }
}

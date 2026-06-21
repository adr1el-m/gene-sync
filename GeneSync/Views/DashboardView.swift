import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var session: GeneSyncSession

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 165), spacing: 12)]
    }

    var body: some View {
        PageScaffold(
            title: "GeneSync",
            subtitle: "Needleman-Wunsch global alignment for DNA, RNA, and protein pairs."
        ) {
            SurfacePanel {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(GeneSyncTheme.primary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Analyze biological sequence similarity")
                            .font(GeneSyncTheme.headline(24))
                            .foregroundStyle(GeneSyncTheme.text)

                        Text("Prepare a sequence pair, run global alignment, inspect the dynamic programming grid, and review curated marker annotations.")
                            .font(GeneSyncTheme.body(14))
                            .foregroundStyle(GeneSyncTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Chip(text: "Needleman-Wunsch")
                        Chip(text: session.kind.rawValue)
                        Chip(text: "iOS Ready")
                    }
                }
            }

            LazyVGrid(columns: actionColumns, spacing: 12) {
                HomeActionCard(
                    title: "Input Sequences",
                    detail: "Paste or edit DNA, RNA, or protein pairs.",
                    symbol: "text.cursor"
                ) {
                    AlignView()
                }

                HomeActionCard(
                    title: "Matrix Playback",
                    detail: "Watch the DP traceback path step by step.",
                    symbol: "tablecells"
                ) {
                    MatrixView()
                }

                HomeActionCard(
                    title: "View Results",
                    detail: "Read score, identity, hotspots, and reports.",
                    symbol: "chart.bar.xaxis"
                ) {
                    ResultsView()
                }

                HomeActionCard(
                    title: "Algorithm Guide",
                    detail: "Review recurrence, validation, and complexity.",
                    symbol: "book.closed"
                ) {
                    LearnView()
                }
            }

            SurfacePanel {
                SectionHeading(title: "About the App", symbol: "info.circle")

                Text("GeneSync turns the Needleman-Wunsch algorithm into an interactive mobile workflow for learning and reviewing global pairwise alignment.")
                    .font(GeneSyncTheme.body(14))
                    .foregroundStyle(GeneSyncTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use the Align tab for computation, Matrix for traceback playback, Results for curated marker interpretation, and History for saved local runs.")
                    .font(GeneSyncTheme.body(13))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SurfacePanel {
                SectionHeading(title: "Validation Sources", symbol: "checklist.checked")

                Text("GeneSync uses a small curated marker database backed by HGVS, reference-context checks, Ensembl VEP, and ClinVar. Matched records become known variant results; unmatched differences remain candidates.")
                    .font(GeneSyncTheme.body(13))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                    ValidationSourceTile(name: "HGVS", detail: "Variant naming")
                    ValidationSourceTile(name: "Reference Context", detail: "Local motif match")
                    ValidationSourceTile(name: "Ensembl VEP", detail: "Predicted effect")
                    ValidationSourceTile(name: "ClinVar", detail: "Clinical evidence")
                }
            }

            SurfacePanel {
                SectionHeading(title: "Workflow", symbol: "point.3.connected.trianglepath.dotted")

                VStack(spacing: 0) {
                    PipelineRow(number: 1, title: "Prepare", detail: "Clean sequence input and validate sequence alphabet")
                    PipelineRow(number: 2, title: "Align", detail: "Fill the global alignment dynamic programming matrix")
                    PipelineRow(number: 3, title: "Trace", detail: "Play the traceback from terminal cell to origin")
                    PipelineRow(number: 4, title: "Interpret", detail: "Review identity, hotspots, shuffle significance, and report")
                }
            }
        }
        .alert("Alignment Error", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK") {
                session.errorMessage = nil
            }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }
}

private struct ValidationSourceTile: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(GeneSyncTheme.body(13, weight: .bold))
                .foregroundStyle(GeneSyncTheme.primary)

            Text(detail)
                .font(GeneSyncTheme.body(11))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(GeneSyncTheme.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }
}

private struct HomeActionCard<Destination: View>: View {
    let title: String
    let detail: String
    let symbol: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(GeneSyncTheme.body(16, weight: .semibold))
                        .foregroundStyle(GeneSyncTheme.text)

                    Text(detail)
                        .font(GeneSyncTheme.body(12))
                        .foregroundStyle(GeneSyncTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .frame(minHeight: 132, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeneSyncTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(GeneSyncTheme.outline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PipelineRow: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(GeneSyncTheme.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(GeneSyncTheme.body(15, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.text)

                Text(detail)
                    .font(GeneSyncTheme.body(13))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

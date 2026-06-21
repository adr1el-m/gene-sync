import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var session: GeneSyncSession
    @State private var reportURL: URL?
    @State private var jsonURL: URL?
    @State private var exportError: String?

    var body: some View {
        PageScaffold(title: "Alignment Results", subtitle: "Optimal alignment, identity, significance, and hotspots.") {
            if let result = session.result {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Score", value: "\(result.score)", detail: "Needleman-Wunsch")
                    MetricTile(title: "Identity", value: result.identity.percentageString, detail: "Alignment matches", tint: GeneSyncTheme.success)
                    MetricTile(title: "P Value", value: String(format: "%.3f", result.significance.pValue), detail: "\(result.significance.iterations) shuffles", tint: result.significance.significant ? GeneSyncTheme.success : GeneSyncTheme.warning)
                    MetricTile(title: "Runtime", value: String(format: "%.2fs", result.duration), detail: "\(result.rows * result.columns) cells")
                }

                SurfacePanel {
                    SectionHeading(title: "Aligned Strings", symbol: "text.alignleft")
                    AlignmentComparisonView(result: result)
                }

                SurfacePanel {
                    VariantResultPanel(result: result)
                }

                SurfacePanel {
                    SectionHeading(title: "Significance Assessment", symbol: "chart.xyaxis.line")

                    VStack(spacing: 10) {
                        ResultRow(title: "Requested shuffles", value: "\(result.significance.requestedIterations)")
                        ResultRow(title: "Effective shuffles", value: "\(result.significance.iterations)")
                        ResultRow(title: "Mean shuffled score", value: String(format: "%.2f", result.significance.meanScore))
                        ResultRow(title: "Standard deviation", value: String(format: "%.2f", result.significance.standardDeviation))
                        ResultRow(title: "Z score", value: String(format: "%.2f", result.significance.zScore))
                        ResultRow(title: "Assessment", value: result.significance.significant ? "Significant" : "Needs review")
                    }
                }

                SurfacePanel {
                    SectionHeading(title: "Hotspots Report", symbol: "flame")

                    HotspotMap(result: result)

                    if result.hotspots.isEmpty {
                        Text("No windows crossed the selected density threshold.")
                            .font(GeneSyncTheme.body(14))
                            .foregroundStyle(GeneSyncTheme.secondaryText)
                    } else {
                        ForEach(result.hotspots) { hotspot in
                            HotspotRow(hotspot: hotspot)
                        }
                    }
                }

                SurfacePanel {
                    SectionHeading(title: "Exportable Output", symbol: "square.and.arrow.up")

                    Text("Generate a printable PDF or a JSON analysis payload with aligned strings, matrix states, traceback, variants, hotspots, and significance.")
                        .font(GeneSyncTheme.body(13))
                        .foregroundStyle(GeneSyncTheme.secondaryText)

                    VStack(spacing: 10) {
                        Button {
                            do {
                                reportURL = try ReportExporter.makePDF(result: result)
                            } catch {
                                exportError = error.localizedDescription
                            }
                        } label: {
                            Label("Prepare PDF", systemImage: "doc.richtext")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GeneSyncTheme.primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(GeneSyncTheme.primary, lineWidth: 1)
                        }

                        if let reportURL {
                            ShareLink(item: reportURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(GeneSyncTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }

                        Button {
                            do {
                                jsonURL = try ReportExporter.makeJSON(result: result)
                            } catch {
                                exportError = error.localizedDescription
                            }
                        } label: {
                            Label("Prepare JSON Payload", systemImage: "curlybraces.square")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GeneSyncTheme.primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(GeneSyncTheme.primary, lineWidth: 1)
                        }

                        if let jsonURL {
                            ShareLink(item: jsonURL) {
                                Label("Share JSON", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(GeneSyncTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            } else {
                EmptyStateView(
                    title: "No result yet",
                    message: "Run an alignment to inspect the optimal strings and diagnostics.",
                    symbol: "chart.bar.doc.horizontal"
                )
            }
        }
        .onChange(of: session.result?.id) {
            reportURL = nil
            jsonURL = nil
            exportError = nil
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "")
        }
    }
}

private struct VariantResultPanel: View {
    let result: AlignmentResult

    private var hasMarkers: Bool {
        !result.markerAnnotations.isEmpty
    }

    private var title: String {
        if hasMarkers {
            return "Known Variant Result"
        }

        return result.variantCandidates.isEmpty ? "Variant Result" : "Variant Candidates"
    }

    private var note: String {
        if hasMarkers {
            return "GeneSync matched the submitted alignment to a curated marker pattern and reports a definite known-marker result for these strings."
        }

        if result.variantCandidates.isEmpty {
            return "GeneSync found no mismatches or gaps in the submitted alignment."
        }

        return "GeneSync found definite alignment differences. Unmatched rows stay as candidates until a curated marker pattern is available."
    }

    private var interpretation: VariantInterpretation {
        VariantInterpretation(result: result)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: title, symbol: hasMarkers ? "checkmark.seal" : "waveform.path.ecg")

            Text(note)
                .font(GeneSyncTheme.body(13))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ValidationSourceGrid()

            if result.variantCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No candidate variation detected.")
                        .font(GeneSyncTheme.body(15, weight: .semibold))
                        .foregroundStyle(GeneSyncTheme.text)

                    Text("GeneSync found no mismatches or gaps in the submitted alignment.")
                        .font(GeneSyncTheme.body(13))
                        .foregroundStyle(GeneSyncTheme.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GeneSyncTheme.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(GeneSyncTheme.outline, lineWidth: 1)
                }
            } else {
                InterpretationCard(interpretation: interpretation)

                ForEach(result.markerAnnotations) { marker in
                    MarkerAnnotationCard(marker: marker)
                }

                CandidateSummaryView(candidates: result.variantCandidates)
            }
        }
    }
}

private struct VariantInterpretation {
    let title: String
    let body: String
    let call: String
    let confidence: String
    let status: String

    init(result: AlignmentResult) {
        let substitutions = result.variantCandidates.filter { $0.kind == .substitution }.count
        let insertions = result.variantCandidates.filter { $0.kind == .insertion }.count
        let deletions = result.variantCandidates.filter { $0.kind == .deletion }.count
        var parts: [String] = []

        if substitutions > 0 {
            parts.append("\(substitutions) substitution\(substitutions == 1 ? "" : "s")")
        }

        if insertions > 0 {
            parts.append("\(insertions) insertion\(insertions == 1 ? "" : "s")")
        }

        if deletions > 0 {
            parts.append("\(deletions) deletion\(deletions == 1 ? "" : "s")")
        }

        let differenceSummary = parts.joined(separator: ", ")

        if !result.markerAnnotations.isEmpty {
            title = "Definite known marker result"
            body = "GeneSync found \(differenceSummary) and matched the change against GeneSync's curated marker database. The alignment event and marker annotation below explain the gene, nucleotide call, protein effect, and validation evidence."
            call = result.markerAnnotations.map(\.variantName).joined(separator: ", ")
            confidence = "Definite known-marker match for the submitted strings"
            status = "Curated database marker matched"
        } else {
            title = "Definite alignment difference detected"
            body = "GeneSync found \(differenceSummary) between Sequence A and Sequence B. This is a definite difference in the submitted strings, but GeneSync did not match it to a curated marker database record."
            call = differenceSummary
            confidence = "Definite alignment difference only"
            status = "Not found in the current local marker database"
        }
    }
}

private struct ValidationSourceGrid: View {
    private let sources: [(name: String, detail: String)] = [
        ("HGVS", "Standard variant naming"),
        ("Reference Context", "Local curated motif match"),
        ("Ensembl VEP", "Predicted variant effect"),
        ("ClinVar", "Clinical evidence for curated records")
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            ForEach(sources.indices, id: \.self) { index in
                let source = sources[index]

                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(GeneSyncTheme.body(13, weight: .bold))
                        .foregroundStyle(GeneSyncTheme.primary)

                    Text(source.detail)
                        .font(GeneSyncTheme.body(11))
                        .foregroundStyle(GeneSyncTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                .background(GeneSyncTheme.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(GeneSyncTheme.outline, lineWidth: 1)
                }
            }
        }
    }
}

private struct InterpretationCard: View {
    let interpretation: VariantInterpretation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(interpretation.title)
                .font(GeneSyncTheme.body(16, weight: .bold))
                .foregroundStyle(GeneSyncTheme.primary)

            Text(interpretation.body)
                .font(GeneSyncTheme.body(13))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ResultRow(title: "Alignment call", value: interpretation.call)
                ResultRow(title: "Confidence", value: interpretation.confidence)
                ResultRow(title: "Biological status", value: interpretation.status)
            }
        }
        .padding(12)
        .background(resultBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }

    private var resultBackground: Color {
        interpretation.status.contains("Curated") ? GeneSyncTheme.success.opacity(0.08) : GeneSyncTheme.surfaceLow
    }
}

private struct MarkerAnnotationCard: View {
    let marker: KnownMarkerAnnotation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(marker.callType.uppercased())
                    .font(GeneSyncTheme.body(11, weight: .bold))
                    .foregroundStyle(GeneSyncTheme.primary)

                Text(marker.variantName)
                    .font(GeneSyncTheme.body(16, weight: .bold))
                    .foregroundStyle(GeneSyncTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(marker.confidence)
                    .font(GeneSyncTheme.body(13))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ResultRow(title: "Organism", value: marker.organism)
                ResultRow(title: "Gene", value: marker.gene)
                ResultRow(title: "Database match", value: marker.databaseMatch)
                ResultRow(title: "Nucleotide", value: marker.nucleotideChange)
                ResultRow(title: "Codon", value: marker.codon)
                ResultRow(title: "Protein", value: marker.protein)
                ResultRow(title: "Detected position", value: marker.position)
                ResultRow(title: "Local context", value: marker.localContext)
                ResultRow(title: "Interpretation", value: marker.interpretation)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                ForEach(marker.sourceFindings) { evidence in
                    EvidenceCard(evidence: evidence)
                }
            }
        }
        .padding(12)
        .background(GeneSyncTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.primary.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct EvidenceCard: View {
    let evidence: MarkerEvidence

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(evidence.name)
                .font(GeneSyncTheme.body(13, weight: .bold))
                .foregroundStyle(GeneSyncTheme.primary)

            Text(evidence.status)
                .font(GeneSyncTheme.body(11, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.text)

            Text(evidence.detail)
                .font(GeneSyncTheme.body(11))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GeneSyncTheme.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }
}

private struct CandidateSummaryView: View {
    let candidates: [VariantCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(candidates.count)")
                    .font(GeneSyncTheme.mono(19, weight: .bold))
                    .foregroundStyle(GeneSyncTheme.primary)

                Text("\(candidates.count == 1 ? "difference" : "differences") detected by Needleman-Wunsch traceback.")
                    .font(GeneSyncTheme.body(13))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(candidates) { candidate in
                CandidateRow(candidate: candidate)
            }
        }
        .padding(12)
        .background(GeneSyncTheme.success.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.success.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct CandidateRow: View {
    let candidate: VariantCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.kind.title)
                        .font(GeneSyncTheme.body(14, weight: .semibold))
                        .foregroundStyle(GeneSyncTheme.text)

                    Text(candidate.referencePosition)
                        .font(GeneSyncTheme.mono(12, weight: .semibold))
                        .foregroundStyle(GeneSyncTheme.secondaryText)
                }

                Spacer(minLength: 12)

                Text("\(candidate.reference) -> \(candidate.variant)")
                    .font(GeneSyncTheme.mono(13, weight: .bold))
                    .foregroundStyle(GeneSyncTheme.primary)
                    .multilineTextAlignment(.trailing)
            }

            Text(alignmentEvidence)
                .font(GeneSyncTheme.body(12))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(candidate.validationBasis)
                .font(GeneSyncTheme.body(11))
                .foregroundStyle(GeneSyncTheme.secondaryText.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(GeneSyncTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }

    private var alignmentEvidence: String {
        switch candidate.kind {
        case .substitution:
            return "\(candidate.reference) is aligned directly against \(candidate.variant) at the same column."
        case .insertion:
            return "\(candidate.variant) appears opposite a gap in Sequence A."
        case .deletion:
            return "\(candidate.reference) appears opposite a gap in Sequence B."
        }
    }
}

private struct AlignmentComparisonView: View {
    let result: AlignmentResult

    private var columns: [AlignmentColumn] {
        Array(zip(result.alignedA, result.alignedB).enumerated()).map { index, pair in
            AlignmentColumn(index: index + 1, top: pair.0, bottom: pair.1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                LegendPill(title: "Match", tint: GeneSyncTheme.success)
                LegendPill(title: "Mismatch", tint: GeneSyncTheme.warning)
                LegendPill(title: "Gap", tint: GeneSyncTheme.error)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .center, spacing: 4) {
                    ForEach(columns) { column in
                        AlignmentColumnView(column: column)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .background(GeneSyncTheme.monoBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(GeneSyncTheme.outline, lineWidth: 1)
            }
        }
    }
}

private struct AlignmentColumn: Identifiable {
    let index: Int
    let top: Character
    let bottom: Character

    var id: Int { index }

    var state: AlignmentColumnState {
        if top == "-" || bottom == "-" {
            return .gap
        }

        return top == bottom ? .match : .mismatch
    }
}

private enum AlignmentColumnState {
    case match
    case mismatch
    case gap

    var tint: Color {
        switch self {
        case .match:
            return GeneSyncTheme.success
        case .mismatch:
            return GeneSyncTheme.warning
        case .gap:
            return GeneSyncTheme.error
        }
    }

    var symbol: String {
        switch self {
        case .match:
            return "|"
        case .mismatch:
            return "•"
        case .gap:
            return "−"
        }
    }

    var label: String {
        switch self {
        case .match:
            return "Match"
        case .mismatch:
            return "Mismatch"
        case .gap:
            return "Gap"
        }
    }
}

private struct AlignmentColumnView: View {
    let column: AlignmentColumn

    var body: some View {
        VStack(spacing: 4) {
            Text(String(column.top))
                .font(GeneSyncTheme.mono(15, weight: .bold))
                .foregroundStyle(GeneSyncTheme.text)
                .frame(width: 30, height: 28)
                .background(cellBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(cellBorder)

            ConnectorView(state: column.state)
                .frame(width: 30, height: 34)
                .accessibilityLabel(column.state.label)

            Text(String(column.bottom))
                .font(GeneSyncTheme.mono(15, weight: .bold))
                .foregroundStyle(GeneSyncTheme.text)
                .frame(width: 30, height: 28)
                .background(cellBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(cellBorder)

            Text("\(column.index)")
                .font(GeneSyncTheme.mono(9, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.secondaryText.opacity(0.75))
        }
        .frame(width: 34)
    }

    private var cellBackground: Color {
        column.state == .match ? GeneSyncTheme.success.opacity(0.10) : GeneSyncTheme.surface
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(column.state.tint.opacity(0.34), lineWidth: 1)
    }
}

private struct ConnectorView: View {
    let state: AlignmentColumnState

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let top = CGPoint(x: midX, y: 1)
            let bottom = CGPoint(x: midX, y: size.height - 1)
            let color = state.tint

            switch state {
            case .match:
                var path = Path()
                path.move(to: top)
                path.addLine(to: bottom)
                context.stroke(path, with: .color(color), lineWidth: 2)

                context.fill(
                    Path(ellipseIn: CGRect(x: midX - 3, y: 0, width: 6, height: 6)),
                    with: .color(color)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: midX - 3, y: size.height - 6, width: 6, height: 6)),
                    with: .color(color)
                )
            case .mismatch:
                var path = Path()
                path.move(to: top)
                path.addLine(to: CGPoint(x: midX + 7, y: size.height / 2))
                path.addLine(to: bottom)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, dash: [4, 3]))
            case .gap:
                var path = Path()
                path.move(to: CGPoint(x: midX - 9, y: size.height / 2))
                path.addLine(to: CGPoint(x: midX + 9, y: size.height / 2))
                context.stroke(path, with: .color(color), lineWidth: 2.4)

                var pointer = Path()
                pointer.move(to: top)
                pointer.addLine(to: CGPoint(x: midX, y: size.height / 2 - 4))
                pointer.move(to: bottom)
                pointer.addLine(to: CGPoint(x: midX, y: size.height / 2 + 4))
                context.stroke(pointer, with: .color(color.opacity(0.75)), lineWidth: 1.2)
            }
        }
        .overlay {
            Text(state.symbol)
                .font(GeneSyncTheme.mono(13, weight: .bold))
                .foregroundStyle(state.tint)
                .padding(3)
                .background(GeneSyncTheme.monoBackground)
        }
    }
}

private struct LegendPill: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct ResultRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(GeneSyncTheme.body(14))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .frame(minWidth: 105, alignment: .leading)
            Spacer()
            Text(value)
                .font(GeneSyncTheme.mono(14, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.text)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HotspotRow: View {
    let hotspot: Hotspot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Positions \(hotspot.start)-\(hotspot.end)")
                    .font(GeneSyncTheme.body(15, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.text)

                Spacer()

                Text(hotspot.density.percentageString)
                    .font(GeneSyncTheme.mono(13, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.warning)
            }

            HStack {
                Chip(text: "\(hotspot.gaps) gaps", foreground: GeneSyncTheme.secondary, background: GeneSyncTheme.secondary.opacity(0.12))
                Chip(text: "\(hotspot.mismatches) mismatches", foreground: GeneSyncTheme.warning, background: GeneSyncTheme.warning.opacity(0.12))
            }
        }
        .padding(.vertical, 8)
    }
}

private struct HotspotMap: View {
    let result: AlignmentResult

    private var positions: [Bool] {
        let length = result.alignedA.count
        var flags = Array(repeating: false, count: length)

        for hotspot in result.hotspots {
            for index in max(0, hotspot.start - 1)..<min(length, hotspot.end) {
                flags[index] = true
            }
        }

        return flags
    }

    var body: some View {
        GeometryReader { proxy in
            let flags = positions
            let width = max(proxy.size.width / CGFloat(max(flags.count, 1)), 2)

            HStack(spacing: 1) {
                ForEach(flags.indices, id: \.self) { index in
                    Rectangle()
                        .fill(flags[index] ? GeneSyncTheme.warning : GeneSyncTheme.outline.opacity(0.45))
                        .frame(width: width)
                }
            }
        }
        .frame(height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }
}

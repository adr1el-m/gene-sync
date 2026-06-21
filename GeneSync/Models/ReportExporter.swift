import Foundation

#if canImport(UIKit)
import UIKit

enum ReportExporter {
    static func makePDF(result: AlignmentResult) throws -> URL {
        let fileName = "GeneSync-\(result.id.uuidString.prefix(8)).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: outputURL) { context in
            context.beginPage()

            let margin: CGFloat = 44
            var cursorY: CGFloat = margin
            let contentWidth = pageBounds.width - (margin * 2)

            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacing: CGFloat = 8) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let rect = NSString(string: text).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )

                if cursorY + rect.height > pageBounds.height - margin {
                    context.beginPage()
                    cursorY = margin
                }

                NSString(string: text).draw(
                    with: CGRect(x: margin, y: cursorY, width: contentWidth, height: rect.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                cursorY += rect.height + spacing
            }

            draw("GeneSync Alignment Report", font: .boldSystemFont(ofSize: 24), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw("Generated \(result.createdAt.formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 11), color: .darkGray, spacing: 18)

            draw("Summary", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw("Type: \(result.kind.rawValue)\nScore: \(result.score)\nIdentity: \(String(format: "%.2f", result.identity))%\nMatrix: \(result.rows) x \(result.columns)\nTraceback steps: \(result.tracebackPath.count)\nRuntime: \(String(format: "%.3f", result.duration)) seconds", font: .systemFont(ofSize: 12))

            draw("Variant Result", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw(variantSummary(result), font: .systemFont(ofSize: 12))

            draw("Scoring Profile", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw("Match: \(result.scoring.match)\nMismatch: \(result.scoring.mismatch)\nGap: \(result.scoring.gap)", font: .systemFont(ofSize: 12))

            draw("Significance", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw("Requested shuffles: \(result.significance.requestedIterations)\nEffective shuffles: \(result.significance.iterations)\nMean shuffled score: \(String(format: "%.2f", result.significance.meanScore))\nStandard deviation: \(String(format: "%.2f", result.significance.standardDeviation))\nZ score: \(String(format: "%.2f", result.significance.zScore))\nP value: \(String(format: "%.4f", result.significance.pValue))\nAssessment: \(result.significance.significant ? "Significant" : "Needs review")", font: .systemFont(ofSize: 12))

            draw("Aligned Sequences", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            draw("A  \(wrapped(result.alignedA))\n   \(wrapped(result.matchLine))\nB  \(wrapped(result.alignedB))", font: .monospacedSystemFont(ofSize: 9, weight: .regular))

            draw("Hotspots", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.40, green: 0.00, blue: 0.00, alpha: 1))
            if result.hotspots.isEmpty {
                draw("No windows crossed the selected density threshold.", font: .systemFont(ofSize: 12))
            } else {
                let hotspotText = result.hotspots.map { hotspot in
                    "Positions \(hotspot.start)-\(hotspot.end): density \(String(format: "%.1f", hotspot.density * 100))%, gaps \(hotspot.gaps), mismatches \(hotspot.mismatches)"
                }
                .joined(separator: "\n")
                draw(hotspotText, font: .systemFont(ofSize: 12))
            }
        }

        return outputURL
    }

    static func makeJSON(result: AlignmentResult) throws -> URL {
        let fileName = "GeneSync-\(result.id.uuidString.prefix(8)).json"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let payload = AlignmentExportPayload(result: result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func variantSummary(_ result: AlignmentResult) -> String {
        if result.variantCandidates.isEmpty {
            return "No candidate variation detected."
        }

        let markerText = result.markerAnnotations.map { marker in
            """
            Known marker: \(marker.variantName)
            Organism: \(marker.organism)
            Gene: \(marker.gene)
            Database match: \(marker.databaseMatch)
            Nucleotide: \(marker.nucleotideChange)
            Codon: \(marker.codon)
            Protein: \(marker.protein)
            Detected position: \(marker.position)
            Local context: \(marker.localContext)
            Interpretation: \(marker.interpretation)
            Evidence: \(marker.sourceFindings.map { "\($0.name) - \($0.status)" }.joined(separator: "; "))
            """
        }
        .joined(separator: "\n\n")

        let candidateText = result.variantCandidates.map { candidate in
            "\(candidate.id). \(candidate.kind.title), \(candidate.referencePosition), \(candidate.reference) -> \(candidate.variant)"
        }
        .joined(separator: "\n")

        if markerText.isEmpty {
            return "Definite alignment difference detected, but no curated marker database record matched.\n\n\(candidateText)"
        }

        return "Definite known marker result. GeneSync matched the alignment against its curated marker database.\n\n\(markerText)\n\nAlignment differences:\n\(candidateText)"
    }

    private static func wrapped(_ value: String, width: Int = 72) -> String {
        guard value.count > width else {
            return value
        }

        var lines: [String] = []
        var start = value.startIndex

        while start < value.endIndex {
            let end = value.index(start, offsetBy: width, limitedBy: value.endIndex) ?? value.endIndex
            lines.append(String(value[start..<end]))
            start = end
        }

        return lines.joined(separator: "\n")
    }
}
#endif

private struct AlignmentExportPayload: Codable {
    let id: UUID
    let createdAt: Date
    let sequenceType: SequenceKind
    let sequenceA: String
    let sequenceB: String
    let scoring: ScoringProfile
    let score: Int
    let identity: Double
    let alignedA: String
    let alignedB: String
    let matchLine: String
    let matrixRows: Int
    let matrixColumns: Int
    let matrix: [Int32]
    let moves: [UInt8]
    let tracebackPath: [TraceCoordinate]
    let variantCandidates: [VariantCandidate]
    let markerAnnotations: [KnownMarkerAnnotation]
    let hotspots: [Hotspot]
    let significance: SignificanceReport
    let duration: TimeInterval

    init(result: AlignmentResult) {
        id = result.id
        createdAt = result.createdAt
        sequenceType = result.kind
        sequenceA = result.sequenceA
        sequenceB = result.sequenceB
        scoring = result.scoring
        score = result.score
        identity = result.identity
        alignedA = result.alignedA
        alignedB = result.alignedB
        matchLine = result.matchLine
        matrixRows = result.rows
        matrixColumns = result.columns
        matrix = result.matrix
        moves = result.moves
        tracebackPath = result.tracebackPath
        variantCandidates = result.variantCandidates
        markerAnnotations = result.markerAnnotations
        hotspots = result.hotspots
        significance = result.significance
        duration = result.duration
    }
}

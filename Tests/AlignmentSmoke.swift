import Foundation

@main
struct AlignmentSmoke {
    static func main() throws {
        let result = try AlignmentEngine.align(
            sequenceA: ">Reference\nGATTACA",
            sequenceB: ">Variant\nGTCGACG",
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 10
        )

        precondition(result.alignedA.count == result.alignedB.count)
        precondition(result.score == result.matrixScore(row: result.rows - 1, column: result.columns - 1))
        precondition(result.tracebackPath.first == TraceCoordinate(row: 0, column: 0))
        precondition(result.tracebackPath.last == TraceCoordinate(row: result.rows - 1, column: result.columns - 1))
        precondition(result.identity > 0)

        print("Alignment smoke test passed: score=\(result.score), identity=\(String(format: "%.1f", result.identity))%, hotspots=\(result.hotspots.count)")
    }
}

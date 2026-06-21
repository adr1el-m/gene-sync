import Foundation
import Combine

struct RunSummary: Codable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let sequenceA: String
    let sequenceB: String
    let kind: SequenceKind
    let scoring: ScoringProfile
    let hotspotWindow: Int
    let hotspotThreshold: Double
    let shuffleIterations: Int
    let score: Int
    let identity: Double
    let hotspotCount: Int
    let duration: TimeInterval

    init(result: AlignmentResult, hotspotWindow: Int, hotspotThreshold: Double, shuffleIterations: Int) {
        id = result.id
        createdAt = result.createdAt
        sequenceA = result.sequenceA
        sequenceB = result.sequenceB
        kind = result.kind
        scoring = result.scoring
        self.hotspotWindow = hotspotWindow
        self.hotspotThreshold = hotspotThreshold
        self.shuffleIterations = shuffleIterations
        score = result.score
        identity = result.identity
        hotspotCount = result.hotspots.count
        duration = result.duration
    }
}

@MainActor
final class GeneSyncSession: ObservableObject {
    @Published var sequenceA = "GATTACA"
    @Published var sequenceB = "GTCGACG"
    @Published var kind: SequenceKind = .dna
    @Published var scoring = ScoringProfile.standard
    @Published var hotspotWindow = 5
    @Published var hotspotThreshold = 0.40
    @Published var shuffleIterations = 100
    @Published private(set) var result: AlignmentResult?
    @Published private(set) var history: [RunSummary] = []
    @Published var isRunning = false
    @Published var errorMessage: String?

    private let historyKey = "genesync.run-history"

    init() {
        loadHistory()
    }

    var sanitizedSequenceA: String {
        SequenceSanitizer.sanitize(sequenceA)
    }

    var sanitizedSequenceB: String {
        SequenceSanitizer.sanitize(sequenceB)
    }

    var detectedKind: SequenceKind? {
        SequenceSanitizer.detectKind(sequenceA: sequenceA, sequenceB: sequenceB)
    }

    func applyDetectedKindIfPossible() {
        if let detectedKind {
            kind = detectedKind
        }
    }

    func loadSample(runImmediately: Bool = false) {
        errorMessage = nil
        kind = .dna
        scoring = .standard
        hotspotWindow = 5
        hotspotThreshold = 0.40
        shuffleIterations = 100
        sequenceA = "GATTACA"
        sequenceB = "GTCGACG"

        if runImmediately {
            runAlignment()
        }
    }

    func restore(_ summary: RunSummary) {
        sequenceA = summary.sequenceA
        sequenceB = summary.sequenceB
        kind = summary.kind
        scoring = summary.scoring
        hotspotWindow = summary.hotspotWindow
        hotspotThreshold = summary.hotspotThreshold
        shuffleIterations = summary.shuffleIterations
        runAlignment()
    }

    func runAlignment() {
        guard !isRunning else {
            return
        }

        let rawA = sequenceA
        let rawB = sequenceB
        applyDetectedKindIfPossible()

        let selectedKind = kind
        let selectedScoring = scoring
        let selectedWindow = hotspotWindow
        let selectedThreshold = hotspotThreshold
        let selectedIterations = shuffleIterations

        isRunning = true
        errorMessage = nil

        Task {
            do {
                let nextResult = try await Task.detached(priority: .userInitiated) {
                    try AlignmentEngine.align(
                        sequenceA: rawA,
                        sequenceB: rawB,
                        kind: selectedKind,
                        scoring: selectedScoring,
                        hotspotWindow: selectedWindow,
                        hotspotThreshold: selectedThreshold,
                        shuffleIterations: selectedIterations
                    )
                }
                .value

                result = nextResult
                saveSummary(
                    RunSummary(
                        result: nextResult,
                        hotspotWindow: selectedWindow,
                        hotspotThreshold: selectedThreshold,
                        shuffleIterations: selectedIterations
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }

            isRunning = false
        }
    }

    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func saveSummary(_ summary: RunSummary) {
        history.removeAll { existing in
            existing.sequenceA == summary.sequenceA &&
                existing.sequenceB == summary.sequenceB &&
                existing.kind == summary.kind &&
                existing.scoring == summary.scoring
        }
        history.insert(summary, at: 0)
        history = Array(history.prefix(20))

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([RunSummary].self, from: data) else {
            return
        }

        history = decoded
    }
}

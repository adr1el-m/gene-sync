import Foundation

enum SequenceKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case dna = "DNA"
    case rna = "RNA"
    case protein = "Protein"

    var id: String { rawValue }

    var allowedCharacters: Set<Character> {
        switch self {
        case .dna:
            return Set("ATCGN")
        case .rna:
            return Set("AUCG")
        case .protein:
            return Set("ACDEFGHIKLMNPQRSTVWY")
        }
    }
}

enum ProteinScoringMatrix: String, CaseIterable, Codable, Identifiable, Sendable {
    case simple = "Simple"
    case blosum62 = "BLOSUM62"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .simple:
            return "Use the match and mismatch values below."
        case .blosum62:
            return "Use a standard amino-acid substitution matrix."
        }
    }
}

struct ScoringProfile: Codable, Equatable, Sendable {
    var match: Int
    var mismatch: Int
    var gap: Int
    var proteinMatrix: ProteinScoringMatrix = .simple

    static let standard = ScoringProfile(match: 1, mismatch: -1, gap: -2)
}

enum AlignmentError: LocalizedError, Sendable {
    case emptySequence
    case sequenceTooLong(limit: Int)
    case invalidCharacters(String)
    case invalidScoring

    var errorDescription: String? {
        switch self {
        case .emptySequence:
            return "Both sequences must contain biological characters."
        case .sequenceTooLong(let limit):
            return "Each sequence is limited to \(limit) characters."
        case .invalidCharacters(let characters):
            return "Invalid characters for the selected sequence type: \(characters)"
        case .invalidScoring:
            return "The gap penalty should be negative and the match score should be higher than mismatch."
        }
    }
}

struct TraceCoordinate: Codable, Hashable, Sendable {
    let row: Int
    let column: Int
}

struct Hotspot: Codable, Identifiable, Sendable {
    let start: Int
    let end: Int
    let density: Double
    let gaps: Int
    let mismatches: Int

    var id: String { "\(start)-\(end)-\(gaps)-\(mismatches)" }
}

struct SignificanceReport: Codable, Sendable {
    let requestedIterations: Int
    let iterations: Int
    let meanScore: Double
    let standardDeviation: Double
    let zScore: Double
    let pValue: Double
    let significant: Bool
}

enum VariantCandidateKind: String, Codable, Sendable {
    case substitution = "Substitution"
    case insertion = "Insertion"
    case deletion = "Deletion"

    var title: String {
        switch self {
        case .substitution:
            return "Substitution candidate"
        case .insertion:
            return "Insertion candidate"
        case .deletion:
            return "Deletion candidate"
        }
    }
}

struct VariantCandidate: Codable, Identifiable, Sendable {
    let id: Int
    let kind: VariantCandidateKind
    let referencePosition: String
    let variantPosition: String
    let referenceStart: Int
    let reference: String
    let variant: String
    let validationBasis: String
}

struct MarkerEvidence: Codable, Identifiable, Sendable {
    let name: String
    let status: String
    let detail: String

    var id: String { "\(name)-\(status)" }
}

struct KnownMarkerAnnotation: Codable, Identifiable, Sendable {
    let id: String
    let organism: String
    let gene: String
    let variantName: String
    let callType: String
    let codon: String
    let protein: String
    let nucleotideChange: String
    let databaseMatch: String
    let interpretation: String
    let confidence: String
    let position: String
    let localContext: String
    let sourceFindings: [MarkerEvidence]
}

struct AlignmentResult: Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let sequenceA: String
    let sequenceB: String
    let kind: SequenceKind
    let scoring: ScoringProfile
    let score: Int
    let identity: Double
    let alignedA: String
    let alignedB: String
    let matchLine: String
    let matrix: [Int32]
    let rows: Int
    let columns: Int
    let moves: [UInt8]
    let tracebackPath: [TraceCoordinate]
    let variantCandidates: [VariantCandidate]
    let markerAnnotations: [KnownMarkerAnnotation]
    let hotspots: [Hotspot]
    let significance: SignificanceReport
    let duration: TimeInterval

    func matrixScore(row: Int, column: Int) -> Int {
        Int(matrix[(row * columns) + column])
    }

    func move(row: Int, column: Int) -> TraceMove {
        TraceMove(rawValue: moves[(row * columns) + column]) ?? .none
    }
}

enum TraceMove: UInt8, Sendable {
    case none = 0
    case diagonal = 1
    case up = 2
    case left = 3
}

enum SequenceSanitizer {
    static let maximumSequenceLength = 5_000

    static func sanitize(_ rawValue: String) -> String {
        rawValue
            .split(whereSeparator: \.isNewline)
            .filter { line in
                !line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
            }
            .joined()
            .uppercased()
            .filter { character in
                character.isLetter
            }
    }

    static func validate(_ sequence: String, kind: SequenceKind) throws {
        guard !sequence.isEmpty else {
            throw AlignmentError.emptySequence
        }

        guard sequence.count <= maximumSequenceLength else {
            throw AlignmentError.sequenceTooLong(limit: maximumSequenceLength)
        }

        let invalid = Set(sequence).subtracting(kind.allowedCharacters)
        guard invalid.isEmpty else {
            let invalidString = invalid.sorted().map(String.init).joined(separator: ", ")
            throw AlignmentError.invalidCharacters(invalidString)
        }
    }

    static func detectKind(sequenceA: String, sequenceB: String) -> SequenceKind? {
        let combined = sanitize(sequenceA) + sanitize(sequenceB)
        guard !combined.isEmpty else {
            return nil
        }

        let symbols = Set(combined)
        let dna = SequenceKind.dna.allowedCharacters
        let rna = SequenceKind.rna.allowedCharacters
        let protein = SequenceKind.protein.allowedCharacters

        if symbols.isSubset(of: dna) {
            return .dna
        }

        if symbols.isSubset(of: rna) {
            return .rna
        }

        if symbols.isSubset(of: protein) {
            return .protein
        }

        return nil
    }
}

enum AlignmentEngine {
    static let maximumShuffleIterations = 100
    static let maximumShuffledCellBudget = 5_000_000

    static func align(
        sequenceA rawA: String,
        sequenceB rawB: String,
        kind: SequenceKind,
        scoring: ScoringProfile,
        hotspotWindow: Int,
        hotspotThreshold: Double,
        shuffleIterations: Int
    ) throws -> AlignmentResult {
        let start = Date()
        let sequenceA = SequenceSanitizer.sanitize(rawA)
        let sequenceB = SequenceSanitizer.sanitize(rawB)

        try SequenceSanitizer.validate(sequenceA, kind: kind)
        try SequenceSanitizer.validate(sequenceB, kind: kind)

        guard scoring.match > scoring.mismatch, scoring.gap < 0 else {
            throw AlignmentError.invalidScoring
        }

        let a = Array(sequenceA)
        let b = Array(sequenceB)
        let rowCount = a.count + 1
        let columnCount = b.count + 1
        let totalCells = rowCount * columnCount
        var matrix = Array(repeating: Int32.zero, count: totalCells)
        var moves = Array(repeating: UInt8.zero, count: totalCells)

        func index(_ row: Int, _ column: Int) -> Int {
            (row * columnCount) + column
        }

        for row in 1..<rowCount {
            matrix[index(row, 0)] = Int32(row * scoring.gap)
            moves[index(row, 0)] = TraceMove.up.rawValue
        }

        for column in 1..<columnCount {
            matrix[index(0, column)] = Int32(column * scoring.gap)
            moves[index(0, column)] = TraceMove.left.rawValue
        }

        for row in 1..<rowCount {
            for column in 1..<columnCount {
                let substitution = substitutionScore(left: a[row - 1], right: b[column - 1], kind: kind, scoring: scoring)
                let diagonal = matrix[index(row - 1, column - 1)] + Int32(substitution)
                let up = matrix[index(row - 1, column)] + Int32(scoring.gap)
                let left = matrix[index(row, column - 1)] + Int32(scoring.gap)

                if diagonal >= up && diagonal >= left {
                    matrix[index(row, column)] = diagonal
                    moves[index(row, column)] = TraceMove.diagonal.rawValue
                } else if up >= left {
                    matrix[index(row, column)] = up
                    moves[index(row, column)] = TraceMove.up.rawValue
                } else {
                    matrix[index(row, column)] = left
                    moves[index(row, column)] = TraceMove.left.rawValue
                }
            }
        }

        var row = a.count
        var column = b.count
        var path: [TraceCoordinate] = []
        var alignedA: [Character] = []
        var alignedB: [Character] = []

        while row > 0 || column > 0 {
            path.append(TraceCoordinate(row: row, column: column))
            let move = TraceMove(rawValue: moves[index(row, column)]) ?? .none

            switch move {
            case .diagonal where row > 0 && column > 0:
                alignedA.append(a[row - 1])
                alignedB.append(b[column - 1])
                row -= 1
                column -= 1
            case .up where row > 0:
                alignedA.append(a[row - 1])
                alignedB.append("-")
                row -= 1
            case .left where column > 0:
                alignedA.append("-")
                alignedB.append(b[column - 1])
                column -= 1
            default:
                if row > 0 {
                    alignedA.append(a[row - 1])
                    alignedB.append("-")
                    row -= 1
                } else if column > 0 {
                    alignedA.append("-")
                    alignedB.append(b[column - 1])
                    column -= 1
                }
            }
        }

        path.append(TraceCoordinate(row: 0, column: 0))
        alignedA.reverse()
        alignedB.reverse()
        path.reverse()

        let alignmentA = String(alignedA)
        let alignmentB = String(alignedB)
        let matchLine = makeMatchLine(alignedA: alignedA, alignedB: alignedB)
        let identity = computeIdentity(alignedA: alignedA, alignedB: alignedB)
        let variantCandidates = findVariantCandidates(alignedA: alignedA, alignedB: alignedB)
        let markerAnnotations = findKnownMarkers(
            sequenceA: sequenceA,
            sequenceB: sequenceB,
            candidates: variantCandidates
        )
        let hotspots = findHotspots(
            alignedA: alignedA,
            alignedB: alignedB,
            windowSize: hotspotWindow,
            threshold: hotspotThreshold
        )
        let terminalScore = Int(matrix[index(a.count, b.count)])
        let significance = evaluateSignificance(
            sequenceA: a,
            sequenceB: b,
            kind: kind,
            scoring: scoring,
            originalScore: terminalScore,
            iterations: shuffleIterations
        )

        return AlignmentResult(
            id: UUID(),
            createdAt: Date(),
            sequenceA: sequenceA,
            sequenceB: sequenceB,
            kind: kind,
            scoring: scoring,
            score: terminalScore,
            identity: identity,
            alignedA: alignmentA,
            alignedB: alignmentB,
            matchLine: matchLine,
            matrix: matrix,
            rows: rowCount,
            columns: columnCount,
            moves: moves,
            tracebackPath: path,
            variantCandidates: variantCandidates,
            markerAnnotations: markerAnnotations,
            hotspots: hotspots,
            significance: significance,
            duration: Date().timeIntervalSince(start)
        )
    }

    static func scoreOnly(
        sequenceA: [Character],
        sequenceB: [Character],
        kind: SequenceKind = .dna,
        scoring: ScoringProfile
    ) -> Int {
        let rows = sequenceA.count + 1
        let columns = sequenceB.count + 1
        var previous = Array(repeating: Int32.zero, count: columns)
        var current = Array(repeating: Int32.zero, count: columns)

        for column in 1..<columns {
            previous[column] = Int32(column * scoring.gap)
        }

        guard rows > 1 else {
            return Int(previous[columns - 1])
        }

        for row in 1..<rows {
            current[0] = Int32(row * scoring.gap)

            for column in 1..<columns {
                let substitution = substitutionScore(left: sequenceA[row - 1], right: sequenceB[column - 1], kind: kind, scoring: scoring)
                let diagonal = previous[column - 1] + Int32(substitution)
                let up = previous[column] + Int32(scoring.gap)
                let left = current[column - 1] + Int32(scoring.gap)
                current[column] = max(diagonal, max(up, left))
            }

            swap(&previous, &current)
        }

        return Int(previous[columns - 1])
    }
}

private extension AlignmentEngine {
    enum MarkerType {
        case substitution
        case deletion
    }

    struct KnownMarkerDefinition {
        let markerType: MarkerType
        let organism: String
        let gene: String
        let variantName: String
        let callType: String
        let codon: String
        let protein: String
        let nucleotideChange: String
        let databaseMatch: String
        let interpretation: String
        let confidence: String
        let referenceMotif: String
        let variantMotif: String
        let referenceBase: String
        let variantBase: String
        let deletedSequence: String
        let deletionOffset: Int
        let sourceFindings: [MarkerEvidence]
    }

    static let knownMarkers: [KnownMarkerDefinition] = [
        KnownMarkerDefinition(
            markerType: .substitution,
            organism: "Escherichia coli",
            gene: "gyrA",
            variantName: "gyrA S83L",
            callType: "Evidence-backed AMR marker",
            codon: "TCG -> TTG",
            protein: "Ser83Leu / S83L",
            nucleotideChange: "C -> T inside the Ser83 codon",
            databaseMatch: "Curated AMR marker record; ClinVar is not primary for this bacterial resistance marker",
            interpretation: "quinolone/fluoroquinolone resistance marker",
            confidence: "High for this submitted fragment because the known gyrA S83L motif is present.",
            referenceMotif: "CATGGTGACTCGGCG",
            variantMotif: "CATGGTGACTTGGCG",
            referenceBase: "C",
            variantBase: "T",
            deletedSequence: "",
            deletionOffset: 0,
            sourceFindings: [
                MarkerEvidence(
                    name: "Reference context",
                    status: "Local motif match",
                    detail: "The submitted fragment contains the curated E. coli gyrA Ser83 motif used by GeneSync's local marker database."
                ),
                MarkerEvidence(
                    name: "CARD",
                    status: "AMR ontology support",
                    detail: "E. coli gyrA point mutations are associated with fluoroquinolone resistance through target alteration."
                ),
                MarkerEvidence(
                    name: "PointFinder",
                    status: "Point-mutation validation",
                    detail: "PointFinder/ResFinder-style AMR tools are the right validation path for bacterial resistance mutations."
                ),
                MarkerEvidence(
                    name: "ClinVar / VEP",
                    status: "Not primary for E. coli",
                    detail: "ClinVar and human VEP are not the best evidence sources for this bacterial AMR marker."
                )
            ]
        ),
        KnownMarkerDefinition(
            markerType: .deletion,
            organism: "Homo sapiens",
            gene: "CFTR",
            variantName: "NM_000492.4(CFTR):c.1520_1522delTCT / c.1521_1523delCTT",
            callType: "Definite known clinical marker",
            codon: "in-frame 3 bp deletion in the Phe508 codon context",
            protein: "p.Phe508del / F508del / deltaF508",
            nucleotideChange: "c.1520_1522delTCT; equivalent CFTR F508del HGVS forms include c.1521_1523delCTT",
            databaseMatch: "ClinVar Variation ID 7105; curated in GeneSync local marker database",
            interpretation: "pathogenic cystic fibrosis-associated CFTR F508del marker",
            confidence: "Definite known-marker match for this submitted fragment because the CFTR F508del deletion motif and 3 bp gap are present.",
            referenceMotif: "ATATCATCTTTGGTGTTT",
            variantMotif: "ATATCATTGGTGTTT",
            referenceBase: "",
            variantBase: "",
            deletedSequence: "TCT",
            deletionOffset: 6,
            sourceFindings: [
                MarkerEvidence(
                    name: "HGVS",
                    status: "Deletion naming",
                    detail: "The local alignment supports an HGVS in-frame deletion call for CFTR F508del; ClinVar lists MANE forms including c.1520_1522delTCT and c.1521_1523delCTT."
                ),
                MarkerEvidence(
                    name: "Reference context",
                    status: "Local motif match",
                    detail: "The submitted fragment contains the curated CFTR F508del motif used by GeneSync's local marker database."
                ),
                MarkerEvidence(
                    name: "Ensembl VEP",
                    status: "Functional consequence",
                    detail: "The expected consequence is an in-frame deletion producing p.Phe508del in CFTR."
                ),
                MarkerEvidence(
                    name: "ClinVar",
                    status: "Clinical evidence",
                    detail: "ClinVar Variation ID 7105 reports CFTR p.Phe508del as a 3 bp deletion with pathogenic cystic fibrosis submissions."
                )
            ]
        ),
        KnownMarkerDefinition(
            markerType: .substitution,
            organism: "Homo sapiens",
            gene: "HBB",
            variantName: "NM_000518.5(HBB):c.118C>T",
            callType: "Evidence-backed clinical variant",
            codon: "CAG -> TAG",
            protein: "Gln40Ter / Q40*",
            nucleotideChange: "c.118C>T",
            databaseMatch: "ClinVar/HGVS-backed HBB marker record curated in GeneSync local marker database",
            interpretation: "pathogenic beta-thalassemia-associated nonsense variant",
            confidence: "High for this submitted fragment because the known HBB c.118C>T motif is present.",
            referenceMotif: "CCTTGGACCCAGAGGTTC",
            variantMotif: "CCTTGGACCTAGAGGTTC",
            referenceBase: "C",
            variantBase: "T",
            deletedSequence: "",
            deletionOffset: 0,
            sourceFindings: [
                MarkerEvidence(
                    name: "HGVS",
                    status: "Variant naming",
                    detail: "HGVS-style transcript notation: NM_000518.5(HBB):c.118C>T, protein p.Gln40Ter."
                ),
                MarkerEvidence(
                    name: "Reference context",
                    status: "Local motif match",
                    detail: "The submitted fragment contains the curated HBB c.118C>T motif used by GeneSync's local marker database."
                ),
                MarkerEvidence(
                    name: "Ensembl VEP",
                    status: "Functional consequence",
                    detail: "Expected consequence is a stop-gained/nonsense change in the HBB coding sequence."
                ),
                MarkerEvidence(
                    name: "ClinVar",
                    status: "Clinical evidence",
                    detail: "ClinVar records NM_000518.5(HBB):c.118C>T (p.Gln40Ter) as pathogenic for beta thalassemia-related conditions."
                )
            ]
        )
    ]

    static let blosum62: [Character: [Character: Int]] = {
        let headers = Array("ARNDCQEGHILKMFPSTWYV")
        let rows = [
            "A 4 -1 -2 -2 0 -1 -1 0 -2 -1 -1 -1 -1 -2 -1 1 0 -3 -2 0",
            "R -1 5 0 -2 -3 1 0 -2 0 -3 -2 2 -1 -3 -2 -1 -1 -3 -2 -3",
            "N -2 0 6 1 -3 0 0 0 1 -3 -3 0 -2 -3 -2 1 0 -4 -2 -3",
            "D -2 -2 1 6 -3 0 2 -1 -1 -3 -4 -1 -3 -3 -1 0 -1 -4 -3 -3",
            "C 0 -3 -3 -3 9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1",
            "Q -1 1 0 0 -3 5 2 -2 0 -3 -2 1 0 -3 -1 0 -1 -2 -1 -2",
            "E -1 0 0 2 -4 2 5 -2 0 -3 -3 1 -2 -3 -1 0 -1 -3 -2 -2",
            "G 0 -2 0 -1 -3 -2 -2 6 -2 -4 -4 -2 -3 -3 -2 0 -2 -2 -3 -3",
            "H -2 0 1 -1 -3 0 0 -2 8 -3 -3 -1 -2 -1 -2 -1 -2 -2 2 -3",
            "I -1 -3 -3 -3 -1 -3 -3 -4 -3 4 2 -3 1 0 -3 -2 -1 -3 -1 3",
            "L -1 -2 -3 -4 -1 -2 -3 -4 -3 2 4 -2 2 0 -3 -2 -1 -2 -1 1",
            "K -1 2 0 -1 -3 1 1 -2 -1 -3 -2 5 -1 -3 -1 0 -1 -3 -2 -2",
            "M -1 -1 -2 -3 -1 0 -2 -3 -2 1 2 -1 5 0 -2 -1 -1 -1 -1 1",
            "F -2 -3 -3 -3 -2 -3 -3 -3 -1 0 0 -3 0 6 -4 -2 -2 1 3 -1",
            "P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4 7 -1 -1 -4 -3 -2",
            "S 1 -1 1 0 -1 0 0 0 -1 -2 -2 0 -1 -2 -1 4 1 -3 -2 -2",
            "T 0 -1 0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1 1 5 -2 -2 0",
            "W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1 1 -4 -3 -2 11 2 -3",
            "Y -2 -2 -2 -3 -2 -1 -2 -3 2 -1 -1 -2 -1 3 -3 -2 -2 2 7 -1",
            "V 0 -3 -3 -3 -1 -2 -2 -3 -3 3 1 -2 1 -1 -2 -2 0 -3 -1 4"
        ]

        return rows.reduce(into: [Character: [Character: Int]]()) { table, row in
            let parts = row.split(separator: " ")
            guard let label = parts.first?.first else {
                return
            }

            table[label] = Dictionary(uniqueKeysWithValues: zip(headers, parts.dropFirst().compactMap { Int(String($0)) }))
        }
    }()

    static func substitutionScore(
        left: Character,
        right: Character,
        kind: SequenceKind,
        scoring: ScoringProfile
    ) -> Int {
        if kind == .protein, scoring.proteinMatrix == .blosum62 {
            return blosum62[left]?[right] ?? (left == right ? scoring.match : scoring.mismatch)
        }

        return left == right ? scoring.match : scoring.mismatch
    }

    static func findVariantCandidates(alignedA: [Character], alignedB: [Character]) -> [VariantCandidate] {
        var candidates: [VariantCandidate] = []
        var referencePosition = 0
        var variantPosition = 0
        var index = 0

        while index < alignedA.count {
            let top = alignedA[index]
            let bottom = alignedB[index]

            if top == bottom {
                if top != "-" {
                    referencePosition += 1
                    variantPosition += 1
                }
                index += 1
                continue
            }

            if top == "-" {
                let variantStart = variantPosition + 1
                var inserted: [Character] = []

                while index < alignedA.count, alignedA[index] == "-", alignedB[index] != "-" {
                    inserted.append(alignedB[index])
                    variantPosition += 1
                    index += 1
                }

                let segment = String(inserted)
                candidates.append(
                    VariantCandidate(
                        id: candidates.count + 1,
                        kind: .insertion,
                        referencePosition: referencePosition == 0 ? "before ref 1" : "after ref \(referencePosition)",
                        variantPosition: inserted.count == 1 ? "var \(variantStart)" : "var \(variantStart)-\(variantPosition)",
                        referenceStart: referencePosition,
                        reference: "-",
                        variant: segment,
                        validationBasis: "HGVS insertion naming, reference-context check, VEP effect, ClinVar evidence if human"
                    )
                )
                continue
            }

            if bottom == "-" {
                let referenceStart = referencePosition + 1
                var deleted: [Character] = []

                while index < alignedA.count, alignedA[index] != "-", alignedB[index] == "-" {
                    deleted.append(alignedA[index])
                    referencePosition += 1
                    index += 1
                }

                let segment = String(deleted)
                candidates.append(
                    VariantCandidate(
                        id: candidates.count + 1,
                        kind: .deletion,
                        referencePosition: deleted.count == 1 ? "ref \(referenceStart)" : "ref \(referenceStart)-\(referencePosition)",
                        variantPosition: variantPosition == 0 ? "before var 1" : "after var \(variantPosition)",
                        referenceStart: referenceStart,
                        reference: segment,
                        variant: "-",
                        validationBasis: "HGVS deletion naming, reference-context check, VEP effect, ClinVar evidence if human"
                    )
                )
                continue
            }

            referencePosition += 1
            variantPosition += 1
            candidates.append(
                VariantCandidate(
                    id: candidates.count + 1,
                    kind: .substitution,
                    referencePosition: "ref \(referencePosition)",
                    variantPosition: "var \(variantPosition)",
                    referenceStart: referencePosition,
                    reference: String(top),
                    variant: String(bottom),
                    validationBasis: "HGVS substitution naming, reference-context check, VEP effect, ClinVar evidence if human"
                )
            )
            index += 1
        }

        return candidates
    }

    static func findKnownMarkers(
        sequenceA: String,
        sequenceB: String,
        candidates: [VariantCandidate]
    ) -> [KnownMarkerAnnotation] {
        let referenceSequence = Array(sequenceA)
        let variantSequence = Array(sequenceB)

        return knownMarkers.compactMap { marker in
            guard let referenceIndex = motifIndex(in: referenceSequence, motif: marker.referenceMotif),
                  motifIndex(in: variantSequence, motif: marker.variantMotif) != nil else {
                return nil
            }

            let candidate: VariantCandidate?

            switch marker.markerType {
            case .substitution:
                candidate = findSubstitutionMarkerCandidate(
                    marker: marker,
                    referenceIndex: referenceIndex,
                    candidates: candidates
                )
            case .deletion:
                candidate = findDeletionMarkerCandidate(
                    marker: marker,
                    referenceIndex: referenceIndex,
                    candidates: candidates
                )
            }

            guard let candidate else {
                return nil
            }

            return KnownMarkerAnnotation(
                id: marker.variantName,
                organism: marker.organism,
                gene: marker.gene,
                variantName: marker.variantName,
                callType: marker.callType,
                codon: marker.codon,
                protein: marker.protein,
                nucleotideChange: marker.nucleotideChange,
                databaseMatch: marker.databaseMatch,
                interpretation: marker.interpretation,
                confidence: marker.confidence,
                position: candidate.referencePosition,
                localContext: markerLocalContext(
                    marker: marker,
                    candidate: candidate,
                    sequenceA: sequenceA,
                    flank: 8
                ),
                sourceFindings: marker.sourceFindings
            )
        }
    }

    static func findSubstitutionMarkerCandidate(
        marker: KnownMarkerDefinition,
        referenceIndex: Int,
        candidates: [VariantCandidate]
    ) -> VariantCandidate? {
        let referenceMotif = Array(marker.referenceMotif)
        let variantMotif = Array(marker.variantMotif)

        guard let markerOffset = zip(referenceMotif.indices, referenceMotif).first(where: { index, character in
            index < variantMotif.count && character != variantMotif[index]
        })?.0 else {
            return nil
        }

        let expectedPosition = referenceIndex + markerOffset + 1

        return candidates.first { candidate in
            candidate.kind == .substitution &&
                candidate.referenceStart == expectedPosition &&
                candidate.reference == marker.referenceBase &&
                candidate.variant == marker.variantBase
        }
    }

    static func findDeletionMarkerCandidate(
        marker: KnownMarkerDefinition,
        referenceIndex: Int,
        candidates: [VariantCandidate]
    ) -> VariantCandidate? {
        let expectedPosition = referenceIndex + marker.deletionOffset + 1

        return candidates.first { candidate in
            candidate.kind == .deletion &&
                candidate.referenceStart == expectedPosition &&
                candidate.reference == marker.deletedSequence &&
                candidate.variant == "-"
        }
    }

    static func motifIndex(in sequence: [Character], motif: String) -> Int? {
        let motifCharacters = Array(motif)
        guard !motifCharacters.isEmpty, sequence.count >= motifCharacters.count else {
            return nil
        }

        for start in 0...(sequence.count - motifCharacters.count) {
            let end = start + motifCharacters.count
            if Array(sequence[start..<end]) == motifCharacters {
                return start
            }
        }

        return nil
    }

    static func markerLocalContext(
        marker: KnownMarkerDefinition,
        candidate: VariantCandidate,
        sequenceA: String,
        flank: Int
    ) -> String {
        let reference = Array(sequenceA)
        let position = max(candidate.referenceStart, 1)

        switch marker.markerType {
        case .deletion:
            let deletionStart = position - 1
            let deletionEnd = min(deletionStart + marker.deletedSequence.count, reference.count)
            let start = max(deletionStart - flank, 0)
            let end = min(deletionEnd + flank, reference.count)

            guard deletionStart < deletionEnd, start <= deletionStart, deletionEnd <= end else {
                return "Context unavailable"
            }

            return String(reference[start..<deletionStart]) +
                "[\(String(reference[deletionStart..<deletionEnd]))->-]" +
                String(reference[deletionEnd..<end])
        case .substitution:
            let targetIndex = position - 1
            let start = max(targetIndex - flank, 0)
            let end = min(targetIndex + flank + 1, reference.count)

            guard reference.indices.contains(targetIndex), start <= targetIndex, targetIndex < end else {
                return "Context unavailable"
            }

            return String(reference[start..<targetIndex]) +
                "[\(reference[targetIndex])->\(candidate.variant)]" +
                String(reference[(targetIndex + 1)..<end])
        }
    }

    static func makeMatchLine(alignedA: [Character], alignedB: [Character]) -> String {
        zip(alignedA, alignedB).map { left, right in
            if left == right {
                return "|"
            }

            if left == "-" || right == "-" {
                return " "
            }

            return "."
        }
        .joined()
    }

    static func computeIdentity(alignedA: [Character], alignedB: [Character]) -> Double {
        guard !alignedA.isEmpty else { return 0 }

        let matches = zip(alignedA, alignedB).filter { left, right in
            left == right
        }
        .count

        return (Double(matches) / Double(alignedA.count)) * 100
    }

    static func findHotspots(
        alignedA: [Character],
        alignedB: [Character],
        windowSize: Int,
        threshold: Double
    ) -> [Hotspot] {
        guard alignedA.count == alignedB.count, !alignedA.isEmpty else {
            return []
        }

        let boundedWindow = min(max(windowSize, 2), alignedA.count)
        var flagged: [Hotspot] = []

        for startIndex in 0...(alignedA.count - boundedWindow) {
            let endIndex = startIndex + boundedWindow
            let slice = zip(alignedA[startIndex..<endIndex], alignedB[startIndex..<endIndex])
            let gaps = slice.filter { left, right in
                left == "-" || right == "-"
            }
            .count
            let mismatches = slice.filter { left, right in
                left != right && left != "-" && right != "-"
            }
            .count
            let density = Double(gaps + mismatches) / Double(boundedWindow)

            if density >= threshold {
                flagged.append(
                    Hotspot(
                        start: startIndex + 1,
                        end: endIndex,
                        density: density,
                        gaps: gaps,
                        mismatches: mismatches
                    )
                )
            }
        }

        return mergeHotspots(flagged)
    }

    static func mergeHotspots(_ hotspots: [Hotspot]) -> [Hotspot] {
        guard var current = hotspots.first else {
            return []
        }

        var merged: [Hotspot] = []

        for hotspot in hotspots.dropFirst() {
            if hotspot.start <= current.end {
                current = Hotspot(
                    start: current.start,
                    end: max(current.end, hotspot.end),
                    density: max(current.density, hotspot.density),
                    gaps: max(current.gaps, hotspot.gaps),
                    mismatches: max(current.mismatches, hotspot.mismatches)
                )
            } else {
                merged.append(current)
                current = hotspot
            }
        }

        merged.append(current)
        return merged
    }

    static func evaluateSignificance(
        sequenceA: [Character],
        sequenceB: [Character],
        kind: SequenceKind,
        scoring: ScoringProfile,
        originalScore: Int,
        iterations requestedIterations: Int
    ) -> SignificanceReport {
        let boundedRequest = max(1, min(requestedIterations, maximumShuffleIterations))
        let shuffledCellCount = max(1, sequenceA.count + 1) * max(1, sequenceB.count + 1)
        let budgetedIterations = max(1, maximumShuffledCellBudget / max(1, shuffledCellCount))
        let iterations = min(boundedRequest, budgetedIterations)
        var rng = SeededRandomNumberGenerator(seed: 0x47534E59)
        var scores: [Int] = []
        scores.reserveCapacity(iterations)

        for _ in 0..<iterations {
            var shuffled = sequenceB
            shuffled.shuffle(using: &rng)
            scores.append(scoreOnly(sequenceA: sequenceA, sequenceB: shuffled, kind: kind, scoring: scoring))
        }

        let mean = scores.reduce(0.0) { partial, score in
            partial + Double(score)
        } / Double(scores.count)

        let variance = scores.reduce(0.0) { partial, score in
            let difference = Double(score) - mean
            return partial + (difference * difference)
        } / Double(scores.count)

        let standardDeviation = sqrt(variance)
        let zScore = standardDeviation > 0 ? (Double(originalScore) - mean) / standardDeviation : 0
        let moreOrEqual = scores.filter { score in
            score >= originalScore
        }
        .count
        let pValue = Double(moreOrEqual + 1) / Double(iterations + 1)

        return SignificanceReport(
            requestedIterations: boundedRequest,
            iterations: iterations,
            meanScore: mean,
            standardDeviation: standardDeviation,
            zScore: zScore,
            pValue: pValue,
            significant: pValue <= 0.05 && zScore >= 1.96
        )
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = (state &* 6_364_136_223_846_793_005) &+ 1
        return state
    }
}

import Foundation

@main
struct AlignmentStress {
    static func main() throws {
        try testSanitizationAndValidation()
        try testKnownNeedlemanWunschSample()
        try testExhaustiveSmallDNAPairs()
        try testRandomizedDNAPairs()
        try testRNAAndProteinModes()
        try testHotspotDetection()
        try testCuratedMarkerDetection()
        try testSignificanceBudgeting()

        print("Alignment stress test passed: validation, matrix recurrence, traceback, identity, curated markers, hotspots, significance, and randomized correctness checks are green.")
    }

    private static func testSanitizationAndValidation() throws {
        let raw = ">Reference\nG A T T A C A\n123\n"
        expect(SequenceSanitizer.sanitize(raw) == "GATTACA", "FASTA cleanup should strip headers, whitespace, and numbers.")

        try SequenceSanitizer.validate("ATCGN", kind: .dna)
        try SequenceSanitizer.validate("AUCG", kind: .rna)
        try SequenceSanitizer.validate("ACDEFGHIKLMNPQRSTVWY", kind: .protein)
        try SequenceSanitizer.validate(String(repeating: "A", count: SequenceSanitizer.maximumSequenceLength), kind: .dna)
        expect(SequenceSanitizer.detectKind(sequenceA: "GATTACA", sequenceB: "GTCGACG") == .dna, "DNA inputs should auto-detect as DNA.")
        expect(SequenceSanitizer.detectKind(sequenceA: "AUGCUU", sequenceB: "AUGUU") == .rna, "RNA inputs with U should auto-detect as RNA.")
        expect(SequenceSanitizer.detectKind(sequenceA: "MEEPQSDPSV", sequenceB: "MEEAQSDPSI") == .protein, "Amino acid inputs should auto-detect as protein.")

        expectThrows("Empty sequence should fail.") {
            try SequenceSanitizer.validate("", kind: .dna)
        }

        expectThrows("DNA must reject RNA/protein-only letters.") {
            try SequenceSanitizer.validate("ATCGU", kind: .dna)
        }

        expectThrows("RNA must reject thymine.") {
            try SequenceSanitizer.validate("AUCGT", kind: .rna)
        }

        expectThrows("Protein must reject non-standard amino acid letters.") {
            try SequenceSanitizer.validate("ACDEFGHIKLMNPQRSTVWYX", kind: .protein)
        }

        expectThrows("Input cap should reject over 5,000 characters.") {
            try SequenceSanitizer.validate(String(repeating: "A", count: SequenceSanitizer.maximumSequenceLength + 1), kind: .dna)
        }
    }

    private static func testKnownNeedlemanWunschSample() throws {
        let scoring = ScoringProfile.standard
        let result = try AlignmentEngine.align(
            sequenceA: "GATTACA",
            sequenceB: "GTCGACG",
            kind: .dna,
            scoring: scoring,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 100
        )

        expect(result.score == referenceScore("GATTACA", "GTCGACG", scoring: scoring), "Sample terminal score must match independent DP reference.")
        expect(result.score == -1, "GATTACA vs GTCGACG should score -1 with +1/-1/-2 scoring.")
        expect(result.significance.iterations == 100, "Small sample should run the requested 100 shuffles.")
        verifyMatrixBoundaries(result, scoring: scoring)
        verifyAlignmentIntegrity(result)
    }

    private static func testExhaustiveSmallDNAPairs() throws {
        let scoringProfiles = [
            ScoringProfile(match: 1, mismatch: -1, gap: -2),
            ScoringProfile(match: 2, mismatch: -1, gap: -2),
            ScoringProfile(match: 3, mismatch: -2, gap: -4)
        ]
        let sequences = generateSequences(alphabet: Array("AC"), maxLength: 4)

        for scoring in scoringProfiles {
            for left in sequences {
                for right in sequences {
                    let result = try AlignmentEngine.align(
                        sequenceA: left,
                        sequenceB: right,
                        kind: .dna,
                        scoring: scoring,
                        hotspotWindow: 3,
                        hotspotThreshold: 0.50,
                        shuffleIterations: 1
                    )

                    let expected = referenceScore(left, right, scoring: scoring)
                    expect(result.score == expected, "Exhaustive score mismatch for \(left) vs \(right).")
                    expect(AlignmentEngine.scoreOnly(sequenceA: Array(left), sequenceB: Array(right), scoring: scoring) == expected, "Linear-memory score mismatch for \(left) vs \(right).")
                    verifyMatrixBoundaries(result, scoring: scoring)
                    verifyAlignmentIntegrity(result)
                }
            }
        }
    }

    private static func testRandomizedDNAPairs() throws {
        var rng = SeededRandomNumberGenerator(seed: 0x515549434B544553)
        let alphabet = Array("ATCGN")

        for trial in 0..<250 {
            let leftLength = Int.random(in: 1...70, using: &rng)
            let rightLength = Int.random(in: 1...70, using: &rng)
            let left = randomSequence(length: leftLength, alphabet: alphabet, rng: &rng)
            let right = randomSequence(length: rightLength, alphabet: alphabet, rng: &rng)
            let scoring = ScoringProfile(
                match: Int.random(in: 1...5, using: &rng),
                mismatch: Int.random(in: -5...0, using: &rng),
                gap: Int.random(in: -6 ... -1, using: &rng)
            )

            let result = try AlignmentEngine.align(
                sequenceA: left,
                sequenceB: right,
                kind: .dna,
                scoring: scoring,
                hotspotWindow: Int.random(in: 2...10, using: &rng),
                hotspotThreshold: Double(Int.random(in: 2...8, using: &rng)) / 10,
                shuffleIterations: 3
            )

            let expected = referenceScore(left, right, scoring: scoring)
            expect(result.score == expected, "Random trial \(trial) score mismatch.")
            expect(result.score == AlignmentEngine.scoreOnly(sequenceA: Array(left), sequenceB: Array(right), scoring: scoring), "Random trial \(trial) scoreOnly mismatch.")
            verifyAlignmentIntegrity(result)
        }
    }

    private static func testRNAAndProteinModes() throws {
        let rna = try AlignmentEngine.align(
            sequenceA: "AUGCUU",
            sequenceB: "AUG-UU",
            kind: .rna,
            scoring: .standard,
            hotspotWindow: 3,
            hotspotThreshold: 0.34,
            shuffleIterations: 10
        )
        expect(rna.sequenceA == "AUGCUU", "RNA sequence A should sanitize cleanly.")
        expect(rna.sequenceB == "AUGUU", "RNA sequence B should remove gap markup during sanitization.")
        verifyAlignmentIntegrity(rna)

        let protein = try AlignmentEngine.align(
            sequenceA: "MEEPQSDPSV",
            sequenceB: "MEEAQSDPSI",
            kind: .protein,
            scoring: ScoringProfile(match: 2, mismatch: -1, gap: -3),
            hotspotWindow: 4,
            hotspotThreshold: 0.25,
            shuffleIterations: 10
        )
        verifyAlignmentIntegrity(protein)
        expect(protein.identity > 70, "Protein sample should retain high identity.")

        var blosumScoring = ScoringProfile(match: 2, mismatch: -1, gap: -3)
        blosumScoring.proteinMatrix = .blosum62
        let blosumProtein = try AlignmentEngine.align(
            sequenceA: "W",
            sequenceB: "W",
            kind: .protein,
            scoring: blosumScoring,
            hotspotWindow: 2,
            hotspotThreshold: 0.50,
            shuffleIterations: 1
        )
        expect(blosumProtein.score == 11, "BLOSUM62 should score W/W as 11.")
    }

    private static func testHotspotDetection() throws {
        let mismatchCluster = try AlignmentEngine.align(
            sequenceA: "AAAAAA",
            sequenceB: "TTTAAA",
            kind: .dna,
            scoring: ScoringProfile(match: 2, mismatch: -1, gap: -4),
            hotspotWindow: 3,
            hotspotThreshold: 1.0,
            shuffleIterations: 3
        )

        expect(mismatchCluster.hotspots.contains { hotspot in
            hotspot.start == 1 && hotspot.end == 3 && hotspot.mismatches == 3
        }, "Dense mismatch cluster should be flagged as a hotspot.")

        let gapCluster = try AlignmentEngine.align(
            sequenceA: "AAAAAA",
            sequenceB: "AAA",
            kind: .dna,
            scoring: ScoringProfile(match: 2, mismatch: -3, gap: -1),
            hotspotWindow: 3,
            hotspotThreshold: 1.0,
            shuffleIterations: 3
        )

        expect(gapCluster.hotspots.contains { hotspot in
            hotspot.gaps == 3
        }, "Dense gap cluster should be flagged as a hotspot.")
    }

    private static func testCuratedMarkerDetection() throws {
        let cftrReference = "AAGAAAATATCATCTTTGGTGTTTCCTATGATGAATATAGATACAGAAGCGTCATCAAAGCATGCCAACTAGAAGAG"
        let cftrVariant = "AAGAAAATATCATTGGTGTTTCCTATGATGAATATAGATACAGAAGCGTCATCAAAGCATGCCAACTAGAAGAG"
        let cftr = try AlignmentEngine.align(
            sequenceA: cftrReference,
            sequenceB: cftrVariant,
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 5
        )

        expect(cftr.variantCandidates.count == 1, "CFTR F508del sample should produce one deletion candidate.")
        expect(cftr.markerAnnotations.contains { marker in
            marker.gene == "CFTR" &&
                marker.databaseMatch.contains("ClinVar Variation ID 7105") &&
                marker.protein.contains("F508del") &&
                marker.localContext.contains("[TCT->-]")
        }, "CFTR F508del sample should match the curated ClinVar-backed marker.")

        let unrelatedDeletion = try AlignmentEngine.align(
            sequenceA: cftrReference,
            sequenceB: String(cftrReference.dropFirst(3)),
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 5
        )
        expect(unrelatedDeletion.markerAnnotations.isEmpty, "Unrelated deletion must not be promoted to CFTR F508del.")

        let hbbReference = "ATGGTGCATCTGACTCCTGAGGAGAAGTCTGCCGTTACTGCCCTGTGGGGCAAGGTGAACGTGGATGAAGTTGGTGGTGAGGCCCTGGGCAGGCTGCTGGTGGTCTACCCTTGGACCCAGAGGTTCTTTGAGTCCTTTGGGGATCTGTCCACTCCTGATGCTGTTATGGGCAACCCTAAG"
        let hbbVariant = "ATGGTGCATCTGACTCCTGAGGAGAAGTCTGCCGTTACTGCCCTGTGGGGCAAGGTGAACGTGGATGAAGTTGGTGGTGAGGCCCTGGGCAGGCTGCTGGTGGTCTACCCTTGGACCTAGAGGTTCTTTGAGTCCTTTGGGGATCTGTCCACTCCTGATGCTGTTATGGGCAACCCTAAG"
        let hbb = try AlignmentEngine.align(
            sequenceA: hbbReference,
            sequenceB: hbbVariant,
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 5
        )
        expect(hbb.markerAnnotations.contains { marker in
            marker.gene == "HBB" && marker.variantName.contains("c.118C>T") && marker.protein.contains("Q40")
        }, "HBB c.118C>T should match the curated HBB marker.")

        let gyrAReference = "TTGACCTGACCATGGTGACTCGGCGTAACTGA"
        let gyrAVariant = "TTGACCTGACCATGGTGACTTGGCGTAACTGA"
        let gyrA = try AlignmentEngine.align(
            sequenceA: gyrAReference,
            sequenceB: gyrAVariant,
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 5,
            hotspotThreshold: 0.40,
            shuffleIterations: 5
        )
        expect(gyrA.markerAnnotations.contains { marker in
            marker.gene == "gyrA" && marker.protein.contains("S83L")
        }, "E. coli gyrA S83L should match the curated AMR marker.")
    }

    private static func testSignificanceBudgeting() throws {
        let compact = try AlignmentEngine.align(
            sequenceA: String(repeating: "ACGT", count: 20),
            sequenceB: String(repeating: "ACGA", count: 20),
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 8,
            hotspotThreshold: 0.25,
            shuffleIterations: 100
        )
        expect(compact.significance.requestedIterations == 100, "Requested shuffle count should be recorded.")
        expect(compact.significance.iterations == 100, "Compact sequence should run all requested shuffles.")
        expect((0...1).contains(compact.significance.pValue), "P value must be normalized.")

        let longA = String(repeating: "ACGT", count: 250)
        let longB = String(repeating: "ACGA", count: 250)
        let long = try AlignmentEngine.align(
            sequenceA: longA,
            sequenceB: longB,
            kind: .dna,
            scoring: .standard,
            hotspotWindow: 12,
            hotspotThreshold: 0.40,
            shuffleIterations: 100
        )
        expect(long.significance.requestedIterations == 100, "Long sequence should preserve requested shuffle count.")
        expect(long.significance.iterations < 100, "Long sequence should respect the mobile shuffle cell budget.")
        verifyAlignmentIntegrity(long)
    }

    private static func verifyMatrixBoundaries(_ result: AlignmentResult, scoring: ScoringProfile) {
        for row in 0..<result.rows {
            expect(result.matrixScore(row: row, column: 0) == row * scoring.gap, "First column must contain cumulative gap penalties.")
        }

        for column in 0..<result.columns {
            expect(result.matrixScore(row: 0, column: column) == column * scoring.gap, "First row must contain cumulative gap penalties.")
        }
    }

    private static func verifyAlignmentIntegrity(_ result: AlignmentResult) {
        expect(result.alignedA.count == result.alignedB.count, "Aligned strings must have equal length.")
        expect(result.alignedA.replacingOccurrences(of: "-", with: "") == result.sequenceA, "Traceback must reconstruct sequence A.")
        expect(result.alignedB.replacingOccurrences(of: "-", with: "") == result.sequenceB, "Traceback must reconstruct sequence B.")
        expect(result.tracebackPath.first == TraceCoordinate(row: 0, column: 0), "Traceback path should begin at matrix origin.")
        expect(result.tracebackPath.last == TraceCoordinate(row: result.rows - 1, column: result.columns - 1), "Traceback path should end at terminal cell.")
        expect(result.matchLine.count == result.alignedA.count, "Match map length must match alignment length.")
        expect(result.score == alignedScore(result), "Aligned strings must evaluate back to the terminal score.")

        let matches = zip(result.alignedA, result.alignedB).filter { left, right in
            left == right
        }
        .count
        let expectedIdentity = (Double(matches) / Double(result.alignedA.count)) * 100
        expect(abs(result.identity - expectedIdentity) < 0.000_001, "Identity should be exact matches divided by alignment length.")
    }

    private static func alignedScore(_ result: AlignmentResult) -> Int {
        zip(result.alignedA, result.alignedB).reduce(0) { partial, pair in
            let (left, right) = pair

            if left == "-" || right == "-" {
                return partial + result.scoring.gap
            }

            return partial + (left == right ? result.scoring.match : result.scoring.mismatch)
        }
    }

    private static func referenceScore(_ left: String, _ right: String, scoring: ScoringProfile) -> Int {
        let a = Array(left)
        let b = Array(right)
        var matrix = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for row in 1...a.count {
            matrix[row][0] = row * scoring.gap
        }

        for column in 1...b.count {
            matrix[0][column] = column * scoring.gap
        }

        guard !a.isEmpty, !b.isEmpty else {
            return matrix[a.count][b.count]
        }

        for row in 1...a.count {
            for column in 1...b.count {
                let substitution = a[row - 1] == b[column - 1] ? scoring.match : scoring.mismatch
                matrix[row][column] = max(
                    matrix[row - 1][column - 1] + substitution,
                    matrix[row - 1][column] + scoring.gap,
                    matrix[row][column - 1] + scoring.gap
                )
            }
        }

        return matrix[a.count][b.count]
    }

    private static func generateSequences(alphabet: [Character], maxLength: Int) -> [String] {
        var values: [String] = []

        func build(_ prefix: String, remaining: Int) {
            if remaining == 0 {
                values.append(prefix)
                return
            }

            for character in alphabet {
                build(prefix + String(character), remaining: remaining - 1)
            }
        }

        for length in 1...maxLength {
            build("", remaining: length)
        }

        return values
    }

    private static func randomSequence(length: Int, alphabet: [Character], rng: inout SeededRandomNumberGenerator) -> String {
        String((0..<length).map { _ in
            alphabet.randomElement(using: &rng)!
        })
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }

    private static func expectThrows(_ message: String, operation: () throws -> Void) {
        do {
            try operation()
            fatalError(message)
        } catch {
            return
        }
    }
}

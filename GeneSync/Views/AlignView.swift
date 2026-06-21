import SwiftUI
import UniformTypeIdentifiers

struct AlignView: View {
    @EnvironmentObject private var session: GeneSyncSession
    @FocusState private var focusedField: Field?
    @State private var showingRunConfirmation = false
    @State private var showingFileImporter = false
    @State private var importTarget: Field = .sequenceA
    @State private var importMessage: String?

    enum Field {
        case sequenceA
        case sequenceB
    }

    var body: some View {
        PageScaffold(title: "Pairwise Alignment", subtitle: "Input, scoring, and analytics parameters.") {
            SurfacePanel {
                SectionHeading(title: "Sequence Type", symbol: "circle.hexagongrid")

                Picker("Sequence Type", selection: $session.kind) {
                    ForEach(SequenceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Chip(
                        text: "Detected: \(session.detectedKind?.rawValue ?? "Unknown")",
                        foreground: session.detectedKind == nil ? GeneSyncTheme.warning : GeneSyncTheme.success,
                        background: (session.detectedKind == nil ? GeneSyncTheme.warning : GeneSyncTheme.success).opacity(0.10)
                    )

                    Spacer()

                    Button {
                        session.applyDetectedKindIfPossible()
                    } label: {
                        Label("Apply", systemImage: "wand.and.stars")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .disabled(session.detectedKind == nil)
                }

                Text("GeneSync scans both cleaned sequences and applies the detected type before each run.")
                    .font(GeneSyncTheme.body(12))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SurfacePanel {
                SectionHeading(title: "Sequence A", symbol: "1.circle")

                TextEditor(text: $session.sequenceA)
                    .font(GeneSyncTheme.mono(14))
                    .foregroundStyle(GeneSyncTheme.text)
                    .frame(minHeight: 140)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(GeneSyncTheme.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(focusedField == .sequenceA ? GeneSyncTheme.primary : GeneSyncTheme.outline, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .sequenceA)

                HStack {
                    Chip(text: "\(session.sanitizedSequenceA.count) chars")
                    Spacer()
                    Button {
                        focusedField = nil
                        importTarget = .sequenceA
                        showingFileImporter = true
                    } label: {
                        Label("Upload", systemImage: "doc.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Button {
                        session.sequenceA = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }

                if let importMessage, importMessage.hasPrefix("Sequence A") {
                    ImportStatusMessage(text: importMessage)
                }
            }

            SurfacePanel {
                SectionHeading(title: "Sequence B", symbol: "2.circle")

                TextEditor(text: $session.sequenceB)
                    .font(GeneSyncTheme.mono(14))
                    .foregroundStyle(GeneSyncTheme.text)
                    .frame(minHeight: 140)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(GeneSyncTheme.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(focusedField == .sequenceB ? GeneSyncTheme.primary : GeneSyncTheme.outline, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .sequenceB)

                HStack {
                    Chip(text: "\(session.sanitizedSequenceB.count) chars")
                    Spacer()
                    Button {
                        focusedField = nil
                        importTarget = .sequenceB
                        showingFileImporter = true
                    } label: {
                        Label("Upload", systemImage: "doc.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Button {
                        session.sequenceB = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }

                if let importMessage, importMessage.hasPrefix("Sequence B") {
                    ImportStatusMessage(text: importMessage)
                }
            }

            SurfacePanel {
                SectionHeading(title: "Scoring Profile", symbol: "plus.forwardslash.minus")

                VStack(spacing: 12) {
                    ScoreStepper(title: "Match", value: Binding(
                        get: { session.scoring.match },
                        set: { session.scoring.match = $0 }
                    ), range: -10...20)

                    ScoreStepper(title: "Mismatch", value: Binding(
                        get: { session.scoring.mismatch },
                        set: { session.scoring.mismatch = $0 }
                    ), range: -20...10)

                    ScoreStepper(title: "Gap", value: Binding(
                        get: { session.scoring.gap },
                        set: { session.scoring.gap = $0 }
                    ), range: -20...0)

                    if session.kind == .protein {
                        VStack(alignment: .leading, spacing: 8) {
                            ParameterRow(title: "Protein matrix", value: session.scoring.proteinMatrix.rawValue)

                            Picker("Protein Matrix", selection: $session.scoring.proteinMatrix) {
                                ForEach(ProteinScoringMatrix.allCases) { matrix in
                                    Text(matrix.rawValue).tag(matrix)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(session.scoring.proteinMatrix.detail)
                                .font(GeneSyncTheme.body(12))
                                .foregroundStyle(GeneSyncTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            SurfacePanel {
                SectionHeading(title: "Analysis Parameters", symbol: "slider.horizontal.3")

                Stepper(value: $session.hotspotWindow, in: 2...40) {
                    ParameterRow(title: "Hotspot window", value: "\(session.hotspotWindow)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    ParameterRow(title: "Density threshold", value: session.hotspotThreshold.percentageString)
                    Slider(value: $session.hotspotThreshold, in: 0.10...1.00, step: 0.05)
                }

                Stepper(value: $session.shuffleIterations, in: 1...100) {
                    ParameterRow(title: "Shuffling runs", value: "\(session.shuffleIterations)")
                }
            }

            PrimaryActionButton(
                title: "Run Needleman-Wunsch",
                systemImage: "function",
                isLoading: session.isRunning
            ) {
                focusedField = nil
                session.applyDetectedKindIfPossible()
                showingRunConfirmation = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    focusedField = nil
                    session.loadSample()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Load sample")
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: SequenceImport.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .confirmationDialog(
            "Run Needleman-Wunsch alignment?",
            isPresented: $showingRunConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run Alignment") {
                session.runAlignment()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("GeneSync will align \(session.sanitizedSequenceA.count) x \(session.sanitizedSequenceB.count) \(session.kind.rawValue) characters using match \(session.scoring.match), mismatch \(session.scoring.mismatch), and gap \(session.scoring.gap).")
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

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            guard SequenceImport.isSupported(url) else {
                session.errorMessage = "Choose a .fasta, .fa, .fna, .ffn, .faa, or .txt file."
                return
            }

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let importedSequence = try SequenceImport.readText(from: url)
            try SequenceImport.validateSchema(importedSequence, from: url)
            let cleanedCount = SequenceSanitizer.sanitize(importedSequence).count
            switch importTarget {
            case .sequenceA:
                session.sequenceA = importedSequence
                importMessage = "Sequence A loaded from \(url.lastPathComponent): \(cleanedCount) cleaned characters."
            case .sequenceB:
                session.sequenceB = importedSequence
                importMessage = "Sequence B loaded from \(url.lastPathComponent): \(cleanedCount) cleaned characters."
            }
            session.applyDetectedKindIfPossible()
            session.errorMessage = nil
        } catch {
            session.errorMessage = "GeneSync could not import that sequence file: \(error.localizedDescription)"
        }
    }
}

private enum SequenceImport {
    enum ImportError: LocalizedError {
        case missingFASTAHeader
        case sequenceBeforeHeader

        var errorDescription: String? {
            switch self {
            case .missingFASTAHeader:
                return "FASTA files must include at least one header line beginning with >."
            case .sequenceBeforeHeader:
                return "FASTA sequence data must appear after a header line beginning with >."
            }
        }
    }

    static let allowedContentTypes: [UTType] = [
        .plainText,
        UTType(filenameExtension: "fasta") ?? .plainText,
        UTType(filenameExtension: "fa") ?? .plainText,
        UTType(filenameExtension: "fna") ?? .plainText,
        UTType(filenameExtension: "ffn") ?? .plainText,
        UTType(filenameExtension: "faa") ?? .plainText,
        UTType(filenameExtension: "txt") ?? .plainText
    ]

    private static let supportedExtensions = Set(["fasta", "fa", "fna", "ffn", "faa", "txt"])

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func readText(from url: URL) throws -> String {
        if let utf8Text = try? String(contentsOf: url, encoding: .utf8) {
            return utf8Text
        }

        return try String(contentsOf: url, encoding: .ascii)
    }

    static func validateSchema(_ text: String, from url: URL) throws {
        guard isFASTA(url) else {
            return
        }

        let nonEmptyLines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard nonEmptyLines.contains(where: { $0.hasPrefix(">") }) else {
            throw ImportError.missingFASTAHeader
        }

        var sawHeader = false
        for line in nonEmptyLines {
            if line.hasPrefix(">") {
                sawHeader = true
            } else if !sawHeader {
                throw ImportError.sequenceBeforeHeader
            }
        }
    }

    private static func isFASTA(_ url: URL) -> Bool {
        ["fasta", "fa", "fna", "ffn", "faa"].contains(url.pathExtension.lowercased())
    }
}

private struct ImportStatusMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GeneSyncTheme.body(12, weight: .semibold))
            .foregroundStyle(GeneSyncTheme.success)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeneSyncTheme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(GeneSyncTheme.success.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct ScoreStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            ParameterRow(title: title, value: "\(value)")
        }
    }
}

private struct ParameterRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(GeneSyncTheme.body(15))
                .foregroundStyle(GeneSyncTheme.text)
            Spacer()
            Text(value)
                .font(GeneSyncTheme.mono(14, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.primary)
        }
    }
}

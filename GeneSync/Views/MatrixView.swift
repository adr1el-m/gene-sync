import SwiftUI

private enum MatrixPlaybackMode: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case traceback = "Traceback"

    var id: String { rawValue }
}

struct MatrixView: View {
    @EnvironmentObject private var session: GeneSyncSession
    @State private var playbackMode: MatrixPlaybackMode = .fill
    @State private var fillIndex = 0.0
    @State private var traceIndex = 0.0
    @State private var isPlaying = false

    private let playbackTimer = Timer.publish(every: 0.24, on: .main, in: .common).autoconnect()

    var body: some View {
        PageScaffold(title: "Matrix Playback", subtitle: "Initialization, filling, and traceback path.") {
            if let result = session.result {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Rows", value: "\(result.rows)", detail: "Sequence A prefixes")
                    MetricTile(title: "Columns", value: "\(result.columns)", detail: "Sequence B prefixes")
                    MetricTile(title: "Final Score", value: "\(result.score)", detail: "F(m,n)")
                    MetricTile(title: "Trace Steps", value: "\(result.tracebackPath.count)", detail: "Back to origin")
                }

                SurfacePanel {
                    SectionHeading(title: "Playback Controls", symbol: "play.rectangle")

                    Picker("Matrix Playback Mode", selection: $playbackMode) {
                        ForEach(MatrixPlaybackMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Button {
                            currentPlaybackValue(result).wrappedValue = 0
                            isPlaying = false
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .frame(width: 38, height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GeneSyncTheme.primary)
                        .background(GeneSyncTheme.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Button {
                            currentPlaybackValue(result).wrappedValue = max(0, currentPlaybackValue(result).wrappedValue - 1)
                        } label: {
                            Image(systemName: "backward.fill")
                                .frame(width: 38, height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GeneSyncTheme.primary)
                        .background(GeneSyncTheme.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Button {
                            if Int(currentPlaybackValue(result).wrappedValue) >= playbackMaxIndex(result) {
                                currentPlaybackValue(result).wrappedValue = 0
                            }
                            isPlaying.toggle()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(GeneSyncTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Button {
                            currentPlaybackValue(result).wrappedValue = min(Double(playbackMaxIndex(result)), currentPlaybackValue(result).wrappedValue + 1)
                        } label: {
                            Image(systemName: "forward.fill")
                                .frame(width: 38, height: 34)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GeneSyncTheme.primary)
                        .background(GeneSyncTheme.surfaceLow)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    Slider(
                        value: currentPlaybackValue(result),
                        in: 0...Double(max(playbackMaxIndex(result), 1)),
                        step: 1
                    )

                    if playbackMode == .fill {
                        let coordinate = fillCoordinate(index: Int(fillIndex), result: result)
                        HStack(spacing: 8) {
                            Chip(text: "Row \(coordinate.row)")
                            Chip(text: "Column \(coordinate.column)")
                            Chip(text: coordinate.row == 0 || coordinate.column == 0 ? "Initialization" : "Matrix fill")
                            Chip(text: "Cell \(Int(fillIndex) + 1)/\(result.rows * result.columns)")
                        }
                    } else if let coordinate = result.tracebackPath[safe: Int(traceIndex)] {
                        HStack(spacing: 8) {
                            Chip(text: "Row \(coordinate.row)")
                            Chip(text: "Column \(coordinate.column)")
                            Chip(text: "Move \(result.move(row: coordinate.row, column: coordinate.column).label)")
                            Chip(text: "Step \(Int(traceIndex) + 1)/\(result.tracebackPath.count)")
                        }
                    }
                }

                SurfacePanel {
                    SectionHeading(title: "Dynamic Programming Grid", symbol: "square.grid.3x3")

                    MatrixGrid(
                        result: result,
                        playbackMode: playbackMode,
                        fillIndex: Int(fillIndex),
                        traceIndex: Int(traceIndex)
                    )

                    if result.rows > 18 || result.columns > 18 {
                        Text("Showing the full matrix. Playback automatically scrolls to the active fill or traceback cell.")
                            .font(GeneSyncTheme.body(12))
                            .foregroundStyle(GeneSyncTheme.secondaryText)
                    }
                }
            } else {
                EmptyStateView(
                    title: "No matrix yet",
                    message: "Run an alignment to generate the scoring matrix and traceback path.",
                    symbol: "tablecells.badge.ellipsis"
                )
            }
        }
        .onReceive(playbackTimer) { _ in
            guard isPlaying, let result = session.result else {
                return
            }

            let lastIndex = Double(playbackMaxIndex(result))
            if currentPlaybackValue(result).wrappedValue < lastIndex {
                currentPlaybackValue(result).wrappedValue += 1
            } else {
                isPlaying = false
            }
        }
        .onChange(of: session.result?.id) {
            fillIndex = 0
            traceIndex = 0
            isPlaying = false
        }
    }

    private func currentPlaybackValue(_ result: AlignmentResult) -> Binding<Double> {
        switch playbackMode {
        case .fill:
            return Binding(
                get: { min(fillIndex, Double(playbackMaxIndex(result))) },
                set: { fillIndex = min(max($0, 0), Double(playbackMaxIndex(result))) }
            )
        case .traceback:
            return Binding(
                get: { min(traceIndex, Double(playbackMaxIndex(result))) },
                set: { traceIndex = min(max($0, 0), Double(playbackMaxIndex(result))) }
            )
        }
    }

    private func playbackMaxIndex(_ result: AlignmentResult) -> Int {
        switch playbackMode {
        case .fill:
            return max((result.rows * result.columns) - 1, 0)
        case .traceback:
            return max(result.tracebackPath.count - 1, 0)
        }
    }

    private func fillCoordinate(index: Int, result: AlignmentResult) -> TraceCoordinate {
        let bounded = min(max(index, 0), max((result.rows * result.columns) - 1, 0))
        return TraceCoordinate(row: bounded / result.columns, column: bounded % result.columns)
    }
}

private struct MatrixGrid: View {
    let result: AlignmentResult
    let playbackMode: MatrixPlaybackMode
    let fillIndex: Int
    let traceIndex: Int

    private var rowIndexes: [Int] {
        Array(0..<result.rows)
    }

    private var columnIndexes: [Int] {
        Array(0..<result.columns)
    }

    private var activePath: Set<TraceCoordinate> {
        playbackMode == .traceback ? Set(result.tracebackPath.prefix(max(1, traceIndex + 1))) : []
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        HeaderCell(text: "", isCorner: true)
                        HeaderCell(text: "0")
                        ForEach(columnIndexes.dropFirst(), id: \.self) { column in
                            HeaderCell(text: sequenceLabel(result.sequenceB, index: column - 1))
                        }
                    }

                    ForEach(rowIndexes, id: \.self) { row in
                        HStack(spacing: 0) {
                            HeaderCell(text: row == 0 ? "0" : sequenceLabel(result.sequenceA, index: row - 1))

                            ForEach(columnIndexes, id: \.self) { column in
                                let coordinate = TraceCoordinate(row: row, column: column)
                                let cellIndex = (row * result.columns) + column
                                MatrixCell(
                                    score: result.matrixScore(row: row, column: column),
                                    move: result.move(row: row, column: column),
                                    isFilled: playbackMode == .traceback || cellIndex <= fillIndex,
                                    isCurrentFill: playbackMode == .fill && cellIndex == fillIndex,
                                    isTrace: activePath.contains(coordinate),
                                    isTerminal: row == result.rows - 1 && column == result.columns - 1,
                                    isOrigin: row == 0 && column == 0
                                )
                                .id(cellID(for: coordinate))
                            }
                        }
                    }
                }
                .background(GeneSyncTheme.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .onAppear {
                scrollToActiveCell(with: proxy, animated: false)
            }
            .onChange(of: fillIndex) {
                guard playbackMode == .fill else { return }
                scrollToActiveCell(with: proxy)
            }
            .onChange(of: traceIndex) {
                guard playbackMode == .traceback else { return }
                scrollToActiveCell(with: proxy)
            }
            .onChange(of: playbackMode) {
                scrollToActiveCell(with: proxy)
            }
        }
        .frame(minHeight: 280)
    }

    private func activeCoordinate() -> TraceCoordinate {
        switch playbackMode {
        case .fill:
            let bounded = min(max(fillIndex, 0), max((result.rows * result.columns) - 1, 0))
            return TraceCoordinate(row: bounded / result.columns, column: bounded % result.columns)
        case .traceback:
            let bounded = min(max(traceIndex, 0), max(result.tracebackPath.count - 1, 0))
            return result.tracebackPath[safe: bounded] ?? TraceCoordinate(row: 0, column: 0)
        }
    }

    private func scrollToActiveCell(with proxy: ScrollViewProxy, animated: Bool = true) {
        let target = cellID(for: activeCoordinate())
        let action = {
            proxy.scrollTo(target, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.14), action)
        } else {
            action()
        }
    }

    private func cellID(for coordinate: TraceCoordinate) -> String {
        "matrix-cell-\(coordinate.row)-\(coordinate.column)"
    }

    private func sequenceLabel(_ sequence: String, index: Int) -> String {
        guard index >= 0, index < sequence.count else {
            return ""
        }

        let stringIndex = sequence.index(sequence.startIndex, offsetBy: index)
        return String(sequence[stringIndex])
    }
}

private struct HeaderCell: View {
    let text: String
    var isCorner = false

    var body: some View {
        Text(text)
            .font(GeneSyncTheme.mono(12, weight: .bold))
            .foregroundStyle(isCorner ? GeneSyncTheme.secondaryText : GeneSyncTheme.primary)
            .frame(width: 48, height: 30)
            .background(isCorner ? GeneSyncTheme.surfaceHighest : GeneSyncTheme.surfaceHigh)
            .overlay {
                Rectangle()
                    .stroke(GeneSyncTheme.outline.opacity(0.8), lineWidth: 0.5)
            }
    }
}

private struct MatrixCell: View {
    let score: Int
    let move: TraceMove
    let isFilled: Bool
    let isCurrentFill: Bool
    let isTrace: Bool
    let isTerminal: Bool
    let isOrigin: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(isFilled ? "\(score)" : "")
                .font(GeneSyncTheme.mono(12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if isFilled {
                Image(systemName: move.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .imageScale(.small)
            }
        }
        .foregroundStyle(isTrace || isCurrentFill ? .white : GeneSyncTheme.text)
        .frame(width: 48, height: 38)
        .background(backgroundColor)
        .overlay {
            Rectangle()
                .stroke(GeneSyncTheme.outline.opacity(0.75), lineWidth: 0.5)
        }
    }

    private var backgroundColor: Color {
        if isTrace {
            return GeneSyncTheme.primary
        }

        if isCurrentFill {
            return GeneSyncTheme.warning
        }

        if !isFilled {
            return GeneSyncTheme.surfaceLow
        }

        if isTerminal {
            return GeneSyncTheme.surfaceHigh
        }

        if isOrigin {
            return GeneSyncTheme.surfaceHighest
        }

        return GeneSyncTheme.surface
    }
}

private extension TraceMove {
    var systemImage: String {
        switch self {
        case .none:
            return "circle.fill"
        case .diagonal:
            return "arrow.up.left"
        case .up:
            return "arrow.up"
        case .left:
            return "arrow.left"
        }
    }

    var label: String {
        switch self {
        case .none:
            return "Origin"
        case .diagonal:
            return "Diagonal"
        case .up:
            return "Up"
        case .left:
            return "Left"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import SwiftUI

struct PageScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 10) {
                    Image("GeneSyncLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(GeneSyncTheme.headline())
                            .foregroundStyle(GeneSyncTheme.text)

                        if let subtitle {
                            Text(subtitle)
                                .font(GeneSyncTheme.body(14))
                                .foregroundStyle(GeneSyncTheme.secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(GridPaperBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SurfacePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeneSyncTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }
}

struct SectionHeading: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(GeneSyncTheme.primary)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.secondaryText)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    var tint: Color = GeneSyncTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.secondaryText)

            Text(value)
                .font(GeneSyncTheme.headline(24))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(GeneSyncTheme.body(12))
                .foregroundStyle(GeneSyncTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeneSyncTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GeneSyncTheme.outline, lineWidth: 1)
        }
    }
}

struct Chip: View {
    let text: String
    var foreground = GeneSyncTheme.primary
    var background = GeneSyncTheme.surfaceLow

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(foreground.opacity(0.16), lineWidth: 1)
            }
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(GeneSyncTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .disabled(isLoading)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(GeneSyncTheme.primary)

                Text(title)
                    .font(GeneSyncTheme.headline(20))
                    .foregroundStyle(GeneSyncTheme.text)

                Text(message)
                    .font(GeneSyncTheme.body(14))
                    .foregroundStyle(GeneSyncTheme.secondaryText)
            }
        }
    }
}

struct GridPaperBackground: View {
    var body: some View {
        GeneSyncTheme.background
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 24
                    let color = GeneSyncTheme.outline.opacity(0.22)
                    var path = Path()

                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }

                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }

                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
            }
    }
}

struct SequenceTextBlock: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GeneSyncTheme.secondaryText)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(GeneSyncTheme.mono())
                    .foregroundStyle(GeneSyncTheme.text)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(GeneSyncTheme.monoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(GeneSyncTheme.outline, lineWidth: 1)
                    }
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var player: MusicPlayer
    @ObservedObject var settings: OverlaySettings
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Group {
                switch settings.layout {
                case .sideBySide: sideBySideLayout
                case .stacked:    stackedLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Timeline bar at the bottom (part of layout flow, not an overlay)
            if settings.showTimeline {
                ProgressBar(player: player, settings: settings)
            }
        }
        .background(backgroundLayer)
        .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
        .frame(width: settings.bubbleWidth, height: settings.bubbleHeight)
        .contextMenu {
            Button("Settings…") { openSettings() }
            Divider()
            Button("Quit Orpheus") { NSApp.terminate(nil) }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if settings.backgroundTheme == .artwork {
            let nsColor = player.artworkAccentColor ?? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            Color(nsColor)
                .opacity(settings.backgroundOpacity)
                .animation(.easeInOut(duration: 0.6), value: player.artworkAccentColor)
        } else if let nsColor = settings.resolvedBackgroundColor {
            Color(nsColor).opacity(settings.backgroundOpacity)
        } else {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(settings.backgroundOpacity)
                .id(settings.backgroundTheme)
        }
    }

    // MARK: - Layouts

    private var sideBySideLayout: some View {
        HStack(spacing: 12) {
            if settings.showArtwork { artworkView(size: settings.artworkSize) }
            textStack(centered: false)
        }
        .padding(12)
    }

    private var stackedLayout: some View {
        VStack(spacing: 8) {
            if settings.showArtwork { artworkView(size: settings.artworkSize) }
            textStack(centered: true)
        }
        .padding(12)
    }

    // MARK: - Artwork

    private func artworkView(size: Double) -> some View {
        let shape = settings.artworkShape
        let radius = size * 0.14

        return Group {
            if let image = player.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(artworkClipShape(size: size, shape: shape))
                    .overlay {
                        ZStack {
                            Color.black.opacity(player.isPlaying ? 0 : 0.45)
                            Image(systemName: "pause.fill")
                                .font(.system(size: size * 0.28, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .opacity(player.isPlaying ? 0 : 1)
                        }
                        .clipShape(artworkClipShape(size: size, shape: shape))
                        .animation(.easeInOut(duration: 0.25), value: player.isPlaying)
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: shape == .circle ? size / 2 : radius,
                                     style: .continuous)
                        .fill(.secondary.opacity(0.2))
                    Image(systemName: player.isPlaying ? "music.note" : "pause.fill")
                        .font(.system(size: size * 0.33))
                        .foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            }
        }
    }

    private func artworkClipShape(size: Double, shape: OverlaySettings.ArtworkShape) -> AnyShape {
        shape == .circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
    }

    // MARK: - Text

    private func textStack(centered: Bool) -> some View {
        let align: HorizontalAlignment = centered ? .center : .leading
        let frameAlign: Alignment      = centered ? .center : .leading

        return VStack(alignment: align, spacing: 3) {
            trackTitle(centered: centered)
            if settings.showArtist && !player.artistName.isEmpty {
                artistName(centered: centered)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlign)
        .animation(.easeInOut(duration: 0.2), value: player.trackName)
    }

    @ViewBuilder
    private func trackTitle(centered: Bool) -> some View {
        let text = player.trackName.isEmpty ? "Not Playing" : player.trackName
        let font = Font.system(size: settings.textScale.titleSize, weight: .semibold)
        if settings.marqueeEnabled {
            MarqueeText(text: text, font: font, speed: settings.marqueeSpeed)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .frame(height: settings.textScale.titleSize + 5)
        } else {
            Text(text)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        }
    }

    @ViewBuilder
    private func artistName(centered: Bool) -> some View {
        let font = Font.system(size: settings.textScale.artistSize)
        if settings.marqueeEnabled {
            MarqueeText(text: player.artistName, font: font, speed: settings.marqueeSpeed * 0.8)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .frame(height: settings.textScale.artistSize + 4)
                .foregroundStyle(.secondary)
        } else {
            Text(player.artistName)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        }
    }
}

// MARK: - AnyShape helper

struct AnyShape: Shape {
    private let path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { path = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { path(rect) }
}

// MARK: - Progress bar

struct ProgressBar: View {
    @ObservedObject var player: MusicPlayer
    @ObservedObject var settings: OverlaySettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let fraction = player.progressFraction
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.15))
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                    if settings.showTimeText {
                        HStack {
                            Spacer()
                            Text(timeLabel)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.trailing, 6)
                        }
                    }
                }
            }
            .frame(height: settings.timelineHeight)
        }
    }

    private var timeLabel: String {
        let elapsed = Int(player.progressFraction * player.duration)
        let total   = Int(player.duration)
        return "\(fmt(elapsed)) / \(fmt(total))"
    }

    private func fmt(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.state = .active
        v.material = material; v.blendingMode = blendingMode
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material; v.blendingMode = blendingMode
    }
}

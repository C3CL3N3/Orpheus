import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: OverlaySettings

    @State private var layoutOpen     = true
    @State private var backgroundOpen = true
    @State private var shapeOpen      = false
    @State private var contentOpen    = true
    @State private var timelineOpen   = true
    @State private var previewOpen    = true

    var body: some View {
        ScrollView {
            VStack(spacing: 1) {
                section("Layout", icon: "rectangle.3.group", isExpanded: $layoutOpen) {
                    layoutContent
                }
                section("Background", icon: "rectangle.fill", isExpanded: $backgroundOpen) {
                    backgroundContent
                }
                section("Shape", icon: "circle.square", isExpanded: $shapeOpen) {
                    shapeContent
                }
                section("Content", icon: "music.note", isExpanded: $contentOpen) {
                    contentContent
                }
                section("Timeline", icon: "timeline.selection", isExpanded: $timelineOpen) {
                    timelineContent
                }
                section("Preview", icon: "eye", isExpanded: $previewOpen) {
                    previewCard
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                // Quit — always visible, no collapse
                Button(role: .destructive) { NSApp.terminate(nil) } label: {
                    Label("Quit Orpheus", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(.vertical, 12)
                .foregroundStyle(.red)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: 620)
    }

    // MARK: - Section shell

    private func section<Content: View>(
        _ title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let body = content()
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .animation(.spring(duration: 0.25), value: isExpanded.wrappedValue)
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 10) {
                    body
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 8)
    }

    // MARK: - Section contents

    private var layoutContent: some View {
        VStack(spacing: 10) {
            rowLabel("Style") {
                Picker("", selection: $settings.layout) {
                    ForEach(OverlaySettings.Layout.allCases) { l in
                        Label(l.label, systemImage: l.icon).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            sliderRow("Width", value: settings.layout == .sideBySide ? $settings.sideBySideWidth : $settings.stackedWidth,
                      in: settings.layout == .sideBySide ? 220...420 : 100...200,
                      display: { "\(Int($0))px" })

            rowLabel("Position") {
                Picker("", selection: $settings.screenAnchor) {
                    ForEach(OverlaySettings.ScreenAnchor.allCases) { a in
                        Label(a.label, systemImage: a.icon).tag(a)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 160)
            }
        }
    }

    private var backgroundContent: some View {
        VStack(spacing: 10) {
            rowLabel("Theme") {
                Picker("", selection: $settings.backgroundTheme) {
                    ForEach(OverlaySettings.BackgroundTheme.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 140)
            }

            if settings.backgroundTheme == .custom {
                rowLabel("Color") {
                    ColorPicker("", selection: customColorBinding, supportsOpacity: false)
                        .labelsHidden()
                }
            }

            sliderRow("Opacity", value: $settings.backgroundOpacity, in: 0.2...1.0,
                      display: { "\(Int($0 * 100))%" })
        }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(red: settings.customBgRed,
                      green: settings.customBgGreen,
                      blue: settings.customBgBlue)
            },
            set: { color in
                if let ns = NSColor(color).usingColorSpace(.sRGB) {
                    settings.customBgRed   = Double(ns.redComponent)
                    settings.customBgGreen = Double(ns.greenComponent)
                    settings.customBgBlue  = Double(ns.blueComponent)
                }
            }
        )
    }

    private var shapeContent: some View {
        VStack(spacing: 10) {
            sliderRow("Corner Radius", value: $settings.cornerRadius, in: 4...28,
                      display: { "\(Int($0))pt" })

            rowLabel("Artwork") {
                Picker("", selection: $settings.artworkShape) {
                    ForEach(OverlaySettings.ArtworkShape.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var contentContent: some View {
        VStack(spacing: 10) {
            rowLabel("Text Size") {
                Picker("", selection: $settings.textScale) {
                    ForEach(OverlaySettings.TextScale.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Toggle("Show Artwork", isOn: $settings.showArtwork)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("Show Artist",  isOn: $settings.showArtist)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("Auto-hide when stopped", isOn: $settings.autoHideWhenStopped)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Toggle("Scroll long titles", isOn: $settings.marqueeEnabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if settings.marqueeEnabled {
                sliderRow("Speed", value: $settings.marqueeSpeed, in: 10...80,
                          display: { speedLabel($0) })
                    .padding(.leading, 8)
            }
        }
    }

    private var timelineContent: some View {
        VStack(spacing: 10) {
            Toggle("Show timeline bar", isOn: $settings.showTimeline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if settings.showTimeline {
                sliderRow("Thickness", value: $settings.timelineThickness, in: 2...8,
                          display: { "\(Int($0))pt" })
                    .padding(.leading, 8)
                Toggle("Show elapsed / total time", isOn: $settings.showTimeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
    }

    // MARK: - Helpers

    private func rowLabel<C: View>(_ label: String, @ViewBuilder trailing: () -> C) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            trailing()
            Spacer(minLength: 0)
        }
    }

    private func sliderRow<V: BinaryFloatingPoint>(
        _ label: String,
        value: Binding<V>,
        in range: ClosedRange<V>,
        display: (V) -> String
    ) -> some View where V.Stride: BinaryFloatingPoint {
        VStack(spacing: 2) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(display(value.wrappedValue))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
            Slider(value: value, in: range)
        }
    }

    private func speedLabel(_ v: Double) -> String {
        switch v {
        case ..<20: "Slow"
        case ..<40: "Medium"
        case ..<60: "Fast"
        default:    "Very Fast"
        }
    }

    // MARK: - Preview helpers

    private var previewTextColor: Color {
        Color(settings.textColor(artworkAccent: nil))
    }

    private var previewSecondaryColor: Color {
        Color(settings.textColor(artworkAccent: nil).withAlphaComponent(0.65))
    }

    private var previewBarColor: Color { previewTextColor }

    // MARK: - Preview card

    private var previewCard: some View {
        let size = settings.artworkSize

        return VStack(spacing: 0) {
            Group {
                switch settings.layout {
                case .sideBySide:
                    HStack(spacing: 12) {
                        if settings.showArtwork { mockArt(size: size) }
                        mockText(centered: false)
                    }
                    .padding(12)
                case .stacked:
                    VStack(spacing: 8) {
                        if settings.showArtwork { mockArt(size: size) }
                        mockText(centered: true)
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if settings.showTimeline {
                ZStack(alignment: .leading) {
                    Rectangle().fill(previewBarColor.opacity(0.15))
                    Rectangle().fill(previewBarColor.opacity(0.7))
                        .frame(width: settings.bubbleWidth * 0.4)
                    if settings.showTimeText {
                        HStack {
                            Spacer()
                            Text("1:40 / 4:02")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(previewBarColor.opacity(0.75))
                                .padding(.trailing, 6)
                        }
                    }
                }
                .frame(height: settings.timelineHeight)
            }
        }
        .background(
            Group {
                if settings.backgroundTheme == .artwork {
                    Color(red: 0.22, green: 0.12, blue: 0.30)
                        .opacity(settings.backgroundOpacity)
                } else if let nsColor = settings.resolvedBackgroundColor {
                    Color(nsColor).opacity(settings.backgroundOpacity)
                } else {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .opacity(settings.backgroundOpacity)
                        .id(settings.backgroundTheme)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
        .frame(width: settings.bubbleWidth, height: settings.bubbleHeight)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    private func mockArt(size: Double) -> some View {
        let radius = size * 0.14
        return ZStack {
            if settings.artworkShape == .circle {
                Circle().fill(.secondary.opacity(0.25))
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.secondary.opacity(0.25))
            }
            Image(systemName: "music.note")
                .font(.system(size: size * 0.33))
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
    }

    private func mockText(centered: Bool) -> some View {
        let a: HorizontalAlignment = centered ? .center : .leading
        let fa: Alignment = centered ? .center : .leading
        return VStack(alignment: a, spacing: 3) {
            Text("Song Title")
                .font(.system(size: settings.textScale.titleSize, weight: .semibold))
                .foregroundStyle(previewTextColor)
                .frame(maxWidth: .infinity, alignment: fa)
            if settings.showArtist {
                Text("Artist Name")
                    .font(.system(size: settings.textScale.artistSize))
                    .foregroundStyle(previewSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: fa)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

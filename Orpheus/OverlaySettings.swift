import AppKit
import Combine

final class OverlaySettings: ObservableObject {

    // MARK: - Layout & Size
    @Published var layout: Layout            = load("layout")    ?? .sideBySide
    @Published var sideBySideWidth: Double   = load("sb_width")  ?? 280
    @Published var stackedWidth: Double      = load("st_width")  ?? 180
    @Published var screenAnchor: ScreenAnchor = load("anchor")   ?? .topRight

    // MARK: - Background
    @Published var backgroundTheme:  BackgroundTheme = load("bg_theme")    ?? .frost
    @Published var backgroundOpacity: Double         = load("bg_opacity")   ?? 0.9
    @Published var customBgRed:   Double = load("custom_bg_r") ?? 0.10
    @Published var customBgGreen: Double = load("custom_bg_g") ?? 0.10
    @Published var customBgBlue:  Double = load("custom_bg_b") ?? 0.10

    // MARK: - Shape
    @Published var cornerRadius: Double     = load("corner_radius")  ?? 16
    @Published var artworkShape: ArtworkShape = load("artwork_shape") ?? .rounded

    // MARK: - Content
    @Published var showArtwork: Bool    = load("show_artwork")    ?? true
    @Published var showArtist: Bool     = load("show_artist")     ?? true
    @Published var textScale: TextScale = load("text_scale")      ?? .medium
    @Published var marqueeEnabled: Bool = load("marquee_enabled") ?? true
    @Published var marqueeSpeed: Double = load("marquee_speed")   ?? 28
    @Published var autoHideWhenStopped: Bool = load("auto_hide")  ?? false

    // MARK: - Timeline
    @Published var showTimeline: Bool        = load("show_timeline")   ?? true
    @Published var timelineThickness: Double = load("timeline_thick")  ?? 3
    @Published var showTimeText: Bool        = load("show_time_text")  ?? false

    // MARK: - Computed geometry

    var bubbleWidth: Double  { layout == .sideBySide ? sideBySideWidth : stackedWidth }
    var timelineHeight: Double { showTimeline ? (showTimeText ? 16 : timelineThickness) : 0 }

    var bubbleHeight: Double {
        switch layout {
        case .sideBySide:
            return 80 + timelineHeight
        case .stacked:
            let artSize = showArtwork ? min(stackedWidth - 24, 140.0) : 0
            let textH   = showArtist ? 46.0 : 28.0
            let gap     = artSize > 0 ? 8.0 : 0.0
            return artSize + textH + gap + 24 + timelineHeight
        }
    }

    var artworkSize: Double {
        layout == .sideBySide ? 56 : min(stackedWidth - 24, 140.0)
    }

    // MARK: - Types

    enum Layout: String, CaseIterable, Identifiable {
        case sideBySide, stacked
        var id: String { rawValue }
        var label: String { self == .sideBySide ? "Side by Side" : "Stacked" }
        var icon:  String { self == .sideBySide ? "rectangle.split.2x1" : "rectangle.split.1x2" }
    }

    enum ScreenAnchor: String, CaseIterable, Identifiable {
        case topRight, topLeft, bottomRight, bottomLeft
        var id: String { rawValue }
        var label: String {
            switch self {
            case .topRight:    return "Top Right"
            case .topLeft:     return "Top Left"
            case .bottomRight: return "Bottom Right"
            case .bottomLeft:  return "Bottom Left"
            }
        }
        var icon: String {
            switch self {
            case .topRight:    return "arrow.up.right.square"
            case .topLeft:     return "arrow.up.left.square"
            case .bottomRight: return "arrow.down.right.square"
            case .bottomLeft:  return "arrow.down.left.square"
            }
        }
    }

    enum BackgroundTheme: String, CaseIterable, Identifiable {
        case frost, system, artwork, dark, light, midnight, ocean, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .frost:    return "Frosted"
            case .system:   return "System"
            case .artwork:  return "Artwork"
            case .dark:     return "Dark"
            case .light:    return "Light"
            case .midnight: return "Midnight"
            case .ocean:    return "Ocean"
            case .custom:   return "Custom"
            }
        }
    }

    // Returns nil for .frost (vibrancy) and .artwork (computed from player in the view layer)
    var resolvedBackgroundColor: NSColor? {
        switch backgroundTheme {
        case .frost, .artwork:
            return nil
        case .system:
            return NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
                    : NSColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
            }
        case .dark:     return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        case .light:    return NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        case .midnight: return NSColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
        case .ocean:    return NSColor(red: 0.05, green: 0.13, blue: 0.22, alpha: 1)
        case .custom:   return NSColor(red: customBgRed, green: customBgGreen, blue: customBgBlue, alpha: 1)
        }
    }

    enum ArtworkShape: String, CaseIterable, Identifiable {
        case rounded, circle
        var id: String { rawValue }
        var label: String { self == .rounded ? "Rounded" : "Circle" }
    }

    enum TextScale: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var titleSize: Double  { switch self { case .small: 11; case .medium: 13; case .large: 16 } }
        var artistSize: Double { switch self { case .small: 9;  case .medium: 11; case .large: 13 } }
    }

    // MARK: - Persistence

    private var bag = Set<AnyCancellable>()

    init() {
        $layout             .sink { save($0.rawValue, "layout") }.store(in: &bag)
        $sideBySideWidth    .sink { save($0, "sb_width") }.store(in: &bag)
        $stackedWidth       .sink { save($0, "st_width") }.store(in: &bag)
        $screenAnchor       .sink { save($0.rawValue, "anchor") }.store(in: &bag)
        $backgroundTheme    .sink { save($0.rawValue, "bg_theme") }.store(in: &bag)
        $backgroundOpacity  .sink { save($0, "bg_opacity") }.store(in: &bag)
        $customBgRed        .sink { save($0, "custom_bg_r") }.store(in: &bag)
        $customBgGreen      .sink { save($0, "custom_bg_g") }.store(in: &bag)
        $customBgBlue       .sink { save($0, "custom_bg_b") }.store(in: &bag)
        $cornerRadius       .sink { save($0, "corner_radius") }.store(in: &bag)
        $artworkShape       .sink { save($0.rawValue, "artwork_shape") }.store(in: &bag)
        $showArtwork        .sink { save($0, "show_artwork") }.store(in: &bag)
        $showArtist         .sink { save($0, "show_artist") }.store(in: &bag)
        $textScale          .sink { save($0.rawValue, "text_scale") }.store(in: &bag)
        $marqueeEnabled     .sink { save($0, "marquee_enabled") }.store(in: &bag)
        $marqueeSpeed       .sink { save($0, "marquee_speed") }.store(in: &bag)
        $autoHideWhenStopped.sink { save($0, "auto_hide") }.store(in: &bag)
        $showTimeline       .sink { save($0, "show_timeline") }.store(in: &bag)
        $timelineThickness  .sink { save($0, "timeline_thick") }.store(in: &bag)
        $showTimeText       .sink { save($0, "show_time_text") }.store(in: &bag)
    }

    // MARK: - Adaptive text color

    func textColor(artworkAccent: NSColor?) -> NSColor {
        switch backgroundTheme {
        case .frost, .system:
            return .labelColor
        case .dark, .midnight, .ocean:
            return .white
        case .light:
            return NSColor(white: 0.08, alpha: 1)
        case .artwork:
            let lum = artworkAccent.map { luminance($0) } ?? 0
            return lum > 0.45 ? NSColor(white: 0.08, alpha: 1) : .white
        case .custom:
            let lum = 0.299 * customBgRed + 0.587 * customBgGreen + 0.114 * customBgBlue
            return lum > 0.45 ? NSColor(white: 0.08, alpha: 1) : .white
        }
    }

    private func luminance(_ color: NSColor) -> Double {
        guard let c = color.usingColorSpace(.sRGB) else { return 0.5 }
        return 0.299 * Double(c.redComponent) + 0.587 * Double(c.greenComponent) + 0.114 * Double(c.blueComponent)
    }
}

// MARK: - UserDefaults helpers

private func save<T>(_ value: T, _ key: String) { UserDefaults.standard.set(value, forKey: key) }

// Overload for String-backed enums — direct cast fails for RawRepresentable types
private func load<T: RawRepresentable>(_ key: String) -> T? where T.RawValue == String {
    guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
    return T(rawValue: raw)
}

private func load<T>(_ key: String) -> T? { UserDefaults.standard.object(forKey: key) as? T }

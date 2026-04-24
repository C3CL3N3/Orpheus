import AppKit
import Combine
import CoreGraphics
import CoreImage

class MusicPlayer: ObservableObject {
    @Published var trackName: String  = ""
    @Published var artistName: String = ""
    @Published var artwork: NSImage?  = nil { didSet { updateArtworkAccent(artwork) } }
    @Published var artworkAccentColor: NSColor? = nil
    @Published var isPlaying: Bool    = false

    // Timeline
    @Published var duration: Double       = 0
    @Published var elapsedAtFetch: Double = 0
    @Published var fetchTimestamp: Date   = Date()

    /// Always current, safe to call from TimelineView every 0.5 s.
    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        let dt = isPlaying ? Date().timeIntervalSince(fetchTimestamp) : 0
        return max(0, min(1, (elapsedAtFetch + dt) / duration))
    }

    // MARK: - Private

    private enum Source { case none, spotify, appleMusic, other }
    private var source: Source = .none
    private var lastArtworkTrack = ""

    private typealias MRGetNowPlayingInfo        = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRRegisterForNotifications = @convention(c) (DispatchQueue) -> Void
    private var mrGetInfo: MRGetNowPlayingInfo?

    private var localObservers: [Any] = []
    private var distObservers:  [Any] = []
    private var timelineTimer:  Timer?

    // MARK: - Init / deinit

    init() {
        loadMediaRemote()
        listenMediaRemote()
        listenSpotify()
        listenAppleMusic()
        refresh()
    }

    deinit {
        timelineTimer?.invalidate()
        localObservers.forEach { NotificationCenter.default.removeObserver($0) }
        distObservers .forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    // MARK: - MediaRemote

    private func loadMediaRemote() {
        guard let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework") as CFURL
        ) else { return }

        if let p = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            mrGetInfo = unsafeBitCast(p, to: MRGetNowPlayingInfo.self)
        }
        if let p = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            unsafeBitCast(p, to: MRRegisterForNotifications.self)(.main)
        }
    }

    private func listenMediaRemote() {
        for name in ["kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                     "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
                     "kMRPlayerPlaybackStateDidChange"] {
            let o = NotificationCenter.default.addObserver(
                forName: .init(name), object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.refresh() }
            }
            localObservers.append(o)
        }
    }

    // MARK: - Spotify

    private func listenSpotify() {
        let o = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] n in
            guard let self, let info = n.userInfo else { return }

            let state  = info["Player State"] as? String ?? ""
            let name   = info["Name"]         as? String ?? ""
            let artist = info["Artist"]       as? String ?? ""

            self.source     = .spotify
            self.trackName  = name
            self.artistName = artist

            // Spotify sends Duration as NSNumber (Int) in milliseconds — as? Double fails on Int
            if let dur = (info["Duration"] as? NSNumber)?.doubleValue, dur > 0 {
                self.duration = dur / 1000.0
            }

            // Must snapshot elapsed BEFORE flipping isPlaying
            let wasPlaying = self.isPlaying
            self.isPlaying = state == "Playing"

            if state == "Playing" {
                if name != self.lastArtworkTrack {
                    // New track
                    self.lastArtworkTrack = name
                    self.elapsedAtFetch   = 0
                    self.fetchTimestamp   = Date()
                    self.fetchSpotifyArtwork()
                } else {
                    if !wasPlaying {
                        // Resuming from pause — elapsedAtFetch is frozen at correct position,
                        // just reset the clock so the formula runs forward from here
                        self.fetchTimestamp = Date()
                    }
                    if self.artwork == nil { self.fetchSpotifyArtwork() }
                }

                // If notification carries exact playback position, use it
                if let pos = (info["Playback Position"] as? NSNumber)?.doubleValue {
                    self.elapsedAtFetch = pos
                    self.fetchTimestamp = Date()
                }

                self.startTimelineTimer()
            } else {
                // Pausing — freeze elapsed at the right position
                if wasPlaying {
                    self.elapsedAtFetch += Date().timeIntervalSince(self.fetchTimestamp)
                    self.fetchTimestamp  = Date()
                }
                self.stopTimelineTimer()
            }
        }
        distObservers.append(o)
    }

    // MARK: - Apple Music

    private func listenAppleMusic() {
        let o = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] n in
            guard let self, let info = n.userInfo else { return }
            let state  = info["Player State"] as? String ?? ""
            let name   = info["Name"]         as? String ?? ""
            let artist = info["Artist"]       as? String ?? ""

            self.source     = .appleMusic
            self.isPlaying  = state == "Playing"
            self.trackName  = name
            self.artistName = artist

            if let data = info["Artwork Data"] as? Data, let img = NSImage(data: data) {
                self.artwork = img
            } else if state == "Playing", name != self.lastArtworkTrack {
                self.lastArtworkTrack = name
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refresh() }
            }
        }
        distObservers.append(o)
    }

    // MARK: - MediaRemote refresh

    func refresh() {
        guard let getMRInfo = mrGetInfo else { return }
        getMRInfo(.main) { [weak self] info in
            guard let self else { return }

            let title  = info["kMRMediaRemoteNowPlayingInfoTitle"]        as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"]       as? String ?? ""
            let rate   = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0

            if !title.isEmpty  { self.trackName  = title }
            if !artist.isEmpty { self.artistName = artist }

            // Don't let lagging MediaRemote overwrite the Spotify notification's isPlaying
            if self.source != .spotify {
                let wasPlaying = self.isPlaying
                self.isPlaying = rate > 0
                if self.isPlaying, !wasPlaying {
                    self.fetchTimestamp = Date()
                    self.startTimelineTimer()
                } else if !self.isPlaying, wasPlaying {
                    self.elapsedAtFetch += Date().timeIntervalSince(self.fetchTimestamp)
                    self.fetchTimestamp  = Date()
                    self.stopTimelineTimer()
                }
            }

            if let dur = info["kMRMediaRemoteNowPlayingInfoDuration"]    as? Double, dur > 0 { self.duration = dur }
            if let ela = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double {
                self.elapsedAtFetch = ela
                self.fetchTimestamp = (info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date) ?? Date()
            }

            if let img = Self.extractArtwork(from: info) { self.artwork = img }
        }
    }

    // MARK: - Timeline timer

    private func startTimelineTimer() {
        guard timelineTimer == nil else { return }
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshTimeline()
        }
    }

    private func stopTimelineTimer() {
        timelineTimer?.invalidate()
        timelineTimer = nil
    }

    private func refreshTimeline() {
        guard let getMRInfo = mrGetInfo else { return }
        getMRInfo(.main) { [weak self] info in
            guard let self else { return }
            if let dur = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double, dur > 0 { self.duration = dur }
            if let ela = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double {
                self.elapsedAtFetch = ela
                self.fetchTimestamp = (info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date) ?? Date()
            }
        }
    }

    // MARK: - Artwork

    private static func extractArtwork(from info: [String: Any]) -> NSImage? {
        let raw = info["kMRMediaRemoteNowPlayingInfoArtworkData"]
        if let data = raw as? Data, !data.isEmpty {
            if let img = NSImage(data: data) { return img }
            if let src = CGImageSourceCreateWithData(data as CFData, nil),
               let cg  = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                return NSImage(cgImage: cg, size: CGSize(width: cg.width, height: cg.height))
            }
        }
        if let img = raw as? NSImage { return img }
        return nil
    }

    private func updateArtworkAccent(_ image: NSImage?) {
        guard let image else { artworkAccentColor = nil; return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let color = Self.dominantColor(from: image)
            DispatchQueue.main.async { self?.artworkAccentColor = color }
        }
    }

    private static func dominantColor(from image: NSImage) -> NSColor? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ci = CIImage(cgImage: cg)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ci,
            kCIInputExtentKey: CIVector(cgRect: ci.extent)
        ]), let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &bitmap, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Darken so it reads well as a background
        return NSColor(red:   CGFloat(bitmap[0]) / 255 * 0.65,
                       green: CGFloat(bitmap[1]) / 255 * 0.65,
                       blue:  CGFloat(bitmap[2]) / 255 * 0.65,
                       alpha: 1)
    }

    private func fetchSpotifyArtwork() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Self.runOsascript(
                "tell application \"Spotify\" to return artwork url of current track"
            ).flatMap(URL.init) else { return }

            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let img = NSImage(data: data) else { return }
                DispatchQueue.main.async { self?.artwork = img }
            }.resume()
        }
    }

    private static func runOsascript(_ script: String) -> String? {
        let t = Process()
        t.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        t.arguments = ["-e", script]
        let out = Pipe(); t.standardOutput = out; t.standardError = Pipe()
        do {
            try t.run(); t.waitUntilExit()
            guard t.terminationStatus == 0 else { return nil }
            return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return nil }
    }
}

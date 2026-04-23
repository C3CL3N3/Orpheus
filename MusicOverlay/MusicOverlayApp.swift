import SwiftUI
import Combine

@main
struct MusicOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

// MARK: -

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var overlayPanel:   NSPanel?
    private var settingsWindow: NSWindow?

    let player   = MusicPlayer()
    let settings = OverlaySettings()
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createOverlayPanel()
        observeChanges()
    }

    // MARK: - Panel creation

    private func createOverlayPanel() {
        let size = panelSize()
        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin(size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level       = .floating
        panel.isOpaque    = false
        panel.backgroundColor = .clear
        panel.hasShadow   = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        panel.contentView = NSHostingView(rootView: ContentView(
            player: player, settings: settings,
            openSettings: { [weak self] in self?.openSettingsWindow() }
        ))
        panel.orderFrontRegardless()
        overlayPanel = panel
    }

    // MARK: - Observation

    private func observeChanges() {
        // Resize & reposition on any setting change
        settings.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] in self?.repositionPanel() }
            .store(in: &bag)

        // Auto-hide when stopped
        player.$isPlaying
            .combineLatest(settings.$autoHideWhenStopped)
            .receive(on: RunLoop.main)
            .sink { [weak self] playing, autoHide in
                guard let panel = self?.overlayPanel else { return }
                let target: CGFloat = (!playing && autoHide) ? 0.08 : 1.0
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.4
                    panel.animator().alphaValue = target
                }
            }
            .store(in: &bag)
    }

    // MARK: - Geometry

    private func panelSize() -> CGSize {
        CGSize(width: settings.bubbleWidth, height: settings.bubbleHeight)
    }

    private func panelOrigin(_ size: CGSize) -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let m: CGFloat = 20
        switch settings.screenAnchor {
        case .topRight:    return CGPoint(x: screen.maxX - size.width - m, y: screen.maxY - size.height - m)
        case .topLeft:     return CGPoint(x: screen.minX + m,              y: screen.maxY - size.height - m)
        case .bottomRight: return CGPoint(x: screen.maxX - size.width - m, y: screen.minY + m)
        case .bottomLeft:  return CGPoint(x: screen.minX + m,              y: screen.minY + m)
        }
    }

    private func repositionPanel() {
        guard let panel = overlayPanel else { return }
        let size = panelSize()
        panel.setFrame(NSRect(origin: panelOrigin(size), size: size), display: true, animate: true)
    }

    // MARK: - Settings window

    func openSettingsWindow() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.title = "Orpheus Settings"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = w
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow { settingsWindow = nil }
    }
}

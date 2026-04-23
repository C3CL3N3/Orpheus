# Orpheus

A lightweight macOS overlay that sits on top of your screen and shows what's currently playing - album art, track name, and artist - for both Spotify and Apple Music.

No menu bar icon, no dock icon. Just a clean, draggable bubble that stays out of your way.

![macOS](https://img.shields.io/badge/macOS-26%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

---

## Download

**[Download the latest DMG from Releases →](../../releases/latest)**

1. Open `Orpheus-1.0.dmg`
2. Drag **Orpheus.app** into your **Applications** folder
3. Right-click the app → **Open** (required on first launch since the app is not notarized yet)

---

## Features

- Works with **Spotify** and **Apple Music** out of the box
- Displays album artwork, track name, and artist
- Live progress bar with optional elapsed / total time
- Multiple layout options - side by side or stacked
- Background themes: Frosted glass, System (dark/light adaptive), Artwork color, Dark, Light, Midnight, Ocean, or any custom color
- Smooth scrolling for long track titles
- Pause overlay on the artwork when playback stops
- Auto-hide when nothing is playing
- Fully customizable through a right-click settings panel
- Draggable - place it wherever you want on screen
- Snap to screen corners (top/bottom left/right)

## Requirements

- macOS 26 Tahoe or later
- Xcode 26 or later (to build from source)

## Build from source

```bash
git clone https://github.com/enzocurci/MusicOverlay.git
cd MusicOverlay
open MusicOverlay.xcodeproj
```

Build and run with **⌘R**. The overlay will appear on screen immediately.

> **Spotify artwork**: on first launch macOS will ask for Automation permission so the app can fetch album art from Spotify. Grant it and you're good.

## Usage

- **Right-click** the overlay to open Settings or quit
- **Drag** the overlay to reposition it anywhere on screen
- In Settings, choose a screen corner to snap back to that position on restart

## Settings

| Section | Options |
|---|---|
| Layout | Side by side / Stacked, width slider, screen anchor |
| Background | Theme picker, opacity slider, custom color picker |
| Shape | Corner radius, artwork shape (rounded / circle) |
| Content | Text size, show/hide artwork & artist, auto-hide, marquee scroll |
| Timeline | Show progress bar, thickness, elapsed/total time label |

## How it works

Orpheus uses macOS's private **MediaRemote** framework to read now-playing info system-wide, and listens to **Spotify** and **Apple Music** distributed notifications for real-time playback state. No third-party dependencies.

## Contributing

Pull requests are welcome. Open an issue first if you're planning something bigger so we can discuss it.

## License

MIT - see [LICENSE](LICENSE).

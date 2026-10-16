# Release Notes - HomeMonitor v2.1.0

## What's New in v2.1.0

- **Locked Window Geometry & Aspect-Fill Stability:** Fixed an issue where 16:9 / 4:3 video feeds with `.aspectRatio(contentMode: .fill)` expanded the parent `ZStack` beyond the physical window height, preventing bottom-left controls and the right carousel from drifting downward.
- **Symmetrically Centered Camera Carousel:** Right-side camera switcher is now strictly centered along the vertical midpoint of the window and snaps to whole camera thumbnails without cutting items in half.
- **Persistent Dark Glass Controls:** Bottom-left camera status, FPS indicator, audio mute toggle, and Settings button stay clearly visible and accessible during live 30fps stream playback.
- **Automated DMG & ZIP Distribution:** Universal macOS binary (`arm64` + `x86_64`) with direct download links and macOS Sonoma/Sequoia Gatekeeper (`xattr -c`) installation instructions.

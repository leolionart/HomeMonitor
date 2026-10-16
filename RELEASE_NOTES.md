# Release Notes - HomeMonitor v2.0.0

## What's New in v2.0.0

- **Universal macOS Binary:** Native support for both Apple Silicon (M1/M2/M3/M4) and Intel Macs (`arm64` + `x86_64`).
- **Menu Bar Quick Access & Dock Panel:** Floating MicDrop-style camera preview accessible right from the macOS status bar.
- **Apple Home-Style Camera Switcher:** Seamless switching between multiple RTSP streams with real-time thumbnail carousel.
- **Ultra-Low Latency RTSP Engine:** Powered by FFmpeg MJPEG streaming with automated reconnection and stream health monitoring.
- **Audio Control & In-App Management:** Integrated audio mute toggle, secure local credential storage, and quick camera addition.
- **Locked Window Geometry & Centered Carousel:** Fixed video frame aspect-fill expansion so bottom-left camera controls and the vertically centered right-hand thumbnail carousel remain stably anchored across all window sizes and stream resolutions.
- **Automated DMG & ZIP Distribution:** Built-in packaging pipeline with direct DMG disk image downloads and macOS Gatekeeper (`xattr -c`) installation instructions.

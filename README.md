# HomeMonitor for macOS

A modern, native macOS camera streaming application designed for Apple Silicon. HomeMonitor allows you to stream RTSP camera feeds with ultra-low latency, switch seamlessly between multiple cameras, and quickly access feeds directly from the macOS Menu Bar.
<img width="390" height="272" alt="file-ae4c242fb41b84d2ae5540e8e80b5d7b" src="https://github.com/user-attachments/assets/45c7eeab-c688-4b8b-bd62-fb402d5b8701" />


---

- **Menu Bar Quick Access:** The menu bar keeps a simple camera icon. Click it to open a floating dock-mode preview above other apps; use **Open App Window** for long viewing.
- **Native macOS Layout:** The camera name, FPS badge, and icon-only Settings control stay in one titlebar-aligned row with Apple-style spacing.
- **MicDrop-style Dock Panel:** Rounded material surface with live status, selected-camera preview, close, open-window, and quit actions. It stays visible until explicitly closed.
- **Simple App Icon:** A minimal home-camera icon is included in the native `.icns` bundle.
- **Full-Bleed 16:9 Video Canvas:** Clean, borderless video window adhering to modern macOS Human Interface Guidelines.
- **Apple Home-Style Camera Switcher:** Floating thumbnail carousel on the right edge allows switching between cameras in one click; use **New** to add a camera.
- **In-App Camera Management:** Configure camera name and RTSP stream URL directly in the app. Full credentials and stream URLs remain hidden from video viewports.
- **Ultra-Low Latency Playback:** Built-in MJPEG pipe stream processor powered by FFmpeg.
- **Privacy First:** All configurations and camera credentials are kept local on your Mac. No cloud connection or external tracking.

---

## Requirements

- **Operating System:** macOS 14.0 (Sonoma) or newer (Apple Silicon Mac recommended).
- **Dependencies:** `ffmpeg` installed locally via Homebrew:
  ```bash
  brew install ffmpeg
  ```
- **Build Tools:** Apple Command Line Tools (no full Xcode installation required).

---

## Building and Installing

Clone the repository and run the build script:

```bash
git clone https://github.com/leolionart/HomeMonitor.git
cd HomeMonitor

# Run the build script (creates build/HomeMonitor.app)
./scripts/build_app.sh

# Optional: Package DMG and ZIP distribution
./scripts/package_dmg.sh

# Copy to Applications
cp -R build/HomeMonitor.app /Applications/
```

Launch `HomeMonitor` from `/Applications` or Spotlight.

---

## Adding Your Camera

1. Launch HomeMonitor.
2. Click **New** in the camera thumbnail carousel.
3. Provide a friendly name (e.g. *Gate*, *Garage*, *Front Door*) and your RTSP URL:
   ```text
   rtsp://user:password@192.168.1.100:554/stream
   ```
4. Click **Save Settings**. The stream connects automatically.

---

## License

This project is licensed under the MIT License.

# HomeMonitor for macOS

A modern, native macOS camera streaming application designed for Apple Silicon. HomeMonitor allows you to stream RTSP camera feeds with ultra-low latency, switch seamlessly between multiple cameras, and quickly access feeds directly from the macOS Menu Bar.

---

## Key Features

- **Menu Bar Quick Access:** Toggle the live camera window instantly from the system menu bar.
- **Full-Bleed 16:9 Video Canvas:** Clean, borderless video window adhering to modern macOS Human Interface Guidelines.
- **Apple Home-Style Camera Switcher:** Floating thumbnail carousel on the right edge allows switching between cameras in one click.
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
git clone https://github.com/your-username/HomeMonitor.git
cd HomeMonitor

# Run the build script
bash scripts/build_app.sh

# Copy to Applications
cp -R /tmp/HomeMonitor-build/HomeMonitor.app /Applications/
```

Launch `HomeMonitor` from `/Applications` or Spotlight.

---

## Adding Your Camera

1. Launch HomeMonitor.
2. Click **Add Cam** (or the `+` button in the camera thumbnail carousel).
3. Provide a friendly name (e.g. *Gate*, *Garage*, *Front Door*) and your RTSP URL:
   ```text
   rtsp://user:password@192.168.1.100:554/stream
   ```
4. Click **Save Settings**. The stream connects automatically.

---

## License

This project is licensed under the MIT License.

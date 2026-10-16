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

## Download & Installation

### 1. Download

Pre-built Universal binaries (supporting both Apple Silicon M1/M2/M3/M4 and Intel Macs) are available on GitHub Releases:

- **[Download HomeMonitor.dmg (Disk Image)](https://github.com/leolionart/HomeMonitor/releases/latest/download/HomeMonitor.dmg)** *(Recommended)*
- **[Download HomeMonitor.zip (Archive)](https://github.com/leolionart/HomeMonitor/releases/latest/download/HomeMonitor.zip)**
- **[View All Releases](https://github.com/leolionart/HomeMonitor/releases)**

### 2. Standard Installation via DMG

1. Download and open `HomeMonitor.dmg`.
2. Drag `HomeMonitor.app` into your **Applications** folder.
3. Ensure `ffmpeg` is installed (`brew install ffmpeg`).

### 3. macOS Gatekeeper Note ("App is damaged and can't be opened" / Move to Trash)

Because HomeMonitor is an open-source project and is ad-hoc signed without a paid Apple Developer Certificate ($99/year), macOS Gatekeeper will attach a quarantine flag to the downloaded app and may display:

> *"HomeMonitor.app is damaged and can’t be opened. You should move it to the Trash."*  
> or *"Apple cannot verify that HomeMonitor is free of malware."*

**The app is not damaged.** To allow macOS to open it normally, use either of these methods:

#### Option A: One-line Terminal Command (Recommended)
Open Terminal and run:
```bash
xattr -c /Applications/HomeMonitor.app
```
*(or `xattr -d com.apple.quarantine /Applications/HomeMonitor.app`)*  
This clears the quarantine flag. You can now launch HomeMonitor from Launchpad, Spotlight, or Applications normally.
#### Option B: GUI Bypass (No Terminal)
1. In Finder, open your **Applications** folder.
2. **Right-click** (or **Control-click**) `HomeMonitor.app` and select **Open**.
3. In the warning prompt, click **Open**.
4. *If no Open prompt appears:* Open **System Settings** → **Privacy & Security** → scroll down to the **Security** section, and click **Open Anyway** next to the HomeMonitor notice.

---

### 4. One-Line Automated Install (Terminal)

You can also download, install, and configure HomeMonitor in one command:

```bash
command -v ffmpeg >/dev/null 2>&1 || brew install ffmpeg && \
curl -fsSL https://github.com/leolionart/HomeMonitor/releases/latest/download/HomeMonitor.zip -o /tmp/HomeMonitor.zip && \
unzip -q -o /tmp/HomeMonitor.zip -d /Applications/ && \
xattr -c /Applications/HomeMonitor.app && \
rm -f /tmp/HomeMonitor.zip && \
open /Applications/HomeMonitor.app
```

---

## Building from Source

If you prefer building from source, clone the repository and run:

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

import AppKit
import Foundation
import SwiftUI

/// Keeps the last decoded frame per camera (as JPEG bytes) so thumbnails and
/// the main view can show a snapshot instead of black while a camera is not
/// streaming. JPEG data is decoded lazily on demand instead of retaining an
/// NSImage per camera.
@MainActor
final class CameraSnapshotStore: ObservableObject {
    @Published private(set) var revision: Int = 0

    private struct Entry {
        var data: Data
        var capturedAt: Date
    }

    private var entries: [UUID: Entry] = [:]
    private static let minimumWriteInterval: TimeInterval = 1.0

    /// Throttled per camera so sequential snapshot captures never drop.
    func record(_ jpeg: Data, for cameraID: UUID?) {
        guard let cameraID else { return }
        let now = Date()
        if let existing = entries[cameraID],
           now.timeIntervalSince(existing.capturedAt) < Self.minimumWriteInterval {
            return
        }
        entries[cameraID] = Entry(data: jpeg, capturedAt: now)
        revision &+= 1
    }

    /// Seconds since the stored snapshot for a camera, or nil if none.
    func age(of cameraID: UUID, now: Date = Date()) -> TimeInterval? {
        entries[cameraID].map { now.timeIntervalSince($0.capturedAt) }
    }

    func forget(_ cameraID: UUID) {
        guard entries[cameraID] != nil else { return }
        entries[cameraID] = nil
        revision &+= 1
    }

    func image(for cameraID: UUID?) -> NSImage? {
        guard let cameraID, let entry = entries[cameraID] else { return nil }
        return NSImage(data: entry.data)
    }
}

@MainActor
final class RTSPStreamPlayer: ObservableObject {
    @Published var currentFrame: NSImage?
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var fpsText: String = "0 fps"

    private static let mutedDefaultsKey = "HomeMonitor.IsMuted"
    @Published var isMuted: Bool = UserDefaults.standard.object(forKey: "HomeMonitor.IsMuted") as? Bool ?? true

    /// True while a stream is (re)connecting: covers both the ffmpeg restart
    /// gap on camera switches and silent mid-stream freezes.
    @Published private(set) var isConnecting: Bool = false

    let snapshots = CameraSnapshotStore()

    /// Camera whose stream is currently active; set by StreamHub before play.
    var currentCameraID: UUID?

    private var process: Process?
    private var audioProcess: Process?
    private var outputPipe: Pipe?
    private var streamTask: Task<Void, Never>?
    private var frameCount: Int = 0
    private var lastFpsCalculation: Date = Date()
    private var lastFrameAt: Date?
    private var stallCheckTask: Task<Void, Never>?

    var rtspURL: String

    static func findExecutable(named name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    init(rtspURL: String = "") {
        self.rtspURL = rtspURL
    }

    func setURLAndPlay(_ url: String) {
        guard !url.isEmpty else {
            stop()
            self.rtspURL = ""
            return
        }

        if isStreaming && self.rtspURL == url {
            return
        }

        // Keep the last frame on screen while the new stream spins up.
        stop(clearFrame: false)
        // If we already have a still of the *new* camera, show that while
        // connecting instead of the old camera's last frame.
        if snapshots.image(for: currentCameraID) != nil {
            currentFrame = nil
        }
        self.rtspURL = url
        isConnecting = true
        start()
    }

    func start() {
        guard !rtspURL.isEmpty else { return }
        guard !isStreaming else { return }
        isStreaming = true
        errorMessage = nil
        fpsText = "0 fps"
        frameCount = 0
        lastFpsCalculation = Date()
        guard let ffmpegPath = Self.findExecutable(named: "ffmpeg") else {
            errorMessage = "FFmpeg not found in standard paths"
            isStreaming = false
            isConnecting = false
            return
        }

        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: ffmpegPath)
        proc.arguments = [
            "-loglevel", "quiet",
            "-rtsp_transport", "tcp",
            "-i", rtspURL,
            "-an",
            "-f", "image2pipe",
            "-vcodec", "mjpeg",
            "-q:v", "3",
            "pipe:1"
        ]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            self.process = proc
            self.outputPipe = pipe
            readMJPEGStream(pipe: pipe)
            startStallCheck()
            if !isMuted {
                startAudio()
            }
        } catch {
            errorMessage = "Failed to launch ffmpeg: \(error.localizedDescription)"
            isStreaming = false
            isConnecting = false
        }
    }

    func stop(clearFrame: Bool = true) {
        isStreaming = false
        isConnecting = false
        stopAudio()
        stallCheckTask?.cancel()
        stallCheckTask = nil
        streamTask?.cancel()
        streamTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        outputPipe = nil
        if clearFrame {
            currentFrame = nil
        }
    }

    func startAudio() {
        guard !isMuted, !rtspURL.isEmpty else { return }
        stopAudio()
        guard let ffplayPath = Self.findExecutable(named: "ffplay") else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffplayPath)
        proc.arguments = [
            "-nodisp",
            "-loglevel", "quiet",
            "-rtsp_transport", "tcp",
            rtspURL
        ]
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            self.audioProcess = proc
        } catch {
            print("[Audio] Failed to launch ffplay: \(error.localizedDescription)")
        }
    }

    func stopAudio() {
        if let proc = audioProcess, proc.isRunning {
            proc.terminate()
        }
        audioProcess = nil
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: Self.mutedDefaultsKey)
        if isMuted {
            stopAudio()
        } else {
            startAudio()
        }
    }

    private func readMJPEGStream(pipe: Pipe) {
        let handle = pipe.fileHandleForReading

        streamTask = Task.detached(priority: .userInitiated) { [weak self] in
            var buffer = Data()
            let soi = Data([0xFF, 0xD8]) // Start Of Image (JPEG SOI)
            let eoi = Data([0xFF, 0xD9]) // End Of Image (JPEG EOI)

            while !Task.isCancelled {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    break
                }
                buffer.append(chunk)

                while let startRange = buffer.range(of: soi) {
                    if startRange.lowerBound > 0 {
                        buffer.removeSubrange(0..<startRange.lowerBound)
                    }

                    guard let endRange = buffer.range(of: eoi) else {
                        break
                    }

                    let frameLength = endRange.upperBound
                    let frameData = buffer.subdata(in: 0..<frameLength)
                    buffer.removeSubrange(0..<frameLength)

                    if let image = NSImage(data: frameData) {
                        await self?.updateFrame(image, jpeg: frameData)
                    }
                }
            }
            if !Task.isCancelled {
                await self?.handleStreamTerminated()
            }
        }
    }

    private func updateFrame(_ image: NSImage, jpeg: Data) {
        self.currentFrame = image
        self.lastFrameAt = Date()
        self.isConnecting = false
        self.snapshots.record(jpeg, for: self.currentCameraID)
        self.frameCount += 1
        let now = Date()
        let interval = now.timeIntervalSince(lastFpsCalculation)
        if interval >= 1.0 {
            let fps = Double(frameCount) / interval
            self.fpsText = String(format: "%.1f fps", fps)
            self.frameCount = 0
            self.lastFpsCalculation = now
        }
    }

    /// Detects mid-stream stalls (frames stop arriving without ffmpeg
    /// exiting) so the connecting indicator reflects reality.
    private func startStallCheck() {
        stallCheckTask?.cancel()
        stallCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, self.isStreaming else { return }
                if let last = self.lastFrameAt, Date().timeIntervalSince(last) > 1.0 {
                    self.isConnecting = true
                }
            }
        }
    }

    private func handleStreamTerminated() {
        stopAudio()
        guard isStreaming else { return }
        isStreaming = false
        isConnecting = false
        errorMessage = "Stream disconnected"
    }
}

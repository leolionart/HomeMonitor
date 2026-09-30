import AppKit
import Foundation
import SwiftUI

@MainActor
final class RTSPStreamPlayer: ObservableObject {
    @Published var currentFrame: NSImage?
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var fpsText: String = "0 fps"

    private var process: Process?
    private var outputPipe: Pipe?
    private var streamTask: Task<Void, Never>?
    private var frameCount: Int = 0
    private var lastFpsCalculation: Date = Date()

    var rtspURL: String

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

        stop()
        self.rtspURL = url
        start()
    }

    func start() {
        guard !rtspURL.isEmpty else { return }
        guard !isStreaming else { return }
        isStreaming = true
        errorMessage = nil

        let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
        guard FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            errorMessage = "FFmpeg not found at /opt/homebrew/bin/ffmpeg"
            isStreaming = false
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
        proc.standardError = Pipe()

        do {
            try proc.run()
            self.process = proc
            self.outputPipe = pipe
            readMJPEGStream(pipe: pipe)
        } catch {
            errorMessage = "Failed to launch ffmpeg: \(error.localizedDescription)"
            isStreaming = false
        }
    }

    func stop() {
        isStreaming = false
        streamTask?.cancel()
        streamTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        outputPipe = nil
        currentFrame = nil
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
                        await self?.updateFrame(image)
                    }
                }
            }

            await self?.handleStreamTerminated()
        }
    }

    private func updateFrame(_ image: NSImage) {
        self.currentFrame = image
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

    private func handleStreamTerminated() {
        if isStreaming {
            isStreaming = false
            errorMessage = "Stream disconnected"
        }
    }
}

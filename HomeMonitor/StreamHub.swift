import AppKit
import Combine

@MainActor
final class StreamHub: ObservableObject {
    static let shared = StreamHub()

    let player = RTSPStreamPlayer()
    @Published private(set) var selectedCameraID: UUID?

    private static let selectionDefaultsKey = "HomeMonitor.SelectedCameraID"

    private init() {
        selectedCameraID = UserDefaults.standard
            .string(forKey: Self.selectionDefaultsKey)
            .flatMap(UUID.init(uuidString:))
    }

    func activeCamera(in cameras: [CameraConfig]) -> CameraConfig? {
        if let id = selectedCameraID, let camera = cameras.first(where: { $0.id == id }) {
            return camera
        }
        return cameras.first
    }

    func select(_ camera: CameraConfig) {
        select(cameraID: camera.id, rtspURL: camera.rtspURL)
    }

    func startStreamIfNeeded(in cameras: [CameraConfig]) {
        guard let camera = activeCamera(in: cameras) else {
            player.stop()
            return
        }
        select(cameraID: camera.id, rtspURL: camera.rtspURL)
    }

    func select(cameraID: UUID, rtspURL: String) {
        if selectedCameraID != cameraID {
            selectedCameraID = cameraID
            UserDefaults.standard.set(cameraID.uuidString, forKey: Self.selectionDefaultsKey)
        }
        player.currentCameraID = cameraID
        player.setURLAndPlay(rtspURL)
    }

    func cameraWasRemoved(_ cameraID: UUID) {
        player.snapshots.forget(cameraID)
    }

    // MARK: - Inactive-camera snapshot polling

    private var pollTask: Task<Void, Never>?
    private static let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    private static let snapshotFreshness: TimeInterval = 10
    private static let snapshotSweepInterval: TimeInterval = 5
    private static let captureTimeout: TimeInterval = 12

    /// Grabs one JPEG per inactive camera so carousel thumbnails and the
    /// connecting state always have a current still for every camera.
    func startSnapshotPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.captureMissingSnapshots()
                try? await Task.sleep(for: .seconds(Self.snapshotSweepInterval))
            }
        }
    }

    func stopSnapshotPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func captureMissingSnapshots() async {
        guard FileManager.default.isExecutableFile(atPath: Self.ffmpegPath) else { return }
        for camera in AppState.shared.cameras {
            guard !Task.isCancelled, selectedCameraID != camera.id else { continue }
            if let age = player.snapshots.age(of: camera.id), age < Self.snapshotFreshness { continue }
            await captureSnapshot(of: camera)
        }
    }

    private func captureSnapshot(of camera: CameraConfig) async {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeMonitor-snapshot-\(camera.id.uuidString).jpg")
        try? FileManager.default.removeItem(at: outputURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.ffmpegPath)
        process.arguments = [
            "-loglevel", "quiet",
            "-rtsp_transport", "tcp",
            "-i", camera.rtspURL,
            "-frames:v", "1",
            "-q:v", "5",
            "-y", outputURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return
        }

        let deadline = Date().addingTimeInterval(Self.captureTimeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        if process.isRunning {
            process.terminate()
        }

        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let data = try? Data(contentsOf: outputURL), !data.isEmpty else { return }
        player.snapshots.record(data, for: camera.id)
    }
}

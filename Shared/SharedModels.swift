import Foundation

struct CameraConfig: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var rtspURL: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        rtspURL: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.rtspURL = rtspURL
        self.isEnabled = isEnabled
    }
}

final class CameraConfigStore {
    private static let userDefaultsKey = "HomeMonitor.ConfiguredCameras"

    // Default template cameras (Placeholder for first launch, no private IP or credentials)
    static let defaultCameras: [CameraConfig] = []

    static func loadCameras() -> [CameraConfig] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([CameraConfig].self, from: data) else {
            return defaultCameras
        }
        return list
    }

    static func saveCameras(_ list: [CameraConfig]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

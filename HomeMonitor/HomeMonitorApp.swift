import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var cameras: [CameraConfig] = []

    init() {
        self.cameras = CameraConfigStore.loadCameras()
    }

    func addCamera(name: String, rtspURL: String) {
        let cam = CameraConfig(name: name, rtspURL: rtspURL)
        cameras.append(cam)
        CameraConfigStore.saveCameras(cameras)
    }

    func updateCamera(id: UUID, name: String, rtspURL: String) {
        if let idx = cameras.firstIndex(where: { $0.id == id }) {
            cameras[idx].name = name
            cameras[idx].rtspURL = rtspURL
            CameraConfigStore.saveCameras(cameras)
        }
    }

    func removeCameras(at offsets: IndexSet) {
        cameras.remove(atOffsets: offsets)
        CameraConfigStore.saveCameras(cameras)
    }
}

@main
struct HomeMonitorApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("HomeMonitor", id: "main-camera-window") {
            CameraStreamMainView(appState: appState)
                .frame(width: 860, height: 484) // 16:9 native aspect ratio without black bars
                .background(
                    WindowAccessor { window in
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        window.styleMask.insert(.fullSizeContentView)
                        window.isMovableByWindowBackground = true
                        window.aspectRatio = NSSize(width: 16, height: 9)
                    }
                )
                .onAppear {
                    setupMenuBar()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    private func setupMenuBar() {
        MenuBarManager.shared.configure {
            let activeWindows = NSApp.windows.filter { window in
                // Filter out status bar window, only grab application document windows
                !(window.className.contains("StatusBar") || window.className.contains("Popover"))
            }

            if let targetWindow = activeWindows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
                if targetWindow.isKeyWindow {
                    targetWindow.orderOut(nil)
                } else {
                    targetWindow.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else if let targetWindow = activeWindows.first {
                targetWindow.deminiaturize(nil)
                targetWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                openWindow(id: "main-camera-window")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var cameras: [CameraConfig] = []

    private init() {
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
        let removedIDs = offsets.map { cameras[$0].id }
        cameras.remove(atOffsets: offsets)
        CameraConfigStore.saveCameras(cameras)
        for id in removedIDs {
            StreamHub.shared.cameraWasRemoved(id)
        }
    }
}

@MainActor
final class HomeMonitorAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: HomeMonitorAppDelegate?

    var onOpenMainWindow: (() -> Void)?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Covers closes that bypass windowShouldClose (e.g. programmatic close:).
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                HomeMonitorAppDelegate.shared?.updateActivationPolicy()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            onOpenMainWindow?()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        StreamHub.shared.stopSnapshotPolling()
        StreamHub.shared.player.stop()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of destroy: keeps the scene alive, drops the Dock icon.
        sender.orderOut(nil)
        updateActivationPolicy()
        return false
    }

    func updateActivationPolicy() {
        DispatchQueue.main.async {
            let hasVisibleMainWindows = NSApp.windows.contains { window in
                !(window is NSPanel) && window.canBecomeMain && window.isVisible
            }
            if !hasVisibleMainWindows {
                _ = NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

@main
struct HomeMonitorApp: App {
    @NSApplicationDelegateAdaptor(HomeMonitorAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared
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
                        window.isReleasedWhenClosed = false
                        window.delegate = (NSApp.delegate as? HomeMonitorAppDelegate) ?? HomeMonitorAppDelegate.shared
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
        StreamHub.shared.startStreamIfNeeded(in: appState.cameras)
        StreamHub.shared.startSnapshotPolling()
        if let delegate = (NSApp.delegate as? HomeMonitorAppDelegate) ?? HomeMonitorAppDelegate.shared {
            delegate.onOpenMainWindow = openMainWindow
        }
        MenuBarManager.shared.configure(onOpenMainWindow: openMainWindow)
    }

    private func openMainWindow() {
        _ = NSApp.setActivationPolicy(.regular)

        let mainWindows = NSApp.windows.filter { window in
            !(window is NSPanel) && window.canBecomeMain
        }
        if let window = mainWindows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = mainWindows.first {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main-camera-window")
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

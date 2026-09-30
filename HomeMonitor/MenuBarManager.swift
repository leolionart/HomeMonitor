import AppKit
import Foundation

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var onToggleMainWindow: (() -> Void)?

    private override init() {
        super.init()
    }

    func configure(onToggleMainWindow: @escaping () -> Void) {
        self.onToggleMainWindow = onToggleMainWindow
        setupStatusBarItem()
    }

    private func setupStatusBarItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "HomeMonitor")
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        onToggleMainWindow?()
    }
}

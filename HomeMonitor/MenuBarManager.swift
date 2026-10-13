import AppKit
import Foundation

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var onOpenMainWindow: (() -> Void)?
    private let dockPanel = DockPanelController()

    private override init() {
        super.init()
    }

    func configure(onOpenMainWindow: @escaping () -> Void) {
        self.onOpenMainWindow = onOpenMainWindow
        dockPanel.onOpenMainWindow = { [weak self] in
            self?.onOpenMainWindow?()
        }

        guard statusItem == nil else { return }
        setupStatusBarItem()
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "HomeMonitor")
        button.image?.isTemplate = true
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            dockPanel.toggle(relativeTo: sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Open App Window", action: #selector(openMainWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(.separator())
        let isMuted = StreamHub.shared.player.isMuted
        let muteItem = menu.addItem(withTitle: isMuted ? "Unmute Audio" : "Mute Audio", action: #selector(toggleMute), keyEquivalent: "m")
        muteItem.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit HomeMonitor", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleMute() {
        StreamHub.shared.player.toggleMute()
    }

    @objc private func openMainWindow() {
        onOpenMainWindow?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

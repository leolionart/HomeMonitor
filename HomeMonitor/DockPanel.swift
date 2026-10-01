import AppKit
import SwiftUI

private struct DockMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
    }
}

struct DockPanelView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var hub: StreamHub
    @ObservedObject var player: RTSPStreamPlayer
    @ObservedObject var snapshots: CameraSnapshotStore

    let onOpenMainWindow: () -> Void
    let onClose: () -> Void

    private var activeCamera: CameraConfig? {
        hub.activeCamera(in: appState.cameras)
    }

    private var isLive: Bool {
        player.currentFrame != nil && !player.isConnecting
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            videoPreview
        }
        .frame(width: 300)
        .background(DockMaterialView())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .padding(8)
    }

    private var header: some View {
        HStack(spacing: 7) {
            statusPill(player.isConnecting ? "Connecting" : (isLive ? "Live" : "Offline"), color: isLive ? .green : .orange)
            if activeCamera != nil {
                cameraSelector
            }
            Spacer(minLength: 4)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close dock mode")
            .accessibilityLabel("Close dock mode")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func statusPill(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func cameraLabel(_ title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    private var cameraSelector: some View {
        Menu {
            ForEach(appState.cameras) { camera in
                Button {
                    hub.select(camera)
                } label: {
                    HStack {
                        Text(camera.name)
                        if camera.id == hub.selectedCameraID {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let activeCamera {
                    cameraLabel(activeCamera.name)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Select camera")
        .accessibilityLabel("Select camera")
    }

    private var videoPreview: some View {
        ZStack {
            Color.black
            if let frame = player.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let snapshot = snapshots.image(for: hub.activeCamera(in: appState.cameras)?.id) {
                Image(nsImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.45))
                if player.isStreaming || player.isConnecting {
                    VStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Connecting…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                } else {
                    Text("Offline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                VStack(spacing: 5) {
                    Image(systemName: player.isStreaming || player.isConnecting ? "hourglass" : "video.slash")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(player.isStreaming || player.isConnecting ? "Connecting…" : "No live frame")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isLive ? Color.green : (player.isConnecting ? Color.orange : Color.red))
                    .frame(width: 6, height: 6)
                Text(isLive ? player.fpsText : (player.isConnecting ? "CONNECTING" : "OFFLINE"))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.62), in: Capsule())
            .padding(7)
        }
        .overlay(alignment: .topTrailing) {
            openWindowButton
                .padding(8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var openWindowButton: some View {
        Button(action: onOpenMainWindow) {
            Image(systemName: "pip.exit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.62), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("Open the full HomeMonitor window")
        .accessibilityLabel("Open HomeMonitor window")
     }
}

@MainActor
final class DockPanelController {
    var onOpenMainWindow: (() -> Void)?

    private var panel: NSPanel?

    func toggle(relativeTo button: NSStatusBarButton?) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton?) {
        let panel = makePanelIfNeeded()
        position(panel, relativeTo: button)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let root = DockPanelView(
            appState: .shared,
            hub: .shared,
            player: StreamHub.shared.player,
            snapshots: StreamHub.shared.player.snapshots,
            onOpenMainWindow: { [weak self] in
                self?.hide()
                self?.onOpenMainWindow?()
            },
            onClose: { [weak self] in self?.hide() }
        )
        let host = NSHostingView(rootView: root)
        let contentSize = host.fittingSize
        host.frame = NSRect(origin: .zero, size: contentSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, relativeTo button: NSStatusBarButton?) {
        let size = panel.frame.size
        let screen = button?.window?.screen ?? NSScreen.main
        guard let anchor = button?.window?.frame else {
            if let visible = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 4, y: visible.maxY - size.height + 2))
            }
            return
        }

        var origin = NSPoint(x: anchor.maxX - size.width + 16, y: anchor.minY - size.height + 6)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)
            origin.y = max(origin.y, visible.minY + 4)
        }
        panel.setFrameOrigin(origin)
    }
}

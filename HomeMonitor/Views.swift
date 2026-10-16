import AppKit
import Combine
import SwiftUI

@MainActor
final class UnifiedCameraViewModel: ObservableObject {
    @Published var showingAddEditSheet: Bool = false
    @Published var editingCamera: CameraConfig? = nil
    @Published var formName: String = ""
    @Published var formURL: String = ""
    @Published var isPlayerUIVisible: Bool = true

    func openAddSheet() {
        editingCamera = nil
        formName = ""
        formURL = "rtsp://"
        showingAddEditSheet = true
    }

    func openEditSheet(for camera: CameraConfig) {
        editingCamera = camera
        formName = camera.name
        formURL = camera.rtspURL
        showingAddEditSheet = true
    }
}

struct CameraStreamMainView: View {
    @ObservedObject var appState: AppState
    @StateObject private var vm = UnifiedCameraViewModel()
    @StateObject private var hub = StreamHub.shared
    @ObservedObject private var player = StreamHub.shared.player
    private var activeCamera: CameraConfig? {
        hub.activeCamera(in: appState.cameras)
    }

    var body: some View {
        GeometryReader { windowGeo in
            ZStack {
                // 1. Video surface: strictly locked to windowGeo.size so .aspectRatio(contentMode: .fill)
                // NEVER overflows or expands the parent ZStack beyond the physical window!
                CameraVideoSurface(
                    size: windowGeo.size,
                    currentFrame: player.currentFrame,
                    snapshot: player.snapshots.image(for: activeCamera?.id),
                    isStreaming: player.isStreaming,
                    isConnecting: player.isConnecting,
                    errorMessage: player.errorMessage,
                    onAddCamera: { vm.openAddSheet() },
                    onReconnect: {
                        if let cam = activeCamera {
                            player.setURLAndPlay(cam.rtspURL)
                        }
                    }
                )
                .frame(width: windowGeo.size.width, height: windowGeo.size.height)

                // 2. Full-window pointer tracker for hover effects
                Color.clear
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            vm.isPlayerUIVisible = hovering
                        }
                    }

                // 3. Bottom-left controls island (Camera name, status, audio, settings)
                cameraInfoCard
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    .frame(width: windowGeo.size.width, height: windowGeo.size.height, alignment: .bottomLeading)
                    .opacity(vm.isPlayerUIVisible ? 1.0 : 0.85)

                // 4. Right carousel: Strictly centered at the exact vertical middle (windowGeo.size.height / 2)
                cameraThumbnailCarousel(availableHeight: windowGeo.size.height)
                    .padding(.trailing, 20)
                    .frame(width: windowGeo.size.width, height: windowGeo.size.height, alignment: .trailing)
                    .opacity(vm.isPlayerUIVisible ? 1.0 : 0.85)
            }
            .frame(width: windowGeo.size.width, height: windowGeo.size.height)
            .clipped()
            .environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $vm.showingAddEditSheet) {
            cameraFormSheet
        }
        .onAppear {
            hub.startStreamIfNeeded(in: appState.cameras)
        }
        .onChange(of: appState.cameras) { _, newCameras in
            guard let camera = hub.activeCamera(in: newCameras) else {
                player.stop()
                return
            }
            if hub.selectedCameraID != camera.id {
                hub.select(camera)
            } else {
                player.setURLAndPlay(camera.rtspURL)
            }
        }
    }

private struct CameraVideoSurface: View {
    let size: CGSize
    let currentFrame: NSImage?
    let snapshot: NSImage?
    let isStreaming: Bool
    let isConnecting: Bool
    let errorMessage: String?
    let onAddCamera: () -> Void
    let onReconnect: () -> Void

    var body: some View {
        ZStack {
            Color.black

            if let frame = currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if let snapshot {
                ZStack {
                    Image(nsImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.45))
                    if isStreaming || isConnecting {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Connecting to stream…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    } else if errorMessage != nil {
                        errorCard
                    }
                }
            } else if isStreaming || isConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting to stream...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if errorMessage != nil {
                errorCard
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.4))
                    Text("No Camera Selected")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    Button("Add Camera", action: onAddCamera)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(currentFrame == nil)
    }

    private var errorCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Stream Disconnected")
                .font(.headline)
                .foregroundColor(.white)
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Button("Reconnect", action: onReconnect)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


    private var cameraInfoCard: some View {
        HStack(spacing: 12) {
            if let cam = activeCamera {
                VStack(alignment: .leading, spacing: 3) {
                    Text(cam.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }

                Divider()
                    .frame(height: 22)
                    .overlay(Color.white.opacity(0.2))

                // Mute / Unmute Audio Toggle
                Button {
                    player.toggleMute()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(player.isMuted ? 0.08 : 0.20))
                            .frame(width: 28, height: 28)
                        Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(player.isMuted ? .white.opacity(0.7) : .green)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("m", modifiers: [])
                .help(player.isMuted ? "Unmute audio (M)" : "Mute audio (M)")
                .accessibilityLabel(player.isMuted ? "Unmute audio" : "Mute audio")

                // Camera Settings
                Button {
                    vm.openEditSheet(for: cam)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 28, height: 28)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Camera settings")
                .accessibilityLabel("Camera settings")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.25))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }

    private var statusColor: Color {
        if player.isConnecting { return .orange }
        if player.currentFrame != nil { return .green }
        return .red
    }

    private var statusText: String {
        if player.isConnecting { return "CONNECTING" }
        if player.currentFrame != nil { return player.fpsText }
        return "OFFLINE"
    }

    /// Last known frame for a camera: live frame for the active camera,
    /// otherwise the stored snapshot.
    private func thumbnailImage(for cam: CameraConfig) -> NSImage? {
        if cam.id == activeCamera?.id, let frame = player.currentFrame {
            return frame
        }
        return player.snapshots.image(for: cam.id)
    }

    private func carouselScrollHeight(for availableHeight: CGFloat) -> CGFloat {
        let count = max(1, appState.cameras.count)
        let itemHeight: CGFloat = 64
        let spacing: CGFloat = 8
        // Reserve at least 156pt for top/bottom window margins (50pt each) + New button (36pt) + padding (20pt)
        let maxScrollHeight = max(itemHeight, availableHeight - 156)
        // Snap to an exact integer number of visible camera items so thumbnails are never awkwardly cut in half
        let maxVisibleItems = max(1, Int((maxScrollHeight + spacing) / (itemHeight + spacing)))
        let visibleItems = min(count, maxVisibleItems)
        return CGFloat(visibleItems) * itemHeight + CGFloat(max(0, visibleItems - 1)) * spacing + 4
    }

    // Floating Camera Switcher Thumbnails (Always available)
    private func cameraThumbnailCarousel(availableHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            if !appState.cameras.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 8) {
                            ForEach(appState.cameras) { cam in
                                cameraThumbnailButton(for: cam)
                                    .id(cam.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: carouselScrollHeight(for: availableHeight))
                    .onChange(of: activeCamera?.id) { _, newID in
                        if let newID {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }

            // Quick Add Camera thumbnail slot
            Button {
                vm.openAddSheet()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 96, height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Add another camera")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
    }

    private func cameraThumbnailButton(for cam: CameraConfig) -> some View {
        let isSelected = (cam.id == (activeCamera?.id ?? UUID()))
        return Button {
            hub.select(cam)
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 96, height: 64)

                if let thumb = thumbnailImage(for: cam) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 64)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 96, height: 64)
                }

                // Camera Label Overlay
                Text(cam.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
            .frame(width: 96, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.25), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                hub.select(cam)
            } label: {
                Label("Switch to Camera", systemImage: "play.fill")
            }

            Divider()

            Button {
                vm.openEditSheet(for: cam)
            } label: {
                Label("Edit Camera", systemImage: "pencil")
            }

            if appState.cameras.count > 1 {
                Button(role: .destructive) {
                    if let idx = appState.cameras.firstIndex(where: { $0.id == cam.id }) {
                        appState.removeCameras(at: IndexSet(integer: idx))
                    }
                } label: {
                    Label("Delete Camera", systemImage: "trash")
                }
            }
        }
    }

    // Clean, perfectly proportioned Camera Settings Modal
    private var cameraFormSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(vm.editingCamera != nil ? "Edit Camera Settings" : "Add New Camera")
                    .font(.system(size: 16, weight: .bold))
                Spacer()

                if let existing = vm.editingCamera, appState.cameras.count > 1 {
                    Button(role: .destructive) {
                        if let idx = appState.cameras.firstIndex(where: { $0.id == existing.id }) {
                            appState.removeCameras(at: IndexSet(integer: idx))
                        }
                        vm.showingAddEditSheet = false
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Input Fields
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Camera Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g. Gate, Living Room", text: $vm.formName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("RTSP Stream URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("rtsp://user:password@ip:port/...", text: $vm.formURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Text("Credentials and full URL are kept secure locally and will not appear on the video screen.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Footer Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    vm.showingAddEditSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Settings") {
                    let name = vm.formName.trimmingCharacters(in: .whitespaces)
                    let url = vm.formURL.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !url.isEmpty else { return }

                    if let existing = vm.editingCamera {
                        appState.updateCamera(id: existing.id, name: name, rtspURL: url)
                        if activeCamera?.id == existing.id {
                            hub.select(cameraID: existing.id, rtspURL: url)
                        }
                    } else {
                        appState.addCamera(name: name, rtspURL: url)
                        if let newCam = appState.cameras.last {
                            hub.select(newCam)
                        }
                    }
                    vm.showingAddEditSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(vm.formName.isEmpty || vm.formURL.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480, height: 260)
    }
}

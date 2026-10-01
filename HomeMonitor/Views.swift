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
        ZStack {
            // Background is pure pitch black for camera canvas
            Color.black.ignoresSafeArea()

            // 1. Video layer: live frame; while a stream (re)connects show a
            // dimmed snapshot of that camera so switching never cuts to black.
            if let frame = player.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else if let snapshot = player.snapshots.image(for: activeCamera?.id) {
                // Camera still with live status: spinner while connecting,
                // error card once the attempt has failed.
                ZStack {
                    Image(nsImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                        .overlay(Color.black.opacity(0.45).ignoresSafeArea())

                    if player.isStreaming || player.isConnecting {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Connecting to stream…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    } else if player.errorMessage != nil {
                        streamErrorCard
                    }
                }
            } else if player.isStreaming || player.isConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting to stream...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if player.errorMessage != nil {
                streamErrorCard
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.4))
                    Text("No Camera Selected")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    Button("Add Camera") {
                        vm.openAddSheet()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Fixed controls stay in the titlebar area; camera metadata is separated below.
            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    settingsButton
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                }

                Spacer(minLength: 0)

                HStack {
                    cameraInfoCard
                        .padding(.leading, 14)
                        .padding(.bottom, 14)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(vm.isPlayerUIVisible ? 1 : 0)
            .allowsHitTesting(vm.isPlayerUIVisible)
            .ignoresSafeArea(.container, edges: .top)

            // 3. Right Floating Carousel (Always available camera switcher)
            HStack {
                Spacer()
                cameraThumbnailCarousel
                    .padding(.trailing, 24)
                    .padding(.vertical, 24)
            }
            .opacity(vm.isPlayerUIVisible ? 1 : 0)
            .allowsHitTesting(vm.isPlayerUIVisible)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                vm.isPlayerUIVisible = hovering
            }
        }
        .sheet(isPresented: $vm.showingAddEditSheet) {
            cameraFormSheet
        }
        .onAppear {
            hub.startStreamIfNeeded(in: appState.cameras)
        }
        .onChange(of: hub.selectedCameraID) { _, newID in
            if let id = newID, let cam = appState.cameras.first(where: { $0.id == id }) {
                hub.select(cam)
            }
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

    private var streamErrorCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Stream Disconnected")
                .font(.headline)
                .foregroundColor(.white)
            if let error = player.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Button("Reconnect") {
                if let cam = activeCamera {
                    player.setURLAndPlay(cam.rtspURL)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsButton: some View {
        Group {
            if let cam = activeCamera {
                Button {
                    vm.openEditSheet(for: cam)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.white)
                .help("Edit this camera")
                .accessibilityLabel("Camera settings")
            }
        }
    }

    private var cameraInfoCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let cam = activeCamera {
                Text(cam.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
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

    // Floating Camera Switcher Thumbnails (Always available)
    private var cameraThumbnailCarousel: some View {
        VStack(spacing: 10) {
            ForEach(appState.cameras) { cam in
                let isSelected = (cam.id == (activeCamera?.id ?? UUID()))
                Button {
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
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // Quick Add Camera thumbnail slot
            Button {
                vm.openAddSheet()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                    Text("New")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 96, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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

import AppKit
import Combine
import SwiftUI

@MainActor
final class UnifiedCameraViewModel: ObservableObject {
    @Published var selectedCameraID: UUID?
    @Published var showingAddEditSheet: Bool = false
    @Published var editingCamera: CameraConfig? = nil
    @Published var formName: String = ""
    @Published var formURL: String = ""
    @Published var isHoveringControls: Bool = false

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
    @StateObject private var player = RTSPStreamPlayer()

    private var activeCamera: CameraConfig? {
        if let id = vm.selectedCameraID, let cam = appState.cameras.first(where: { $0.id == id }) {
            return cam
        }
        return appState.cameras.first
    }

    var body: some View {
        ZStack {
            // Background is pure pitch black for camera canvas
            Color.black.ignoresSafeArea()

            // 1. Video Layer: fills the entire window seamlessly without black borders
            if let frame = player.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else if player.isStreaming {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Connecting to stream...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = player.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Stream Disconnected")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button("Reconnect") {
                        if let cam = activeCamera {
                            player.setURLAndPlay(cam.rtspURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // 2. Overlay Top Floating Control Bar (Clean Glass HUD)
            VStack {
                topFloatingBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Spacer()
            }

            // 3. Right Floating Carousel (Always visible camera switcher)
            HStack {
                Spacer()
                cameraThumbnailCarousel
                    .padding(.trailing, 16)
            }
        }
        .sheet(isPresented: $vm.showingAddEditSheet) {
            cameraFormSheet
        }
        .onAppear {
            if let cam = activeCamera {
                vm.selectedCameraID = cam.id
                player.setURLAndPlay(cam.rtspURL)
            }
        }
        .onDisappear {
            player.stop()
        }
        .onChange(of: vm.selectedCameraID) { _, newID in
            if let id = newID, let cam = appState.cameras.first(where: { $0.id == id }) {
                player.setURLAndPlay(cam.rtspURL)
            }
        }
        .onChange(of: appState.cameras) { _, newCameras in
            if vm.selectedCameraID == nil || !newCameras.contains(where: { $0.id == vm.selectedCameraID }) {
                if let first = newCameras.first {
                    vm.selectedCameraID = first.id
                    player.setURLAndPlay(first.rtspURL)
                }
            }
        }
    }

    // Top Floating Glass HUD Bar
    private var topFloatingBar: some View {
        HStack(spacing: 12) {
            // Space for native macOS traffic lights (Close, Minimize, Zoom)
            Spacer().frame(width: 64)

            // Current Camera Badge
            if let cam = activeCamera {
                HStack(spacing: 8) {
                    Text(cam.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(player.currentFrame != nil ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(player.currentFrame != nil ? player.fpsText : "OFFLINE")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                if let cam = activeCamera {
                    Button {
                        vm.openEditSheet(for: cam)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Settings")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .help("Edit this camera")
                }

                Button {
                    vm.openAddSheet()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .help("Add new camera")
            }
        }
    }

    // Floating Camera Switcher Thumbnails (Always available)
    private var cameraThumbnailCarousel: some View {
        VStack(spacing: 10) {
            ForEach(appState.cameras) { cam in
                let isSelected = (cam.id == (activeCamera?.id ?? UUID()))
                Button {
                    vm.selectedCameraID = cam.id
                } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 96, height: 64)

                        if isSelected, let frame = player.currentFrame {
                            Image(nsImage: frame)
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
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                            player.setURLAndPlay(url)
                        }
                    } else {
                        appState.addCamera(name: name, rtspURL: url)
                        if let newCam = appState.cameras.last {
                            vm.selectedCameraID = newCam.id
                            player.setURLAndPlay(url)
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

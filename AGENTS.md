# HomeMonitor - Engineering Guidelines & Lessons Learned

Tài liệu này lưu trữ các quy chuẩn kỹ thuật và bài học xương máu (post-mortem) khi phát triển ứng dụng native macOS **HomeMonitor** (SwiftUI + AppKit).

---

## 1. Kiến Trúc Giao Diện & Bố Cục Cửa Sổ (SwiftUI Layout Invariants)

### 1.1. Cấm dùng `.frame(maxWidth: .infinity, maxHeight: .infinity)` đơn độc cho `Image` có `.aspectRatio(contentMode: .fill)`
- **Bẫy kỹ thuật (Root Cause gây lệch toàn bộ UI):**
  - Khi cửa sổ người dùng có tỉ lệ khác với tỉ lệ khung hình camera (ví dụ cửa sổ `900x450` tỉ lệ `2:1`, nhưng luồng RTSP trả về ảnh `1920x1080` tỉ lệ `16:9` hoặc `4:3`), một `Image` có `.aspectRatio(contentMode: .fill)` chỉ gắn `.frame(maxWidth: .infinity, maxHeight: .infinity)` sẽ tự tính chiều cao cần thiết là `900 * 9 / 16 = 506.25pt` (hoặc `675pt` với `4:3`).
  - `Image` báo kích thước `900x506.25` lên `ZStack` cha làm **toàn bộ `ZStack` phình to vượt khỏi kích thước vật lý của `NSWindow` (`450pt`)**.
  - Hậu quả: Mọi thành phần overlay bám đáy (`.bottomLeading`) hoặc căn giữa (`.trailing`) đều bị đẩy tụt xuống dưới mép đáy cửa sổ thật (bị cắt lẹm hoặc biến mất hoàn toàn khi có luồng video).
- **Quy chuẩn bắt buộc:**
  - Luôn bọc root view bằng `GeometryReader { windowGeo in ... }`.
  - Truyền `windowGeo.size` xuống `CameraVideoSurface` và **khoá cứng kích thước bằng `.frame(width: size.width, height: size.height).clipped()`** trước khi trả về `ZStack`.

### 1.2. Xử lý Hover & Trạng Thái Điều Khiển Khi Video Stream Ở Tần Số Cao (15–30 FPS)
- **Bẫy kỹ thuật:**
  - Khi `player.currentFrame` cập nhật liên tục mỗi 33ms, nếu view hiển thị video nằm chung cấp với các view nhận gesture, SwiftUI sẽ liên tục re-evaluate cây view và làm rớt/huỷ trạng thái `.onHover`, khiến cờ `isPlayerUIVisible` bị reset về `false`.
  - Nếu đặt `.opacity(vm.isPlayerUIVisible ? 1.0 : 0.0)`, toàn bộ nút điều khiển sẽ biến mất vĩnh viễn ngay khi camera bắt đầu phát hình.
- **Quy chuẩn bắt buộc:**
  - Tách phần render hình ảnh camera ra struct con độc lập (`CameraVideoSurface`) với `.allowsHitTesting(currentFrame == nil)` để các frame video không bao giờ can thiệp vào hit-testing của chuột.
  - Giữ các cụm điều khiển (`cameraInfoCard` ở góc dưới trái `bottomLeading` và `cameraThumbnailCarousel` ở chính giữa cạnh phải `trailing`) luôn hiển thị rõ ở trạng thái nghỉ (`opacity: 0.85`) và sáng 100% khi hover (`opacity: 1.0`).
  - Ép `.environment(\.colorScheme, .dark)` cho overlay để lớp kính mờ `.ultraThinMaterial` luôn giữ nền tối tương phản cao, chữ trắng không bị chìm vào nền.

### 1.3. Căn Giữa Tuyệt Đối Cho Carousel (`cameraThumbnailCarousel`)
- Đặt Carousel trong frame có `width: windowGeo.size.width, height: windowGeo.size.height, alignment: .trailing`.
- Chiều cao vùng cuộn (`carouselScrollHeight`) phải được tính theo **bội số nguyên (`visibleItems`) của chiều cao mỗi thumbnail (`64pt`) + khoảng cách (`8pt`)**, không bao giờ cắt cụt nửa chừng một thumbnail và luôn chừa tối thiểu `156pt` tổng lề trên/dưới + nút `+ New` để khoảng cách lề trên và lề dưới đối xứng tuyệt đối.

---

## 2. Phương Pháp Kiểm Thử Trực Quan Tự Động (Visual Smoke Test)

- **Tuyệt đối không push code hoặc báo cáo hoàn thành chỉ dựa trên suy đoán mã nguồn.**
- Khi môi trường chạy agent không được cấp quyền macOS Screen Recording (`capturePermission: "denied"`), phải kiểm chứng giao diện bằng cách tạo một **Offscreen `NSHostingView` Bitmap Renderer** (`/tmp/test_main_renderer.swift`):
  1. Khởi tạo `NSWindow` và `NSHostingView(rootView: CameraStreamMainView(...))` với đúng kích thước cửa sổ thực tế (ví dụ `900x450`) và nạp một `NSImage` giả lập luồng camera (`1920x1080`).
  2. Gọi `host.bitmapImageRepForCachingDisplay(in: host.bounds)` và `host.cacheDisplay(in: host.bounds, to: rep)` để xuất ra file PNG.
  3. Dùng công cụ `read` đọc trực tiếp file PNG vừa kết xuất để kiểm tra bằng mắt:
     - `host.fittingSize` không được vượt quá kích thước cửa sổ.
     - Cụm `cameraInfoCard` (góc dưới trái) và `cameraThumbnailCarousel` (cạnh phải) không bao giờ đè nhau và có lề trên/dưới cân xứng.
  4. Xoá sạch các file test tạm trong `/tmp` sau khi xác minh xong.

---

## 3. Phân Phối & CI/CD (GitHub Actions & Gatekeeper)

- **GitHub Release tự động (`.github/workflows/release.yml`):**
  - Mọi lượt push lên `main` hoặc tag `v*` đều tự động biên dịch Universal Binary (`arm64` + `x86_64`), đóng gói `HomeMonitor.dmg` / `HomeMonitor.zip` và cập nhật trực tiếp vào GitHub Release mới nhất (`make_latest: true`).
- **Hỗ trợ người dùng không có chứng chỉ Apple Developer ($99/năm):**
  - Do app ký ad-hoc (`codesign -s -`), người dùng tải từ trình duyệt về sẽ bị macOS Gatekeeper gắn cờ `com.apple.quarantine` (báo lỗi *"App is damaged and can't be opened. You should move it to the Trash"*).
  - Trên macOS Sonoma/Sequoia, lệnh chuẩn để gỡ cờ kiểm dịch là:
    ```bash
    xattr -c /Applications/HomeMonitor.app
    ```
    *(Lưu ý: binary `xattr` mặc định trên macOS hiện đại không nhận cờ `-r` khi đi kèm `-c`).*

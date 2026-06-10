# 🔐 PassNote - Biometric Vault (Local-First)

**PassNote** là ứng dụng quản lý mật khẩu bảo mật cao, kết hợp giữa kiến trúc **Local-First (ưu tiên dữ liệu cục bộ)** và xác thực sinh trắc học **Face AI (ArcFace)**. Ứng dụng đảm bảo dữ liệu luôn sẵn dụng ngay cả khi offline và tự động đồng bộ hóa an toàn với Supabase Cloud.

---

## 🚀 Tính năng nổi bật

- 🗄️ **Local-First Architecture**: Sử dụng **Isar Database** siêu tốc để lưu trữ mật khẩu trên thiết bị. Load dữ liệu tức thì, không phụ thuộc mạng.
- 🔄 **Background Sync**: Tự động đồng bộ hóa dữ liệu với **Supabase** khi có kết nối internet.
- 🎭 **Face ID Authentication**: Xác thực bằng khuôn mặt sử dụng model **ArcFace** (Inference qua Server riêng để đảm bảo hiệu năng).
- 🛡️ **AES-256 Encryption**: Mật khẩu được mã hóa cục bộ trước khi lưu vào database.
- 🌙 **Luxury UI**: Giao diện hiện đại, sang trọng với các hiệu ứng micro-animation.

---

## 🛠️ Yêu cầu hệ thống

- **Flutter SDK**: ^3.0.0
- **Dart**: ^3.0.0
- **Android**: API 21+ (Android 5.0 trở lên)
- **Face AI Server**: Đang chạy model `arcface.onnx` (FastAPI/Python)

---

## 📦 Hướng dẫn cài đặt

### 1. Clone Project
```bash
git clone https://github.com/MaiTruong1312/PassNote.git
cd PassNote
```

### 2. Cài đặt Dependencies
```bash
flutter pub get
```

### 3. Sinh mã nguồn tự động (Quan trọng)
Dự án sử dụng `build_runner` để sinh code cho Isar và các Model. Bạn **bắt buộc** phải chạy lệnh này nếu có thay đổi về Model:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## ⚙️ Cấu hình quan trọng

### 1. Supabase Configuration
Mở file `lib/main.dart` và cập nhật thông tin dự án Supabase của bạn:
```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 2. Face AI Server
Mở file `lib/services/face_api_service.dart` và cập nhật địa chỉ IP Server đang chạy model ArcFace:
```dart
static String get baseUrl {
  return 'http://YOUR_SERVER_IP:8000'; 
}
```

---

## 📱 Chạy ứng dụng

Để đảm bảo hiệu năng tốt nhất trên các dòng máy Android đời cao (Android 11-16), hãy làm theo các bước sau:

1.  **Gỡ cài đặt** bản app cũ trên điện thoại (nếu có).
2.  **Dọn dẹp build**:
    ```bash
    flutter clean
    flutter pub get
    ```
3.  **Chạy ứng dụng**:
    ```bash
    flutter run
    ```

---

## ⚠️ Lưu ý kỹ thuật

### Lỗi ANR (App Not Responding)
Nếu app bị treo ở logo, hãy kiểm tra:
- Đảm bảo file `arcface.onnx` và `isar` được cấu hình `noCompress` trong `android/app/build.gradle.kts`.
- Kiểm tra kết nối mạng giữa điện thoại và máy tính (ADB).

### Gradle & AGP
Dự án đã được cấu hình tối ưu với **AGP 8.11.1** và **Gradle 8.14**. Một đoạn script đặc biệt trong `android/build.gradle.kts` đã được thêm vào để xử lý lỗi `namespace` của thư viện Isar trên các phiên bản Android mới.

---

## 📝 Giấy phép
Dự án được phát triển bởi **Antigravity AI Assistant** & **MaiTruong1312**.

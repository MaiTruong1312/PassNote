# PassNote (Luxury Secure Vault) 🔐

**PassNote** là một ứng dụng quản lý mật khẩu an toàn và cao cấp, được phát triển trên nền tảng **Flutter** kết hợp cơ sở dữ liệu **Supabase**. Ứng dụng tập trung vào bảo mật tối đa cho thông tin người dùng với sự kết hợp của chuẩn mã hóa AES tiên tiến và công nghệ xác thực sinh trắc học AI (DeepFace).

---

## Tính năng nổi bật ✨

- **Lưu trữ bảo mật đám mây:** Thêm, xem, ẩn/hiện, sao chép và xóa mật khẩu. Dữ liệu được quản trị qua Supabase.
- **Mã hóa điểm-cuối (End-to-end Encryption):** Mọi mật khẩu được mã hóa bằng thuật toán `AES` với `IV` động ngay trên điện thoại trước khi đẩy lên Supabase. Không lấy được plaintext nếu chỉ truy cập cơ sở dữ liệu.
- **Đăng nhập nhanh với Mã PIN (Passkey):** Thiết lập và sử dụng mã PIN 6 số để đăng nhập an toàn, tiện lợi thay vì nhập mật khẩu tài khoản (dùng `flutter_secure_storage`).
- **Nhận diện khuôn mặt AI (Face Authentication):** Tích hợp công nghệ AI xác thực khuôn mặt từ `DeepFace` thông qua Máy chủ API Python độc lập, phát hiện và so sánh bằng thuật toán Cosine Distance.

## Kiến trúc Hệ thống 🏗️

1. **Frontend (Mobile App):** `Flutter` & `Provider`. Giao diện tối giản, sang trọng (Luxury Theme).
2. **Backend Database:** `Supabase` PostgreSQL (lưu trữ mật khẩu mã hóa, lịch sử hệ thống `audit_log`, quản lý người dùng `users`,...).
3. **Face API Server:** Server độc lập chạy bằng `Python (FastAPI)` tích hợp `DeepFace`, `OpenCV` để trích xuất cấu trúc đường nét khuôn mặt (embeddings vector).

---

## Hướng dẫn cài đặt & Khởi chạy 🚀

### 1. Khởi chạy Máy chủ API Nhận diện Khuôn mặt (Face API Server)
Để tính năng Face Login hoạt động, bạn cần khởi chạy Backend API.

```bash
cd face_api_server
# Cài đặt các thư viện cần thiết
pip install fastapi uvicorn deepface opencv-python numpy python-multipart
# Chạy server ở cổng 8000
python main.py
```
*(Lưu ý: Nếu bạn chạy ứng dụng Flutter trên thiết bị thật, hãy nhớ lấy địa chỉ IPv4 của máy tính và sửa `baseUrl` trong file `lib/services/face_api_service.dart`)*.

### 2. Thiết lập Ứng dụng Flutter (Frontend)
Đảm bảo bạn đã cài đặt [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
# Clone dự án & di chuyển vào thư mục dự án
cd PassNote

# Cài đặt các thư viện Dart/Flutter
flutter pub get

# Chạy ứng dụng trên Emulator hoặc Thiết bị thật
flutter run
```

---

## Hướng dẫn sử dụng cơ bản 📖

1. **Đăng ký & Đăng nhập**: Tại màn hình chính, mở khóa Vault bằng cách Đăng nhập tài khoản Supabase. 
2. **Bảo mật sinh trắc học & Passkey**: Truy cập vào `System Settings` -> `Setup Passkey` (Mã PIN 6 số) hoặc `Setup Face Recognition`. Điện thoại sẽ dùng Camera hoặc lưu mã hóa an toàn trên thiết bị của bạn.
3. **Đăng nhập lần tiếp theo**: Ứng dụng sẽ ưu tiên hiển thị màn hình mở khóa nhanh (Face Scan / PIN code).
4. **Quản lý Passwords**:
   - Chạm vào nút (+) để thêm thông tin ứng dụng mới.
   - Chạm vào ứng dụng trong Vault để mở khóa/hiển thị chi tiết (Có nút Copy Clipboard và con mắt (`•`) để ẩn hiện text).
   - Biểu tượng 🗑️ (Thùng rác) ở góc trên để Xóa vĩnh viễn mật khẩu.

---

*Phát triển bởi đội ngũ tâm huyết, PassNote cam kết mang lại không gian lưu trữ thông tin số hóa an toàn và thẩm mỹ nhất.*

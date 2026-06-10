# Tài liệu Kiến trúc Cơ sở dữ liệu Hệ thống PassNote (Bank-Grade)

Tài liệu này tổng hợp và phân tích chi tiết cấu trúc cơ sở dữ liệu của dự án PassNote, được thiết kế theo tiêu chuẩn bảo mật ngân hàng, tập trung vào nhận diện khuôn mặt và mã hóa dữ liệu.

---

## 1. Tổng quan Hệ thống (System Overview)
Hệ thống được xây dựng trên nền tảng PostgreSQL, sử dụng các kiểu dữ liệu hiện đại như `UUID` cho định danh, `JSONB` cho dữ liệu linh hoạt (AI embeddings, settings), và `INET` cho bảo mật mạng.

---

## 2. Chi tiết các Thực thể (Table Definitions)

### 2.1 Quản lý Người dùng & Sinh trắc học
*   **`users`**: Bảng lõi lưu trữ thông tin định danh. Đặc biệt có `face_encoding` (JSONB) chứa vector đặc trưng khuôn mặt và các thông tin thiết bị đăng ký.
*   **`face_templates`**: Lưu trữ các mẫu khuôn mặt bổ sung (Backup, Alternative). Hỗ trợ quản lý phiên bản model AI (`model_name`, `template_version`) và thống kê độ chính xác (`avg_match_score`).

### 2.2 Quản lý Mật khẩu & Két sắt (Vault)
*   **`passwords`**: Lưu trữ thông tin tài khoản được bảo vệ. Mật khẩu được lưu dưới dạng `encrypted_password` đi kèm với `iv` (Initialization Vector). Hỗ trợ gắn tag, yêu thích và phân loại.
*   **`password_categories`**: Cho phép người dùng tổ chức mật khẩu theo thư mục (Social, Work, Bank, etc.) với icon và màu sắc tùy chỉnh.
*   **`password_sharing`**: Hệ thống phân quyền chia sẻ mật khẩu giữa các người dùng với các cấp độ: `view`, `edit`, `admin`.

### 2.3 Bảo mật & Mã hóa (Encryption Layer)
*   **`encryption_keys`**: Quản lý vòng đời của các khóa mã hóa (Master Key, Data Key). Hỗ trợ xoay vòng khóa (`rotation_reason`) và thuật toán `AES-256-GCM`.
*   **`backup_codes`**: Lưu trữ mã dự phòng (hash & salt) cho trường hợp khẩn cấp khi không thể nhận diện khuôn mặt.

### 2.4 Giám sát & Nhật ký (Logging & Monitoring)
*   **`login_history`**: Nhật ký chi tiết mọi lần đăng nhập. Lưu trữ điểm tin cậy AI (`face_confidence`), thời gian nhận diện (`recognition_time_ms`), và đánh giá rủi ro (`risk_score`).
*   **`sessions`**: Quản lý phiên làm việc theo Token, hỗ trợ thu hồi quyền truy cập (`is_revoked`) và gắn định danh thiết bị.
*   **`audit_log`**: Lưu trữ mọi hành động nhạy cảm trên tài nguyên hệ thống để phục vụ điều tra bảo mật.

### 2.5 Cấu hình (Configuration)
*   **`user_settings`**: Một kho lưu trữ JSONB khổng lồ chứa mọi tùy chỉnh từ giao diện (Theme, Language) đến bảo mật cao cấp (Ngưỡng nhận diện mặt - `threshold`, Yêu cầu nhận diện sự sống - `require_liveness`).

---

## 3. Các đặc tính "Bank-Grade" nổi bật
1.  **AI Versioning**: Cho phép nâng cấp model nhận diện khuôn mặt mà không làm hỏng dữ liệu cũ nhờ lưu trữ `model_name` trong template.
2.  **Granular Security**: Mỗi mật khẩu có IV riêng và tham chiếu đến một ID khóa mã hóa cụ thể, giúp giảm thiểu thiệt hại nếu một phần dữ liệu bị lộ.
3.  **Liveness Detection**: Cấu hình sẵn sàng cho các thuật toán chống giả mạo (Anti-spoofing) thông qua cài đặt người dùng.
4.  **Device Binding**: Ràng buộc tài khoản với `registered_device_id` để ngăn chặn đăng nhập lạ.

---
*Tài liệu được tạo tự động bởi Antigravity AI Assistant.*

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/face_api_service.dart';

class RealtimeCameraScanner extends StatefulWidget {
  final Function(List<double> vector) onFaceDetected;
  final String promptText;

  const RealtimeCameraScanner({Key? key, required this.onFaceDetected, this.promptText = "Đang nhận diện..."}) : super(key: key);

  @override
  State<RealtimeCameraScanner> createState() => _RealtimeCameraScannerState();
}

class _RealtimeCameraScannerState extends State<RealtimeCameraScanner> {
  CameraController? _controller;
  Timer? _timer;
  bool _isProcessing = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first);

      _controller = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      
      if (_isDisposed) return;
      setState(() {});
      
      // Bắt đầu chu trình quét liên tục mỗi 1.5 giây
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _scanFrame());
    } catch (e) {
      debugPrint("Camera INIT Error: \$e");
    }
  }

  Future<void> _scanFrame() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    _isProcessing = true;
    try {
      final xFile = await _controller!.takePicture();
      final File imageFile = File(xFile.path);

      // Gọi API siêu tốc
      final vector = await FaceApiService.extractFace(imageFile);
      
      if (vector != null && !_isDisposed) {
        _timer?.cancel(); // Dừng quét khi tìm thấy mặt
        widget.onFaceDetected(vector);
      }
      
      // Xóa file tạm
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      debugPrint("Lỗi quét camera: \$e");
    } finally {
      if (!_isDisposed) _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.desktop_windows, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Camera Live-feed chưa hỗ trợ hoàn thiện trên PC/Laptop.\nVui lòng chạy trên Android, hoặc tải ảnh lên!", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () async {
                setState(() => _isProcessing = true);
                try {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(source: ImageSource.gallery);
                  
                  if (xFile != null) {
                    final vector = await FaceApiService.extractFace(File(xFile.path));
                    
                    if (vector != null && mounted) {
                       widget.onFaceDetected(vector);
                    } else if (vector == null && mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("THẤT BẠI: AI không tìm thấy khuôn mặt rõ ràng, hoặc API mất phản hồi! Vui lòng chọn ảnh khác rõ mặt hơn.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red)
                       );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tệp: \$e")));
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              icon: _isProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload, color: Colors.white),
              label: Text(_isProcessing ? "ĐANG GỬI AI PHÂN TÍCH..." : "TẢI ẢNH CHÂN DUNG"),
            )
          ],
        )
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox(
        height: 300, 
        child: Center(child: CircularProgressIndicator())
      );
    }

    // PHẦN BUILD CHO MOBILE (SAU KHI ĐÃ INIT CAMERA)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // THAY THẾ CẢ CỤM OVAN BẰNG KHUNG VUÔNG TỐI GIẢN
        Container(
          height: 250, // Khớp với kích thước 250x250 bên LoginPage
          width: 250,
          decoration: BoxDecoration(
            // Xóa BorderRadius.elliptical, giữ góc vuông
            border: Border.all(color: Colors.black, width: 1), 
          ),
          child: ClipRect( // Thay ClipOval bằng ClipRect để giữ khung vuông
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // Lưu ý: Preview camera thường bị ngược width/height ở mode portrait
                width: _controller!.value.previewSize?.height ?? 480,
                height: _controller!.value.previewSize?.width ?? 640,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Chuyển màu text sang đen/xám cho tone-sur-tone
        Text(
          widget.promptText.toUpperCase(), 
          style: const TextStyle(
            fontWeight: FontWeight.w300, 
            fontSize: 12, 
            letterSpacing: 2, 
            color: Colors.black
          )
        ),
      ],
    );
  }
}

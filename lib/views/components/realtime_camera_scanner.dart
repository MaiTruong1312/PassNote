import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../services/face_inference_service.dart';
import '../../services/secure_storage_service.dart';

enum ScannerMode { registration, login }

class RealtimeCameraScanner extends StatefulWidget {
  final Function(List<double> faceVector, String angleType) onFaceDetected;
  final ScannerMode mode;
  final String? targetAngle; // 'straight', 'tilt_left', 'tilt_right', 'tilt_up', 'tilt_down'

  const RealtimeCameraScanner({
    super.key, 
    required this.onFaceDetected,
    this.mode = ScannerMode.login,
    this.targetAngle,
  });

  @override
  State<RealtimeCameraScanner> createState() => _RealtimeCameraScannerState();
}

class _RealtimeCameraScannerState extends State<RealtimeCameraScanner> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isDisposed = false;
  int _userRotationOffset = 0;
  final int _scanIntervalMs = 200; // Tăng tốc độ quét giữa các lần
  final int _scanCount = 5; // Chạy đúng 5 lần như yêu cầu
  
  File? _capturedFile;
  bool _isConfirming = false;
  String _statusText = "VUI LÒNG NHÌN THẲNG VÀO CAMERA";
  List<double>? _lastExtractedEmb;
  Rect? _lastFaceRect;
  Size? _lastDetectedSize;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: false,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _loadUserRotation();
    if (Platform.isAndroid || Platform.isIOS) {
      _initCamera();
    }
  }

  Future<void> _loadUserRotation() async {
    // Luôn bắt đầu với 0, người dùng không cần chỉnh tay nữa
    _userRotationOffset = 0;
  }

  Future<void> _initCamera() async {
    if (_isDisposed) return;
    
    try {
      // 1. Lưu lại controller cũ và xóa khỏi State để ẩn Preview ngay lập tức
      final oldController = _controller;
      if (mounted) {
        setState(() {
          _statusText = "ĐANG KHỞI ĐỘNG CAMERA...";
          _controller = null; 
        });
      }

      // 2. Dọn dẹp controller cũ triệt để (nếu có)
      if (oldController != null) {
        try { await oldController.stopImageStream(); } catch (_) {} 
        await oldController.dispose();
      }

      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first);

      // 3. Khởi tạo vào biến tạm để an toàn tuyệt đối cho UI
      final newController = CameraController(
        frontCam, 
        ResolutionPreset.medium, 
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );
      
      await newController.initialize();
      
      if (_isDisposed || !mounted) {
        await newController.dispose();
        return;
      }
      
      // 4. Chỉ gán vào biến chính khi đã sẵn sàng 100%
      setState(() {
        _controller = newController;
        _statusText = "VUI LÒNG NHÌN THẲNG VÀO CAMERA";
      });
      
      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Camera INIT Error: $e");
      if (mounted) setState(() => _statusText = "LỖI CAMERA. VUI LÒNG THỬ LẠI.");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // KHÓA CỨNG: Chỉ sử dụng hướng cảm biến gốc, bỏ qua cảm biến nghiêng máy
      int rotationCompensation = camera.sensorOrientation;
      
      // Đối với camera trước, 270 là hướng dọc chuẩn trên đa số máy Android
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    Uint8List bytes;
    InputImageFormat finalFormat = format;

    if (Platform.isAndroid) {
      // TUYỆT CHIÊU: Chuyển đổi thủ công sang NV21 cho Android
      // NV21 = Y plane + Interleaved V/U planes
      final int width = image.width;
      final int height = image.height;
      final int ySize = width * height;
      final int uvSize = width * height ~/ 2;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // 1. Copy Y plane (loại bỏ padding)
      final Plane yPlane = image.planes[0];
      final Uint8List yBuffer = yPlane.bytes;
      final int yRowStride = yPlane.bytesPerRow;
      for (int row = 0; row < height; row++) {
        nv21.setRange(row * width, (row + 1) * width, 
            yBuffer.sublist(row * yRowStride, row * yRowStride + width));
      }

      // 2. Interleave V and U (NV21 format: V1, U1, V2, U2...)
      // Lưu ý: Android YUV_420_888 thường có Plane 1 là U, Plane 2 là V
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final Uint8List uBuffer = uPlane.bytes;
      final Uint8List vBuffer = vPlane.bytes;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      int pos = ySize;
      for (int row = 0; row < height ~/ 2; row++) {
        for (int col = 0; col < width ~/ 2; col++) {
          final int vIdx = row * uvRowStride + col * uvPixelStride;
          final int uIdx = row * uvRowStride + col * uvPixelStride;
          // NV21 expects V first, then U
          nv21[pos++] = vBuffer[vIdx];
          nv21[pos++] = uBuffer[uIdx];
        }
      }
      bytes = nv21;
      finalFormat = InputImageFormat.nv21;
    } else {
      // iOS: BGRA8888 hoặc định dạng khác xử lý đơn giản hơn
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    final inputImageMetadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: finalFormat,
      bytesPerRow: image.width,
    );
    
    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isConfirming || _isDisposed) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);
        
        if (faces.isNotEmpty) {
          final face = faces.first;
          
          // Lấy góc độ
          double y = face.headEulerAngleY ?? 0;
          double x = face.headEulerAngleX ?? 0;
          
          String currentAngle = 'unknown';
          if (y.abs() < 12 && x.abs() < 12) currentAngle = 'straight';
          else if (y > 20) currentAngle = 'tilt_left';
          else if (y < -20) currentAngle = 'tilt_right';
          else if (x > 15) currentAngle = 'tilt_up';
          else if (x < -15) currentAngle = 'tilt_down';

          bool isTargetDetected = false;
          if (widget.targetAngle != null) {
            isTargetDetected = currentAngle == widget.targetAngle;
          } else {
            // Trong chế độ login, mặc định chấp nhận mọi góc (vì chúng ta so khớp với toàn bộ bộ mỏ neo)
            isTargetDetected = currentAngle != 'unknown';
          }
          
          if (isTargetDetected) {
            // KIỂM TRA ĐỘ THẲNG CỦA MẶT (Strict Alignment Check)
            bool isFaceStraight = y.abs() < 10 && x.abs() < 10;
            
            setState(() {
              _lastFaceRect = face.boundingBox;
              _lastDetectedSize = Size(image.width.toDouble(), image.height.toDouble());
              if (!isFaceStraight) {
                _statusText = "VUI LÒNG NHÌN THẲNG VÀO CAMERA";
              } else {
                _statusText = "ĐANG QUÉT BẢO MẬT...";
              }
            });
            
            // Chỉ cho phép quét nếu mặt đang nhìn thẳng (Giống App Ngân Hàng)
            if (!isFaceStraight && widget.mode == ScannerMode.login) {
               _isProcessing = false;
               return; 
            }
            
            if (widget.mode == ScannerMode.registration) {
              await _controller!.stopImageStream();
              final xFile = await _controller!.takePicture();
              setState(() {
                _capturedFile = File(xFile.path);
                _isConfirming = true;
                _statusText = "GÓC ${currentAngle.toUpperCase()} - XÁC NHẬN?";
              });
            } else {
              await _controller!.stopImageStream();
              await Future.delayed(const Duration(milliseconds: 500));
              _captureAndExtract(currentAngle);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("ML Kit error: $e");
    } finally {
      if (!_isDisposed && !_isConfirming) _isProcessing = false;
    }
  }

  Future<void> _captureAndExtract(String detectedAngle) async {
    try {
      List<List<double>> vectors = [];
      
      for (int i = 0; i < _scanCount; i++) {
        if (_isDisposed || _controller == null || !_controller!.value.isInitialized) return;
        
        while (_controller!.value.isTakingPicture && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        setState(() {
          _statusText = "ĐANG XÁC THỰC (${i + 1}/$_scanCount)...";
        });

        final xFile = await _controller!.takePicture();
        final File imageFile = File(xFile.path);
        
        final vector = await FaceInferenceService().extractEmbedding(
          imageFile, 
          faceRect: _lastFaceRect,
          previewSize: _lastDetectedSize,
          rotationAngle: 0,
          flipHorizontal: _controller?.description.lensDirection == CameraLensDirection.front,
        );
        
        if (vector != null) {
          setState(() => _lastExtractedEmb = vector);
          
          // Gửi vector và góc về để kiểm tra
          widget.onFaceDetected(vector, detectedAngle);
          
          // Đợi một chút để xem có login thành công không (parent sẽ unmount widget này)
          await Future.delayed(const Duration(milliseconds: 300));
          if (_isDisposed) return; // Nếu đã login thành công và unmount thì thoát
        }

        if (await imageFile.exists()) {
          await imageFile.delete();
        }

        if (i < _scanCount - 1) {
          await Future.delayed(Duration(milliseconds: _scanIntervalMs));
        }
      }

      if (vectors.isNotEmpty && !_isDisposed) {
        widget.onFaceDetected(vectors.first, detectedAngle);
      } else if (vectors.isEmpty && mounted) {
        setState(() {
          _statusText = "NHẬN DIỆN THẤT BẠI. THỬ LẠI...";
          _isConfirming = false;
          _isProcessing = false;
        });
        _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint("Lỗi quét camera: $e");
    }
  }

  Future<void> _onConfirmed() async {
    if (_capturedFile == null) return;
    
    setState(() {
      _isConfirming = false;
      _statusText = "ĐANG TRÍCH XUẤT ĐẶC TRƯNG...";
    });
    
    final vector = await FaceInferenceService().extractEmbedding(
      _capturedFile!, 
      faceRect: _lastFaceRect,
      previewSize: _lastDetectedSize,
      rotationAngle: 0,
      flipHorizontal: _controller?.description.lensDirection == CameraLensDirection.front,
    );
    if (vector != null) {
      // Trích xuất góc độ từ tên trạng thái (hoặc lưu state góc độ lúc chụp)
      String confirmedAngle = widget.targetAngle ?? 'straight';
      widget.onFaceDetected(vector, confirmedAngle);
    } else {
      _onRetake();
    }
  }

  void _onRetake() {
    if (_controller == null || !_controller!.value.isInitialized) {
      _initCamera();
      return;
    }
    
    setState(() {
      _capturedFile = null;
      _isConfirming = false;
      _isProcessing = false;
      _statusText = "VUI LÒNG NHÌN THẲNG VÀO CAMERA";
    });

    try {
      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Error restarting stream: $e");
      _initCamera(); // Fallback nếu stream bị lỗi
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _faceDetector.close();
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
            const Text("Live-feed camera chỉ hỗ trợ trên Android/iOS.\nVui lòng tải ảnh lên!", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () async {
                setState(() => _isProcessing = true);
                try {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(source: ImageSource.gallery);
                  if (xFile != null) {
                    final vector = await FaceInferenceService().extractEmbedding(File(xFile.path));
                    if (vector != null && mounted) {
                       widget.onFaceDetected(vector, 'straight');
                    }
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              icon: const Icon(Icons.upload, color: Colors.white),
              label: Text(_isProcessing ? "ĐANG PHÂN TÍCH..." : "TẢI ẢNH CHÂN DUNG"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            )
          ],
        )
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
    }

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("BIOMETRIC SCAN", 
                    style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            // Camera Viewport (Vuông vức, Tối giản)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.black, width: 2), // Viền đen sắc nét
                  borderRadius: BorderRadius.zero, // Vuông vức
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Camera Preview
                    Positioned.fill(
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize?.height ?? 480,
                            height: _controller!.value.previewSize?.width ?? 640,
                            child: _isConfirming && _capturedFile != null
                                ? (_controller?.description.lensDirection == CameraLensDirection.front
                                    ? Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.rotationY(pi),
                                        child: Image.file(_capturedFile!),
                                      )
                                    : Image.file(_capturedFile!))
                                : CameraPreview(_controller!),
                          ),
                        ),
                      ),
                    ),
                    // Scanner Animation
                    if (!_isConfirming)
                      _buildScannerOverlay(),
                  ],
                ),
              ),
            ),

            // Controls & Status
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero, // Vuông vức
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 3, color: Colors.black)),
                  const SizedBox(height: 10),
                  const Text("ALIGN FACE WITHIN FRAME",
                    style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  
                  if (_isConfirming) ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            onPressed: _onRetake,
                            child: const Text("RETAKE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              elevation: 0,
                            ),
                            onPressed: _onConfirmed,
                            child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Corner borders (Đen trắng, tối giản)
        Positioned(
          top: 0, left: 0,
          child: Container(width: 30, height: 30, 
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 2), left: BorderSide(color: Colors.white, width: 2)))),
        ),
        Positioned(
          top: 0, right: 0,
          child: Container(width: 30, height: 30, 
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 2), right: BorderSide(color: Colors.white, width: 2)))),
        ),
        Positioned(
          bottom: 0, left: 0,
          child: Container(width: 30, height: 30, 
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 2), left: BorderSide(color: Colors.white, width: 2)))),
        ),
        Positioned(
          bottom: 0, right: 0,
          child: Container(width: 30, height: 30, 
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 2), right: BorderSide(color: Colors.white, width: 2)))),
        ),
        // Scanning line (Trắng tinh khiết)
        _ScanningLine(),
      ],
    );
  }
}

class _ScanningLine extends StatefulWidget {
  @override
  __ScanningLineState createState() => __ScanningLineState();
}

class __ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: _controller.value * constraints.maxHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                        ],
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0), Colors.white, Colors.white.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

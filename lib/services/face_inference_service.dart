import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class FaceInferenceService {
  static final FaceInferenceService _instance = FaceInferenceService._internal();
  factory FaceInferenceService() => _instance;
  FaceInferenceService._internal();

  static const double defaultThreshold = 0.65;
  static const double driftThreshold = 0.50;

  OrtSession? _session;
  bool _isInitialized = false;

  /// Khởi tạo model ONNX từ assets
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // OrtEnv.instance.init(); // Thường không cần gọi explicit trong các version mới
      
      final modelBytes = await rootBundle.load('assets/model/arcface.onnx');
      final sessionOptions = OrtSessionOptions();
      
      _session = OrtSession.fromBuffer(modelBytes.buffer.asUint8List(), sessionOptions);
      _isInitialized = true;
      debugPrint("FaceInferenceService: Model loaded successfully.");
    } catch (e) {
      debugPrint("FaceInferenceService: Failed to load model: $e");
    }
  }

  /// Trích xuất vector embedding từ ảnh, có hỗ trợ cắt ảnh theo khung mặt
  Future<List<double>?> extractEmbedding(File imageFile, {Rect? faceRect, Size? previewSize, int rotationAngle = 0, bool flipHorizontal = false}) async {
    if (!_isInitialized) {
      await init();
    }

    if (_session == null) {
      debugPrint("FaceInferenceService: Session is null, cannot extract embedding.");
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint("FaceInferenceService: Failed to decode image.");
        return null;
      }

      // 1. Tự động xử lý xoay ảnh dựa trên Metadata EXIF (Bake Orientation)
      image = img.bakeOrientation(image);

      // 2. Lật ngang nếu là camera trước (Mirror effect)
      if (flipHorizontal) {
        image = img.flipHorizontal(image);
      }

      // Nếu vẫn cần xoay thêm (ví dụ IP Camera không có EXIF), ta mới dùng rotationAngle
      if (rotationAngle != 0 && image.width > image.height) {
         // Chỉ xoay nếu ảnh vẫn đang nằm ngang sau khi bake
         image = img.copyRotate(image, angle: rotationAngle);
      }

      // 3. Cắt ảnh khuôn mặt nếu có Rect từ ML Kit
      img.Image processedImage;
      if (faceRect != null && previewSize != null) {
        // TÍNH TOÁN TỶ LỆ SCALE THÔNG MINH
        // ML Kit trả về Rect dựa trên hướng "đã xoay" của stream.
        // Ta cần tính tỷ lệ dựa trên kích thước thực tế sau khi đã Bake Orientation.
        
        double streamW = previewSize.width;
        double streamH = previewSize.height;
        
        // Nếu hướng ảnh stream và ảnh thực tế lệch nhau (ngang vs dọc), ta đảo lại kích thước stream
        bool isStreamLandscape = streamW > streamH;
        bool isImageLandscape = image.width > image.height;
        
        if (isStreamLandscape != isImageLandscape) {
          double temp = streamW;
          streamW = streamH;
          streamH = temp;
        }

        double scaleX = image.width / streamW;
        double scaleY = image.height / streamH;

        double leftS = faceRect.left * scaleX;
        double topS = faceRect.top * scaleY;
        double widthS = faceRect.width * scaleX;
        double heightS = faceRect.height * scaleY;

        // NẾU LẬT NGANG, PHẢI ĐẢO TỌA ĐỘ LEFT CỦA FACE RECT
        if (flipHorizontal) {
          leftS = image.width - leftS - widthS;
        }

        // Tăng cường vùng đệm 10% (Vừa đủ để AI thấy được đặc điểm bao quanh)
        double padding = widthS * 0.10;
        int left = (leftS - padding).toInt().clamp(0, image.width - 1);
        int top = (topS - padding).toInt().clamp(0, image.height - 1);
        int width = (widthS + padding * 2).toInt().clamp(1, image.width - left);
        int height = (heightS + padding * 2).toInt().clamp(1, image.height - top);
        
        processedImage = img.copyCrop(image, x: left, y: top, width: width, height: height);
      } else {
        processedImage = image;
      }

      // 2. Resize (Không dùng Sharpen vì gây biến dạng đặc điểm AI)
      img.Image resized = img.copyResize(processedImage, width: 112, height: 112, interpolation: img.Interpolation.linear);
      final inputData = Float32List(1 * 3 * 112 * 112);
      
      int rOffset = 0;
      int gOffset = 112 * 112;
      int bOffset = 2 * 112 * 112;

      for (var pixel in resized) {
        // RGB normalized to [-1.0, 1.0] to match the ArcFace training configuration
        inputData[rOffset++] = (pixel.r - 127.5) / 128.0;
        inputData[gOffset++] = (pixel.g - 127.5) / 128.0;
        inputData[bOffset++] = (pixel.b - 127.5) / 128.0;
      }

      // Debug: In ra 5 giá trị đầu để kiểm tra
      debugPrint("FaceInferenceService: Input samples: ${inputData.take(5).toList()}");

      final shape = [1, 3, 112, 112];
      final inputTensor = OrtValueTensor.createTensorWithDataList(inputData, shape);
      
      // Lấy tên input đầu tiên của model
      final inputName = _session!.inputNames.first;
      final inputs = {inputName: inputTensor};

      // Chạy inference
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);

      if (outputs.isNotEmpty && outputs[0] != null) {
        final outputTensor = outputs[0] as OrtValueTensor;
        final rawEmbedding = outputTensor.value as List<dynamic>;
        
        // Giải phóng tensor và ảnh trung gian
        inputTensor.release();
        for (var output in outputs) {
          output?.release();
        }
        image.clear();
        processedImage.clear();
        resized.clear();

        // Chuyển về List<double> bằng cách flatten mảng
        List<double> result = [];
        void flatten(List<dynamic> list) {
          for (var item in list) {
            if (item is List) {
              flatten(item);
            } else if (item is num) {
              result.add(item.toDouble());
            }
          }
        }
        flatten(rawEmbedding);
        return result;
      }
    } catch (e) {
      debugPrint("FaceInferenceService: Inference Error: $e");
    }
    return null;
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _session?.release();
    _isInitialized = false;
  }

  /// Tính Cosine Distance (`1 - Cosine Similarity`)
  static double calculateCosineDistance(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) return 1.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      normA += vec1[i] * vec1[i];
      normB += vec2[i] * vec2[i];
    }

    if (normA == 0.0 || normB == 0.0) return 1.0;

    double similarity = dotProduct / (math.sqrt(normA) * math.sqrt(normB));
    return 1 - similarity;
  }
}

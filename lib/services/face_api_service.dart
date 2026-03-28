// lib/services/face_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FaceApiService {
  static String get baseUrl {
    return 'http://192.168.1.4:8000';
  }

  /// Gửi ảnh lên backend lấy vector embedding của khuôn mặt
  static Future<List<double>?> extractFace(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/extract-face'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);

        if (jsonResponse['success'] == true) {
          // Trả về mảng double 
          return List<double>.from(jsonResponse['embedding'].map((x) => x.toDouble()));
        } else {
          debugPrint("Face extraction point err: ${jsonResponse['error']}");
        }
      }
    } catch (e) {
      debugPrint("API Extract Error: $e");
    }
    return null;
  }

  /// Tính Cosine Distance giống trong code Python (`1 - Cosine Similarity`)
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

    double similarity = dotProduct / (sqrt(normA) * sqrt(normB));
    return 1 - similarity;
  }
}

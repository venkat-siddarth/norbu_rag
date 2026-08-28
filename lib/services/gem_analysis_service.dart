import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:norbu_rag/models/gem_scan.dart';

class IdentificationQuotaExceededException implements Exception {
  final String message;
  IdentificationQuotaExceededException(this.message);
  @override
  String toString() => message;
}

class GemAnalysisService extends ChangeNotifier {
  String _apiUrl = "https://rag-fast-api.vercel.app/identify";
  String get apiUrl => _apiUrl;

  set apiUrl(String val) {
    _apiUrl = val;
    notifyListeners();
  }

  Future<GemScan> analyzeGemImage(String imagePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      final mimeType = lookupMimeType(imagePath) ?? 'image/jpeg';

      request.files.add(await http.MultipartFile.fromPath(
        'image', 
        imagePath,
        contentType: MediaType.parse(mimeType),
        ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 429) {
        throw IdentificationQuotaExceededException(
          'Identification API rate limit exceeded (HTTP 429).',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'API call failed with status: ${response.statusCode}\nBody: ${response.body}',
        );
      }

      var responseData = json.decode(response.body);

      final predictions = responseData['answer'];

      if (predictions.isEmpty) {
        throw Exception('Invalid response schema: no identification returned.');
      }
      return _scanFromPredictions(predictions, imagePath);
    } catch (e) {
      if (e is IdentificationQuotaExceededException) rethrow;
      throw Exception('Failed to connect to identification API: $e');
    }
  }

  GemScan _scanFromPredictions(List<dynamic> predictions, String imagePath) {
    final predictionMaps = predictions
        .whereType<Map<String, dynamic>>()
        .toList();
    if (predictionMaps.isEmpty) {
      throw Exception('Invalid response schema. Predictions must be objects.');
    }

    final primary = GemScan.fromJson(
      predictionMaps.first,
      localImagePath: imagePath,
      timestamp: DateTime.now(),
    );
    final alternatives = predictionMaps
        .skip(1)
        .map(GemPrediction.fromJson)
        .toList();

    return GemScan(
      name: primary.name,
      characteristics: primary.characteristics,
      colors: primary.colors,
      description: primary.description,
      hardness: primary.hardness,
      uses: primary.uses,
      category: primary.category,
      confidence: primary.confidence,
      localImagePath: primary.localImagePath,
      timestamp: primary.timestamp,
      alternatives: alternatives,
    );
  }
}


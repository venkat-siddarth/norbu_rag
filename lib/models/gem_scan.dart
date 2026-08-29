class GemScan {
  final String name;
  final List<String> characteristics;
  final List<String> colors;
  final String description;
  final String hardness;
  final List<String> uses;
  final String category;
  final String confidence;
  final String localImagePath;
  final DateTime timestamp;
  GemScan({
    required this.name,
    required this.characteristics,
    required this.colors,
    required this.description,
    required this.hardness,
    required this.uses,
    required this.category,
    required this.confidence,
    required this.localImagePath,
    required this.timestamp,
    this.alternatives = const [],
  });
  final List<GemPrediction> alternatives;
  factory GemScan.fromJson(Map<String, dynamic> json, {required String localImagePath, DateTime? timestamp}) {
    if (json["uses"] is String) {json["uses"] = [json["uses"]];}
    return GemScan(
      name: json['name'] as String? ?? 'Unknown Gem',
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      colors: (json['colors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      description: json['description'] as String? ?? '',
      hardness: json['hardness'] as String? ?? 'N/A',
      uses: (json['uses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ?? [],
      category: json['category'] as String? ?? 'N/A',
      confidence: json['confidence'] as String? ?? '0%',
      localImagePath: localImagePath,
      timestamp: timestamp ?? DateTime.now(),
      alternatives: (json['alternatives'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GemPrediction.fromJson)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toPredictionJson() {
    return {
      'name': name,
      'characteristics': characteristics,
      'colors': colors,
      'description': description,
      'hardness': hardness,
      'uses': uses,
      'category': category,
      'confidence': confidence,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toPredictionJson(),
      'localImagePath': localImagePath,
      'timestamp': timestamp.toIso8601String(),
      'alternatives': alternatives.map((a) => a.toJson()).toList(),
    };
  }
}

class GemPrediction {
  final String name;
  final String confidence;
  final List<String> characteristics;
  final List<String> colors;
  final String description;
  final String hardness;
  final List<String> uses;
  final String category;

  GemPrediction({
    required this.name,
    required this.confidence,
    required this.characteristics,
    required this.colors,
    required this.description,
    required this.hardness,
    required this.uses,
    required this.category,
  });

  factory GemPrediction.fromJson(Map<String, dynamic> json) {
    if (json["uses"] is String) {json["uses"] = [json["uses"]];}
    return GemPrediction(
      name: json['name'] as String? ?? 'Unknown',
      confidence: json['confidence'] as String? ?? '0%',
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      colors: (json['colors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      description: json['description'] as String? ?? '',
      hardness: json['hardness'] as String? ?? 'N/A',
      uses: (json['uses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      category: json['category'] as String? ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'characteristics': characteristics,
      'colors': colors,
      'description': description,
      'hardness': hardness,
      'uses': uses,
      'category': category,
    };
  }
}


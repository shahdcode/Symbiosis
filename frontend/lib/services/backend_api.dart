import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/plant_model.dart';

const String kBackendBaseUrl = String.fromEnvironment(
  'SYMBIOSIS_API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

class BackendApiException implements Exception {
  final String message;

  const BackendApiException(this.message);

  @override
  String toString() => message;
}

enum PlantDisplayDifficulty { easy, medium, hard }

const List<PlantSvgType> _plantArtCycle = [
  PlantSvgType.monstera,
  PlantSvgType.calathea,
  PlantSvgType.ficus,
  PlantSvgType.lily,
  PlantSvgType.pothos,
  PlantSvgType.snake,
  PlantSvgType.zz,
  PlantSvgType.bird,
  PlantSvgType.rubber,
  PlantSvgType.alocasia,
];

int _seedHash(String seed) {
  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = 0x1fffffff & (hash + codeUnit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash;
}

PlantSvgType _artTypeFromSeed(String seed) {
  return _plantArtCycle[_seedHash(seed).abs() % _plantArtCycle.length];
}

class BackendPlant {
  final String plantId;
  final String commonName;
  final String species;
  final String? displayName;
  final String? plantType;
  final String? location;
  final double optimalMoisture;
  final double moistureMin;
  final double moistureMax;
  final double lightValue;
  final double moistureValue;
  final double dliRequirement;
  final double preferredHumidityPct;
  final double humidityMin;
  final double humidityMax;
  final double optimalTempC;
  final double tempMinC;
  final double tempMaxC;
  final double speciesWeight;
  final Map<String, dynamic> utilityParams;
  final String? notes;
  final String? updatedAt;
  final String? id;

  const BackendPlant({
    required this.plantId,
    required this.commonName,
    required this.species,
    required this.optimalMoisture,
    required this.moistureMin,
    required this.moistureMax,
    required this.lightValue,
    required this.moistureValue,
    required this.dliRequirement,
    required this.preferredHumidityPct,
    required this.humidityMin,
    required this.humidityMax,
    required this.optimalTempC,
    required this.tempMinC,
    required this.tempMaxC,
    required this.speciesWeight,
    required this.utilityParams,
    this.displayName,
    this.plantType,
    this.location,
    this.notes,
    this.updatedAt,
    this.id,
  });

  factory BackendPlant.fromJson(Map<String, dynamic> json) {
    double d(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    return BackendPlant(
      id: json['id']?.toString(),
      plantId: (json['plant_id'] ?? '').toString(),
      commonName: (json['common_name'] ?? '').toString(),
      species: (json['species'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      plantType: json['plant_type']?.toString(),
      location: json['location']?.toString(),
      optimalMoisture: d(json['optimal_moisture'], 50.0),
      moistureMin: d(json['moisture_min'], 30.0),
      moistureMax: d(json['moisture_max'], 80.0),
      lightValue: d(json['light_value'], 5.0),
      moistureValue: d(json['moisture_value'], 5.0),
      dliRequirement: d(json['dli_requirement'], 12.0),
      preferredHumidityPct: d(json['preferred_humidity_pct'], 50.0),
      humidityMin: d(json['humidity_min'], 30.0),
      humidityMax: d(json['humidity_max'], 80.0),
      optimalTempC: d(json['optimal_temp_c'], 22.0),
      tempMinC: d(json['temp_min_c'], 10.0),
      tempMaxC: d(json['temp_max_c'], 38.0),
      speciesWeight: d(json['species_weight'], 1.0),
      utilityParams: Map<String, dynamic>.from(
        json['utility_params'] ?? const {},
      ),
      notes: json['notes']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  BackendPlant copyWith({
    String? displayName,
    String? plantType,
    String? location,
  }) {
    return BackendPlant(
      id: id,
      plantId: plantId,
      commonName: commonName,
      species: species,
      displayName: displayName ?? this.displayName,
      plantType: plantType ?? this.plantType,
      location: location ?? this.location,
      optimalMoisture: optimalMoisture,
      moistureMin: moistureMin,
      moistureMax: moistureMax,
      lightValue: lightValue,
      moistureValue: moistureValue,
      dliRequirement: dliRequirement,
      preferredHumidityPct: preferredHumidityPct,
      humidityMin: humidityMin,
      humidityMax: humidityMax,
      optimalTempC: optimalTempC,
      tempMinC: tempMinC,
      tempMaxC: tempMaxC,
      speciesWeight: speciesWeight,
      utilityParams: utilityParams,
      notes: notes,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'common_name': commonName,
      'species': species,
      'display_name': displayName,
      'plant_type': plantType,
      'location': location,
      'optimal_moisture': optimalMoisture,
      'moisture_min': moistureMin,
      'moisture_max': moistureMax,
      'light_value': lightValue,
      'moisture_value': moistureValue,
      'dli_requirement': dliRequirement,
      'preferred_humidity_pct': preferredHumidityPct,
      'humidity_min': humidityMin,
      'humidity_max': humidityMax,
      'optimal_temp_c': optimalTempC,
      'temp_min_c': tempMinC,
      'temp_max_c': tempMaxC,
      'species_weight': speciesWeight,
      'utility_params': utilityParams,
      'notes': notes,
      'updated_at': updatedAt,
      'id': id,
    };
  }

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : commonName;

  String get typeLabel {
    if (plantType != null && plantType!.trim().isNotEmpty) {
      return plantType!.trim();
    }
    return lightValue >= 7.0 || dliRequirement >= 16.0 ? 'Outdoor' : 'Indoor';
  }

  PlantDisplayDifficulty get difficulty {
    if (lightValue <= 4.5 && optimalMoisture >= 55.0) {
      return PlantDisplayDifficulty.easy;
    }
    if (lightValue >= 7.0 || dliRequirement >= 17.5) {
      return PlantDisplayDifficulty.hard;
    }
    return PlantDisplayDifficulty.medium;
  }

  static PlantSvgType svgTypeFor(
    String commonName,
    String species,
    String plantId,
  ) {
    final text =
        '${commonName.toLowerCase()} ${species.toLowerCase()} ${plantId.toLowerCase()}';
    if (text.contains('monstera')) return PlantSvgType.monstera;
    if (text.contains('calathea')) return PlantSvgType.calathea;
    if (text.contains('ficus') || text.contains('fiddle'))
      return PlantSvgType.ficus;
    if (text.contains('lily')) return PlantSvgType.lily;
    if (text.contains('pothos')) return PlantSvgType.pothos;
    if (text.contains('snake')) return PlantSvgType.snake;
    if (text.contains('zz')) return PlantSvgType.zz;
    if (text.contains('bird')) return PlantSvgType.bird;
    if (text.contains('rubber')) return PlantSvgType.rubber;
    if (text.contains('alocasia')) return PlantSvgType.alocasia;
    return _artTypeFromSeed('$plantId|$commonName|$species');
  }

  PlantSvgType get svgType => svgTypeFor(commonName, species, plantId);
}

class BackendDiseaseResult {
  final String predictedClass;
  final String displayName;
  final double confidence;
  final bool isHealthy;
  final String plant;
  final String disease;
  final Map<String, double> allScores;

  const BackendDiseaseResult({
    required this.predictedClass,
    required this.displayName,
    required this.confidence,
    required this.isHealthy,
    required this.plant,
    required this.disease,
    required this.allScores,
  });

  factory BackendDiseaseResult.fromJson(Map<String, dynamic> json) {
    final scores = <String, double>{};
    final rawScores = json['all_scores'];
    if (rawScores is Map) {
      rawScores.forEach((key, value) {
        if (value is num) {
          scores[key.toString()] = value.toDouble();
        } else if (value is String) {
          scores[key.toString()] = double.tryParse(value) ?? 0.0;
        }
      });
    }

    return BackendDiseaseResult(
      predictedClass: (json['predicted_class'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isHealthy: json['is_healthy'] == true,
      plant: (json['plant'] ?? '').toString(),
      disease: (json['disease'] ?? '').toString(),
      allScores: scores,
    );
  }

  List<MapEntry<String, double>> topScores([int limit = 3]) {
    final entries =
        allScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  List<String> get insightLines => [
    displayName.isNotEmpty ? displayName : disease,
    'Confidence ${(confidence * 100).round()}%',
    isHealthy ? 'No disease detected' : 'Detected issue: $disease',
  ];
}

class BackendPlantStats {
  final double moisture;
  final double humidity;
  final double light;
  final double temp;
  final double waterTank;
  final double fertilizer;
  final double nextWateringMinutes;
  final String lastWatered;
  final int addedWeeks;
  final double health;
  final String status;

  const BackendPlantStats({
    required this.moisture,
    required this.humidity,
    required this.light,
    required this.temp,
    required this.waterTank,
    required this.fertilizer,
    required this.nextWateringMinutes,
    required this.lastWatered,
    required this.addedWeeks,
    required this.health,
    required this.status,
  });

  factory BackendPlantStats.fromJson(Map<String, dynamic> json) {
    double d(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    return BackendPlantStats(
      moisture: d(json['moisture'], 0.0),
      humidity: d(json['humidity'], 0.0),
      light: d(json['light'], 0.0),
      temp: d(json['temp'], 0.0),
      waterTank: d(json['water_tank'], 0.0),
      fertilizer: d(json['fertilizer'], 0.0),
      nextWateringMinutes: d(json['next_watering_minutes'], 0.0),
      lastWatered: (json['last_watered'] ?? 'Unknown').toString(),
      addedWeeks: (json['added_weeks'] as num?)?.toInt() ?? 0,
      health: d(json['health'], 0.0),
      status: (json['status'] ?? 'resting').toString(),
    );
  }
}

class BackendPlantDetail {
  final BackendPlant plant;
  final Map<String, dynamic>? latestReading;
  final Map<String, dynamic> learning;
  final BackendPlantStats stats;

  const BackendPlantDetail({
    required this.plant,
    required this.latestReading,
    required this.learning,
    required this.stats,
  });

  factory BackendPlantDetail.fromJson(Map<String, dynamic> json) {
    final plant = BackendPlant.fromJson(
      Map<String, dynamic>.from(json['plant'] as Map),
    );
    final latestReading = json['latest_reading'];
    final learning = Map<String, dynamic>.from(
      (json['learning'] as Map?) ?? const {},
    );
    final stats = BackendPlantStats.fromJson(
      Map<String, dynamic>.from((json['stats'] as Map?) ?? const {}),
    );

    return BackendPlantDetail(
      plant: plant,
      latestReading:
          latestReading is Map
              ? Map<String, dynamic>.from(latestReading)
              : null,
      learning: learning,
      stats: stats,
    );
  }
}

class BackendApi {
  BackendApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse(
      '$kBackendBaseUrl$path',
    ).replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const BackendApiException('Unexpected backend response shape');
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded;
    }
    throw const BackendApiException('Unexpected backend response shape');
  }

  Never _throwResponseError(http.Response response) {
    final message = () {
      try {
        final data = _decodeObject(response);
        final detail = data['detail'];
        if (detail != null) {
          return detail.toString();
        }
      } catch (_) {
        // Fall through to the raw body.
      }
      return response.body.isNotEmpty ? response.body : 'Request failed';
    }();
    throw BackendApiException('HTTP ${response.statusCode}: $message');
  }

  Future<List<BackendPlant>> fetchPlants() async {
    final response = await _client.get(_uri('/plants/'));
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return _decodeList(response)
        .whereType<Map>()
        .map((item) => BackendPlant.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BackendPlant>> fetchPlantLibrary({int limit = 12}) async {
    final response = await _client.get(
      _uri('/plants/library', {'limit': '$limit'}),
    );
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return _decodeList(response)
        .whereType<Map>()
        .map((item) => BackendPlant.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BackendPlant> fetchPlant(String plantId) async {
    final response = await _client.get(_uri('/plants/$plantId'));
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendPlant.fromJson(_decodeObject(response));
  }

  Future<BackendPlantDetail> fetchPlantDetail(String plantId) async {
    final response = await _client.get(_uri('/plants/$plantId/detail'));
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendPlantDetail.fromJson(_decodeObject(response));
  }

  Future<BackendPlant> createPlantFromScientificName(
    String scientificName,
  ) async {
    final response = await _client.post(
      _uri('/plants/', {'scientific_name': scientificName}),
    );
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendPlant.fromJson(_decodeObject(response));
  }

  Future<BackendPlant> upsertPlant(BackendPlant plant) async {
    final response = await _client.put(
      _uri('/plants/${plant.plantId}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(plant.toJson()),
    );
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendPlant.fromJson(_decodeObject(response));
  }

  Future<BackendDiseaseResult> detectDisease({
    required String plantId,
    required XFile imageFile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/disease/detect', {'plant_id': plantId}),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendDiseaseResult.fromJson(_decodeObject(response));
  }

  Future<BackendDiseaseResult> fetchDiseaseHistory(String plantId) async {
    final response = await _client.get(_uri('/disease/$plantId/history'));
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    return BackendDiseaseResult.fromJson(_decodeObject(response));
  }
}

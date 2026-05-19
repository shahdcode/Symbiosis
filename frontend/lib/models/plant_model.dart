import 'package:flutter/material.dart';

enum PlantStatus { thriving, attention, resting }

class PlantModel {
  final int id;
  final String name;
  final String species;
  final String type;
  final PlantStatus status;
  final int moisture;
  final int humidity;
  final int light;
  final int temp;
  final int waterTank;
  final int fertilizer;
  final int nextWateringMinutes;
  final String lastWatered;
  final int addedWeeks;
  final int health;
  final String description;
  final Map<String, String> idealConditions;
  final Color color;
  final Color lightColor;
  final PlantSvgType svgType;

  const PlantModel({
    required this.id,
    required this.name,
    required this.species,
    required this.type,
    required this.status,
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
    required this.description,
    required this.idealConditions,
    required this.color,
    required this.lightColor,
    required this.svgType,
  });

  Color get statusColor {
    switch (status) {
      case PlantStatus.thriving:
        return const Color(0xFF4CAF50);
      case PlantStatus.attention:
        return const Color(0xFFFF9800);
      case PlantStatus.resting:
        return const Color(0xFF2196F3);
    }
  }

  String get statusLabel {
    switch (status) {
      case PlantStatus.thriving:
        return 'Thriving';
      case PlantStatus.attention:
        return 'Attention';
      case PlantStatus.resting:
        return 'Resting';
    }
  }
}

enum PlantSvgType { monstera, calathea, ficus, lily, pothos, snake, zz, bird, rubber, alocasia }

class ExplorePlant {
  final String name;
  final String species;
  final String type;
  final String difficulty;
  final PlantSvgType svgType;

  const ExplorePlant({
    required this.name,
    required this.species,
    required this.type,
    required this.difficulty,
    required this.svgType,
  });
}

final List<PlantModel> myPlants = [
  PlantModel(
    id: 1,
    name: 'Monstera',
    species: 'Monstera deliciosa',
    type: 'Indoor',
    status: PlantStatus.thriving,
    moisture: 72,
    humidity: 65,
    light: 82,
    temp: 23,
    waterTank: 68,
    fertilizer: 45,
    nextWateringMinutes: 14,
    lastWatered: '2 days ago',
    addedWeeks: 8,
    health: 94,
    description:
        'The Swiss cheese plant is a species of flowering plant native to tropical forests of southern Mexico. Known for its dramatic, perforated leaves, it\'s one of the most beloved houseplants worldwide.',
    idealConditions: {
      'Moisture': '60–80%',
      'Humidity': '60–80%',
      'Light': 'Bright indirect',
      'Temperature': '18–30°C',
      'Watering': 'Every 1–2 weeks',
    },
    color: const Color(0xFF2D5A27),
    lightColor: const Color(0xFFE8F5E3),
    svgType: PlantSvgType.monstera,
  ),
  PlantModel(
    id: 2,
    name: 'Calathea',
    species: 'Calathea orbifolia',
    type: 'Indoor',
    status: PlantStatus.attention,
    moisture: 19,
    humidity: 55,
    light: 78,
    temp: 22,
    waterTank: 10,
    fertilizer: 86,
    nextWateringMinutes: 36,
    lastWatered: '5 days ago',
    addedWeeks: 26,
    health: 71,
    description:
        'Calathea orbifolia is a prayer plant native to Bolivia. Its large, rounded leaves with silver-green stripes make it one of the most striking foliage plants. Sensitive and rewarding to care for.',
    idealConditions: {
      'Moisture': '50–70%',
      'Humidity': '50–60%',
      'Light': 'Low to medium',
      'Temperature': '18–24°C',
      'Watering': 'Every week',
    },
    color: const Color(0xFF1A6B3A),
    lightColor: const Color(0xFFE0F4EA),
    svgType: PlantSvgType.calathea,
  ),
  PlantModel(
    id: 3,
    name: 'Fiddle Leaf',
    species: 'Ficus lyrata',
    type: 'Indoor',
    status: PlantStatus.thriving,
    moisture: 58,
    humidity: 48,
    light: 91,
    temp: 24,
    waterTank: 68,
    fertilizer: 62,
    nextWateringMinutes: 52,
    lastWatered: '1 day ago',
    addedWeeks: 12,
    health: 88,
    description:
        'The fiddle-leaf fig is a species of flowering plant in the mulberry and fig family Moraceae. Native to tropical West Africa, it\'s prized for its large, violin-shaped leaves.',
    idealConditions: {
      'Moisture': '40–60%',
      'Humidity': '30–65%',
      'Light': 'Bright direct',
      'Temperature': '16–24°C',
      'Watering': 'Every 1–2 weeks',
    },
    color: const Color(0xFF3D6B1A),
    lightColor: const Color(0xFFEBF5E0),
    svgType: PlantSvgType.ficus,
  ),
  PlantModel(
    id: 4,
    name: 'Peace Lily',
    species: 'Spathiphyllum wallisii',
    type: 'Indoor',
    status: PlantStatus.resting,
    moisture: 44,
    humidity: 70,
    light: 55,
    temp: 21,
    waterTank: 68,
    fertilizer: 30,
    nextWateringMinutes: 80,
    lastWatered: '3 days ago',
    addedWeeks: 4,
    health: 82,
    description:
        'The peace lily is a tropical species that grows in the warm, humid forests of the Americas and southeastern Asia. It produces elegant white spathes and is renowned for its air-purifying qualities.',
    idealConditions: {
      'Moisture': '40–60%',
      'Humidity': '50–80%',
      'Light': 'Low to medium',
      'Temperature': '18–30°C',
      'Watering': 'Every 1–2 weeks',
    },
    color: const Color(0xFF2A5C3F),
    lightColor: const Color(0xFFE2F0EB),
    svgType: PlantSvgType.lily,
  ),
];

final List<ExplorePlant> explorePlants = [
  const ExplorePlant(name: 'Pothos', species: 'Epipremnum aureum', type: 'Indoor', difficulty: 'Easy', svgType: PlantSvgType.pothos),
  const ExplorePlant(name: 'Snake Plant', species: 'Dracaena trifasciata', type: 'Indoor', difficulty: 'Easy', svgType: PlantSvgType.snake),
  const ExplorePlant(name: 'ZZ Plant', species: 'Zamioculcas zamiifolia', type: 'Indoor', difficulty: 'Easy', svgType: PlantSvgType.zz),
  const ExplorePlant(name: 'Bird of Paradise', species: 'Strelitzia reginae', type: 'Outdoor', difficulty: 'Medium', svgType: PlantSvgType.bird),
  const ExplorePlant(name: 'Rubber Plant', species: 'Ficus elastica', type: 'Indoor', difficulty: 'Easy', svgType: PlantSvgType.rubber),
  const ExplorePlant(name: 'Alocasia', species: 'Alocasia amazonica', type: 'Indoor', difficulty: 'Hard', svgType: PlantSvgType.alocasia),
];

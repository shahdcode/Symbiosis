import 'package:flutter/material.dart';

class NavItem {
  const NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class StatTileData {
  const StatTileData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class DecisionEntry {
  const DecisionEntry({
    required this.time,
    required this.icon,
    required this.title,
    required this.reason,
    required this.emphasis,
    required this.color,
  });

  final String time;
  final IconData icon;
  final String title;
  final String reason;
  final String emphasis;
  final Color color;
}

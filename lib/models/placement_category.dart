import 'package:flutter/material.dart';
import 'course.dart';

class PlacementCategory {
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;

  const PlacementCategory({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
  });

  Course toCourse() => Course(
    id: 0,
    abbreviation: name,
    fullName: subtitle,
    icon: icon,
    gradientColors: gradientColors,
  );

  static const List<PlacementCategory> allCategories = [
    PlacementCategory(
      name: 'Aptitude',
      subtitle: 'Quantitative & Logical',
      icon: Icons.psychology,
      gradientColors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
    ),
    PlacementCategory(
      name: 'Coding',
      subtitle: 'DSA & Programming',
      icon: Icons.code,
      gradientColors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
    ),
    PlacementCategory(
      name: 'Verbal',
      subtitle: 'English & Communication',
      icon: Icons.text_fields,
      gradientColors: [Color(0xFFE85D04), Color(0xFFD62828)],
    ),
    PlacementCategory(
      name: 'Reasoning',
      subtitle: 'Logical Reasoning',
      icon: Icons.hub,
      gradientColors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
    ),
    PlacementCategory(
      name: 'Interview',
      subtitle: 'HR & Technical',
      icon: Icons.work,
      gradientColors: [Color(0xFF00838F), Color(0xFF006064)],
    ),
    PlacementCategory(
      name: 'GD',
      subtitle: 'Group Discussion',
      icon: Icons.groups,
      gradientColors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
    ),
  ];
}

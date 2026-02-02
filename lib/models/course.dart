import 'package:flutter/material.dart';

/// Course model with ID, abbreviation, and full name
class Course {
  final int id;
  final String abbreviation;
  final String fullName;
  final IconData icon;
  final List<Color> gradientColors;

  const Course({
    required this.id,
    required this.abbreviation,
    required this.fullName,
    required this.icon,
    required this.gradientColors,
  });

  static const List<Course> allCourses = [
    Course(
      id: 1,
      abbreviation: 'CSE',
      fullName: 'Computer Science and Engineering',
      icon: Icons.code,
      gradientColors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
    ),
    Course(
      id: 2,
      abbreviation: 'ECE',
      fullName: 'Electronics and Communication Engineering',
      icon: Icons.memory,
      gradientColors: [Color(0xFF00838F), Color(0xFF006064)],
    ),
    Course(
      id: 3,
      abbreviation: 'EEE',
      fullName: 'Electrical and Electronics Engineering',
      icon: Icons.electrical_services,
      gradientColors: [Color(0xFFE85D04), Color(0xFFD62828)],
    ),
    Course(
      id: 4,
      abbreviation: 'CIVIL',
      fullName: 'Civil Engineering',
      icon: Icons.architecture,
      gradientColors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
    ),
    Course(
      id: 5,
      abbreviation: 'MECHANICAL',
      fullName: 'Mechanical Engineering',
      icon: Icons.settings,
      gradientColors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
    ),
  ];
}

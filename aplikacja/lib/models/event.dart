import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;

class Event {
  final String id;
  final String name;
  final String location;
  final String description;
  final String type;
  final DateTime startDate;
  final int maxParticipants;
  final int registeredParticipants;
  final String imagePath;
  final int? userId;
  final double cena;
  final bool isPromoted;
  final double recommendationScore;
  final int userScore;

  const Event({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.type,
    required this.startDate,
    required this.maxParticipants,
    required this.registeredParticipants,
    required this.imagePath,
    this.userId,
    required this.cena,
    required this.isPromoted,
    this.recommendationScore = 0.0,
    this.userScore = 0,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      startDate: _parseDateTime(json['start_date']),
      maxParticipants: _parseIntSafely(json['max_participants']) ?? 0,
      registeredParticipants: _parseIntSafely(json['registered_participants']) ?? 0,
      imagePath: json['image']?.toString() ?? '',
      userId: _parseIntSafely(json['user_id']),
      cena: _parseDoubleSafely(json['cena']) ?? 0.0,
      isPromoted: json['is_promoted'] == 1 || json['is_promoted'] == true,
      userScore: _parseIntSafely(json['score']) ?? 0,
    );
  }

  // Bezpieczne parsowanie wartości liczbowych
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      print('Błąd parsowania daty: $e dla wartości: $value');
      return DateTime.now();
    }
  }

  Event copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? type,
    DateTime? startDate,
    int? maxParticipants,
    int? registeredParticipants,
    String? imagePath,
    int? userId,
    double? cena,
    bool? isPromoted,
    double? recommendationScore,
    int? userScore,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.location,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      registeredParticipants:
          registeredParticipants ?? this.registeredParticipants,
      imagePath: imagePath ?? this.imagePath,
      userId: userId ?? this.userId,
      cena: cena ?? this.cena,
      isPromoted: isPromoted ?? this.isPromoted,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      userScore: userScore ?? this.userScore,
    );
  }

  String dateFormated(DateTime startDate) {
    List<String> months = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia'
    ];
    String result =
        '${startDate.day} ${months[startDate.month - 1]} ${startDate.year}';

    return (result);
  }

  static Future<bool> assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true; // plik istnieje
    } catch (e) {
      return false; // plik nie istnieje
    }
  }

  static Widget getIcon(String eventType) {
    String iconPath = "assets/type_icons/$eventType.svg";

    return FutureBuilder<bool>(
      future: assetExists(iconPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Icon(Icons.hourglass_empty);
        }
        if (snapshot.hasError || snapshot.data == false) {
          return Icon(Icons.hive_sharp);
        }
        return SvgPicture.asset(iconPath, width: 30, height: 30);
      },
    );
  }
}

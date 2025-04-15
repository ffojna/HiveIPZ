import 'package:intl/intl.dart';

class Comment {
  final String id;
  final String userId;
  final String username;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final formatter = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');

    return Comment(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      username: json['username'] ?? 'Nieznany użytkownik',
      text: json['text'] ?? '',
      createdAt: formatter.parse(json['created_at']),
    );
  }
}

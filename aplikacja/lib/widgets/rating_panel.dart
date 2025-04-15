import 'package:flutter/material.dart';
import '../models/event.dart';

class RatingPanel extends StatelessWidget {
  final Event event;
  final Map<String, dynamic>? userRating;
  final Function(bool isLike) onRate;

  const RatingPanel({
    required this.event,
    required this.userRating,
    required this.onRate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        ListTile(
          leading: Icon(
            Icons.thumb_up_alt_outlined,
            size: 35,
            color: userRating?['rating'] == 'like'
                ? Colors.green
                : Colors.white,
          ),
          onTap: () => onRate(true),
        ),
        ListTile(
          leading: Icon(
            Icons.thumb_down_alt_outlined,
            size: 35,
            color: userRating?['rating'] == 'dislike'
                ? Colors.red
                : Colors.white,
          ),
          onTap: () => onRate(false),
        ),
        Text(
          'Wynik: ${userRating?['score'] ?? 0}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}

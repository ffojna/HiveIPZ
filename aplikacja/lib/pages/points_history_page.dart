import 'package:flutter/material.dart';
import '../database/database_helper.dart'; // Upewnij się, że ścieżka jest poprawna
import 'package:intl/intl.dart'; // Dodaj pakiet intl: flutter pub add intl

class PointsHistoryPage extends StatefulWidget {
  final int userId;

  const PointsHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _PointsHistoryPageState createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = DatabaseHelper.getPointsHistory(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historia HoneyCoins'),
        backgroundColor: Color(0xFFF9D220), // Kolor pasujący do motywu
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Błąd ładowania historii: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Brak historii punktów.'));
          }

          final history = snapshot.data!;

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final pointsChange = int.parse(item['points_change'].toString());
              final isPositive = pointsChange > 0;
              final date = DateTime.parse(item['created_at']);
              final formattedDate = DateFormat('dd.MM.yyyy, HH:mm').format(date);

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 36,
                  ),
                  title: Text(
                    item['reason'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    '${isPositive ? '+' : ''}$pointsChange',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../styles/hive_colors.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({Key? key}) : super(key: key);

  @override
  _PointsPageState createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  Map<String, dynamic>? userData;
  int? userId;
  int? userPoints;
  List<Event>? userEvents; // Lista obiektów Event
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception("Brak tokena w SharedPreferences");
      }

      final data = await DatabaseHelper.getUserByToken(token);

      setState(() {
        userData = data;
        userId = data?['id'];
        userPoints = data?['points'];
      });
      // Pobranie wydarzeń dla tego użytkownika
      if (userId != null) {
        final events = await DatabaseHelper.getUserEvents(userId!);
        setState(() {
          userEvents = events?.map((eventMap) {
            return Event(
              id: eventMap['id'],
              name: eventMap['name'],
              location: eventMap['location'],
              description: eventMap['description'],
              type: eventMap['type'],
              startDate: DateTime.parse(eventMap['start_date']),
              updatedAt: DateTime.parse(eventMap['updated_at']),
              maxParticipants: eventMap['max_participants'],
              registeredParticipants: eventMap['registered_participants'],
              imagePath: eventMap['image'],
              userId: eventMap['user_id'],
              cena: double.tryParse(eventMap['cena'].toString()) ?? 0.0,
              isPromoted: eventMap['is_promoted'] == 1,
            );
          }).toList();
        });
      }
    } catch (e) {
      print('Błąd podczas pobierania danych użytkownika: $e');
    }
  }

  // Funkcja do promowania wydarzenia
  Future<void> promoteEvent(Event event) async {
    if (userPoints! < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie masz wystarczająco punktów!')),
      );
      return;
    }

    // Zmniejszamy punkty użytkownika o 1000
    try {
      final updatedUser = userData!;
      updatedUser['points'] =
          userPoints! - 1000; // Zmniejszamy punkty użytkownika

      // Aktualizujemy dane użytkownika
      await DatabaseHelper.updateUser(
          userId.toString(), {'points': updatedUser['points'].toString()});

      // Używamy copyWith na obiekcie Event i zmieniamy isPromoted
      Event updatedEvent = event.copyWith(isPromoted: true);

      // Aktualizujemy wydarzenie w bazie danych
      await DatabaseHelper.updateEvent(event.id, {
        'name': event.name,
        'location': event.location,
        'description': event.description,
        'type': event.type,
        'start_date': event.startDate.toIso8601String(),
        'max_participants': event.maxParticipants,
        'registered_participants': event.registeredParticipants,
        'image': event.imagePath,
        'is_promoted': updatedEvent.isPromoted,
      });

      // Aktualizujemy stan aplikacji
      setState(() {
        userPoints = updatedUser['points'];
        final index = userEvents?.indexWhere((e) => e.id == event.id);
        if (index != null && index >= 0) {
          userEvents?[index] = updatedEvent;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wydarzenie zostało promowane!')),
      );
    } catch (e) {
      print("Błąd podczas promocji wydarzenia: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas promocji wydarzenia: $e')),
      );
    }
  }

  void _showEventSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Wybierz wydarzenie do promocji'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userEvents?.length ?? 0,
              itemBuilder: (context, index) {
                final event = userEvents?[index];
                return ListTile(
                  title: Text(event?.name ?? 'Brak nazwy'),
                  trailing: event?.isPromoted == true
                      ? Icon(Icons.star, color: Colors.orange)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    promoteEvent(event!);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showPromoTicketConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Potwierdzenie'),
          content: Text(
            'Czy na pewno chcesz wykupić promocję -10zł na dowolny bilet za 3500 HoneyCoins?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                if ((userPoints ?? 0) < 3500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Nie masz wystarczająco HoneyCoins!')),
                  );
                  return;
                }

                try {
                  // Odejmij punkty
                  int newPoints = userPoints! - 3500;
                  await DatabaseHelper.updateUser(
                    userId.toString(),
                    {'points': newPoints.toString()},
                  );

                  // Dodaj promocję
                  final hasPromo = await DatabaseHelper.hasPromotion(
                      userId!, 'promo_ticket');
                  if (hasPromo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Masz już aktywną promocję -10zł.')),
                    );
                    return;
                  }
                  await DatabaseHelper.addUserPromotion(
                      userId!, 'promo_ticket');

                  setState(() {
                    userPoints = newPoints;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Promocja została wykupiona!')),
                  );
                } catch (e) {
                  print('Błąd przy wykupie: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wystąpił błąd podczas wykupu.')),
                  );
                }
              },
              child: Text('Tak, wykup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double cardWidth = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: HiveColors.main,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: cardWidth,
              height: 160,
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/honeycoins.png', // Zastąp nazwą swojego pliku PNG
                    height: 100, // Opcjonalnie, ustaw wysokość ikony
                    width: 100, // Opcjonalnie, ustaw szerokość ikony
                  ),
                  SizedBox(width: 10),
                  Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center vertically
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("HoneyCoins",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w200)),
                      Text(
                        userPoints?.toString() ?? '0',
                        style: TextStyle(
                          fontSize: 34,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(120.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text("Lista nagród",
                          style: TextStyle(
                              fontSize: 34, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(120.0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 20),
                              Column(
                                children: [
                                  RewardCard(
                                    title: "Promowanie wydarzenia",
                                    priceText: "1000′",
                                    badgeText:
                                        "", // niepotrzebne, bo używamy ikony
                                    isIcon: true,
                                    onTap: () {
                                      if ((userEvents?.isEmpty ?? true)) { // This condition becomes true
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Brak wydarzeń do promowania.")), // This message is shown
                                        );
                                        return;
                                      }
                                      _showEventSelectionDialog();
                                    },
                                  ),
                                  RewardCard(
                                    title: "Promocja na dowolny bilet",
                                    priceText: "3500′",
                                    badgeText: "-10zł",
                                    isIcon: false,
                                    onTap: () {
                                      _showPromoTicketConfirmationDialog();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RewardCard extends StatefulWidget {
  final String title;
  final String priceText;
  final String badgeText;
  final bool isIcon;
  final VoidCallback onTap;

  const RewardCard({
    required this.title,
    required this.priceText,
    required this.badgeText,
    this.isIcon = false,
    required this.onTap,
    super.key,
  });

  @override
  State<RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<RewardCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: 160,
              color: Colors.white, // tło przeniesione tutaj
              child: Stack(
                children: [
                  // Żółte kółko
                  Positioned(
                    top: -10,
                    right: -10,
                    child: Transform.translate(
                      offset: Offset(8, -4),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.yellow[600],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: widget.isIcon
                              ? Icon(Icons.trending_up,
                                  size: 80, color: Colors.black)
                              : Text(
                                  widget.badgeText,
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Treść
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.priceText,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        Spacer(),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

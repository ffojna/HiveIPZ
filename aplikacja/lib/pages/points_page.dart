import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../styles/hive_colors.dart';
import 'points_history_page.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({Key? key}) : super(key: key);

  @override
  _PointsPageState createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  Map<String, dynamic>? userData;
  int? userId;
  int? userPoints;
  List<Event>? userEvents;
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
      final data = await DatabaseHelper.getUserByToken(token); // Załóżmy, że ta funkcja istnieje
      setState(() {
        userData = data;
        userId = data?['id'];
        userPoints = data?['points'];
      });
      if (userId != null) {
        final events = await DatabaseHelper.getUserEvents(userId!); // Załóżmy, że ta funkcja istnieje
        setState(() {
          userEvents = events?.map((eventMap) => Event.fromJson(eventMap)).toList();
        });
      }
    } catch (e) {
      print('Błąd podczas pobierania danych użytkownika: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas pobierania danych: $e')),
        );
      }
    }
  }

  // Zaktualizowana funkcja do promowania wydarzenia
  Future<void> promoteEvent(Event event) async {
    if ((userPoints ?? 0) < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie masz wystarczająco punktów!')),
      );
      return;
    }

    try {
      // **POPRAWIONA LOGIKA**
      // Jedno wywołanie do serwera, które obsługuje obie operacje
      await DatabaseHelper.spendPoints(
        userId: userId!,
        pointsToSpend: 1000,
        reason: 'Promowanie wydarzenia: ${event.name}',
      );

      // Używamy copyWith na obiekcie Event i zmieniamy isPromoted
      Event updatedEvent = event.copyWith(isPromoted: true);

      // Aktualizujemy wydarzenie lokalnie i w bazie danych
      await DatabaseHelper.updateEvent(event.id, {'is_promoted': true}); // Załóżmy, że ta funkcja istnieje

      // Aktualizujemy stan aplikacji
      setState(() {
        userPoints = (userPoints ?? 0) - 1000;
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
                final event = userEvents![index];
                return ListTile(
                  title: Text(event.name),
                  enabled: !event.isPromoted,
                  trailing: event.isPromoted
                      ? Icon(Icons.star, color: Colors.orange)
                      : null,
                  onTap: () {
                    if (!event.isPromoted) {
                      Navigator.of(context).pop();
                      promoteEvent(event);
                    }
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
                    SnackBar(content: Text('Nie masz wystarczająco HoneyCoins!')),
                  );
                  return;
                }

                try {
                  // **POPRAWIONA LOGIKA**
                  await DatabaseHelper.spendPoints(
                    userId: userId!,
                    pointsToSpend: 3500,
                    reason: 'Zakup promocji -10zł na bilet',
                  );

                  // Dodajemy promocję po stronie klienta i w bazie
                  await DatabaseHelper.addUserPromotion(userId!, 'promo_ticket'); // Załóżmy, że ta funkcja istnieje

                  setState(() {
                    userPoints = (userPoints ?? 0) - 3500;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Promocja została wykupiona!')),
                  );
                } catch (e) {
                  print('Błąd przy wykupie: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wystąpił błąd podczas wykupu: $e')),
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


  void _showPriorityQueueConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Potwierdzenie'),
          content: Text(
            'Czy na pewno chcesz wykupić dostęp do kolejek priorytetowych za 5000 HoneyCoins?',
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

                if ((userPoints ?? 0) < 5000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Nie masz wystarczająco HoneyCoins!')),
                  );
                  return;
                }

                try {
                  // **POPRAWIONA LOGIKA**
                  await DatabaseHelper.spendPoints(
                    userId: userId!,
                    pointsToSpend: 5000,
                    reason: 'Zakup dostępu do kolejki priorytetowej',
                  );

                  await DatabaseHelper.addUserPromotion(userId!, 'priority_queue'); // Załóżmy, że ta funkcja istnieje

                  setState(() {
                    userPoints = (userPoints ?? 0) - 5000;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dostęp priorytetowy został aktywowany!')),
                  );
                } catch (e) {
                  print('Błąd przy wykupie dostępu priorytetowego: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Wystąpił błąd podczas wykupu: $e')),
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
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.black, size: 28),
            onPressed: () {
              if (userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PointsHistoryPage(userId: userId!),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nie można załadować historii. Spróbuj ponownie.')),
                );
              }
            },
          ),
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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
                      'assets/honeycoins.png',
                      height: 100,
                      width: 100,
                    ),
                    SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
            Container(
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
                    Column(
                      children: [
                        RewardCard(
                          title: "Promowanie wydarzenia",
                          priceText: "1000′",
                          badgeText: "",
                          isIcon: true,
                          onTap: () {
                            if ((userEvents?.isEmpty ?? true)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Brak wydarzeń do promowania.")),
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
                        RewardCard(
                          title: "Dostęp do kolejki priorytetowej",
                          priceText: "5000′",
                          badgeText: "FAST",
                          isIcon: false,
                          onTap: () {
                            _showPriorityQueueConfirmationDialog();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ten widget pozostaje bez zmian
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
              color: Colors.white,
              child: Stack(
                children: [
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
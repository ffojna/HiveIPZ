import 'package:flutter/material.dart';
import '../models/event.dart';
import '../styles/gradients.dart';
import '../pages/edit_event_page.dart';
import '../database/database_helper.dart';
import '../styles/text_styles.dart';

/// Strona realizująca widok szczegółowy wydarzenia
class EventPage extends StatefulWidget {
  final Event event;
  final Function(Event) onUpdate;

  const EventPage({super.key, required this.event, required this.onUpdate});

  @override
  _EventPageState createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  late Event currentEvent; // aktualne wydarzenie
  bool isUserJoined = false; // Czy użytkownik jest zapisany na wydarzenie
  bool isUserOwner = false; // Czy użytkownik jest właścicielem wydarzenia?
  String? userId; // Przechowywanie userId

  @override
  void initState() {
    super.initState();
    currentEvent = widget.event;
    _fetchEvent();
    _initializeUser(); // Inicjalizacja użytkownika
  }



  Future<void> _initializeUser() async {
    try {
      userId = await DatabaseHelper.getUserIdFromToken();
      _checkUserJoinedStatus();
      _checkIfUserIsOwner();
    } catch (e) {
      print('Błąd podczas inicjalizacji użytkownika: $e');
    }
  }

  Future<void> _fetchEvent() async {
    try {
      final eventData = await DatabaseHelper.getEvent(widget.event.id);
      if (eventData != null) {
        setState(() {
          currentEvent = Event.fromJson(eventData);
        });
      }
    } catch (e) {
      print('Błąd podczas pobierania wydarzenia: $e');
    }
  }

  void _showParticipantsModal(BuildContext context) async {
    List<String> participants = await DatabaseHelper.getEventParticipants(currentEvent.id);
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lista uczestników',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: participants.isEmpty
                    ? const Center(child: Text('Brak uczestników'))
                    : ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(participants[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _checkIfUserIsOwner() {
    if (userId != null) {
      setState(() {
        isUserOwner = currentEvent.userId == int.tryParse(userId!);
      });
    }
  }

  Future<void> _checkUserJoinedStatus() async {
    if (userId != null) {
      try {
        final isJoined = await DatabaseHelper.isUserJoinedEvent(
            currentEvent.id, userId!);

        setState(() {
          isUserJoined = isJoined;
        });
      } catch (e) {
        print('Błąd podczas sprawdzania statusu użytkownika: $e');
      }
    }
  }

  Future<void> _joinOrLeaveEvent() async {
    try {
      if (isUserJoined) {
        // Wypisanie z wydarzenia
        await DatabaseHelper.leaveEvent(currentEvent.id);
        setState(() {
          isUserJoined = false;
          currentEvent = currentEvent.copyWith(
            registeredParticipants: currentEvent.registeredParticipants - 1,
          );
        });
      } else {
        if (currentEvent.maxParticipants != -1 &&
            currentEvent.registeredParticipants >= currentEvent.maxParticipants) {
          // Jeśli liczba uczestników osiągnęła maksymalny limit
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wydarzenie jest już pełne!'),
            ),
          );
        } else {
          // Zapisanie na wydarzenie
          await DatabaseHelper.joinEvent(currentEvent.id);
          setState(() {
            isUserJoined = true;
            currentEvent = currentEvent.copyWith(
              registeredParticipants: currentEvent.registeredParticipants + 1,
            );
          });
        }
      }
    } catch (e) {
      print('Błąd podczas zapisywania/wypisywania użytkownika: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double photoHeight = 300;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                currentEvent.imagePath,
                height: photoHeight,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                height: photoHeight,
                decoration: BoxDecoration(
                  gradient: AppGradients.eventPageGradient,
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Text(
                  currentEvent.name,
                  textAlign: TextAlign.center,
                  style: HiveTextStyles.title,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${currentEvent.location}  |  ${currentEvent.type}\n${currentEvent.startDate.day}.${currentEvent.startDate.month}.${currentEvent.startDate.year}',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              currentEvent.cena > 0
                  ? 'Cena wejścia: ${currentEvent.cena} zł'
                  : 'Wejście darmowe',
              style: HiveTextStyles.regular,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              currentEvent.description,
              style: HiveTextStyles.regular,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              currentEvent.maxParticipants != -1
                  ? '${currentEvent.registeredParticipants} / ${currentEvent
                  .maxParticipants}'
                  : 'Wydarzenie otwarte, ${currentEvent.registeredParticipants} uczestników',
              style: HiveTextStyles.regular,
            ),
          ),

          // Wyświetl przycisk "Edytuj wydarzenie" tylko, jeśli użytkownik jest właścicielem wydarzenia
          if (isUserOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEventPage(
                        event: currentEvent,
                        onSave: (updatedEvent) {
                          setState(() {
                            currentEvent = updatedEvent;
                          });
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Edytuj wydarzenie'),
              ),
            ),
          // Wyświetl przycisk "Zapisz się / Wypisz się" tylko, jeśli użytkownik nie jest właścicielem wydarzenia
          if (!isUserOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  _joinOrLeaveEvent();
                },
                child: Text(isUserJoined ? 'Wypisz się' : 'Zapisz się'),
              ),
            ),
             Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => _showParticipantsModal(context),
              child: const Text('Zobacz uczestników'),
            ),
          ),
        ],
      ),
    );
  }
}
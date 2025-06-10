import 'package:flutter/material.dart';
import '../models/event.dart';
import '../styles/gradients.dart';
import '../pages/edit_event_page.dart';
import '../database/database_helper.dart';
import '../styles/text_styles.dart';
import '../styles/hive_colors.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/comment_section.dart';
import '../widgets/event_chat_widget.dart'; // Added for event chat
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import '../widgets/qr_display_dialog.dart';


/// Strona realizująca widok szczegółowy wydarzenia
class EventPage extends StatefulWidget {
  final Event event;
  final Function(Event) onUpdate;

  const EventPage({super.key, required this.event, required this.onUpdate});

  @override
  _EventPageState createState() => _EventPageState();
}




Widget _buildActionButton(String text, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    child: TextButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC300),
        disabledBackgroundColor:
            const Color(0xFFFFC300), // zachowaj żółty nawet jak disabled
        disabledForegroundColor: Colors.black.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _EventPageState extends State<EventPage> {
  late Event currentEvent; // aktualne wydarzenie
  bool isUserJoined = false; // Czy użytkownik jest zapisany na wydarzenie
  bool isUserOwner = false; // Czy użytkownik jest właścicielem wydarzenia?
  String? userId; // Przechowywanie userId
  int? _currentUserIdInt; // For chat widget
  double? organizerRating;
  bool ratingSent = false;
  Map<String, dynamic>? currentUser;



  @override
  void initState() {
    super.initState();
    currentEvent = widget.event;
    _fetchEvent();
    _initializeUser();
    _loadRating();
    _loadUserId();
    _fetchCurrentUser();
  }

  Future<void> _loadUserId() async {
    final id = await DatabaseHelper.getUserIdFromToken();
    setState(() {
      userId = id;
    });
  }

  Future<void> _fetchCurrentUser() async {
    final token = await DatabaseHelper.getToken(); // ⬅️ pobierz token z pamięci
    if (token == null) {
      print('Brak tokenu - użytkownik niezalogowany.');
      return;
    }
    try {
      final user = await DatabaseHelper.getUserByToken(token);
      setState(() {
        currentUser = user;
      });
    } catch (e) {
      print('Błąd pobierania użytkownika: $e');
    }
  }





  void _addToGoogleCalendar() {
    final calendarEvent = calendar.Event(
      title: currentEvent.name,
      description: currentEvent.description,
      location: currentEvent.location,
      startDate: currentEvent.startDate,
      endDate: currentEvent.startDate.add(const Duration(hours: 2)),
      allDay: false,
      iosParams: const calendar.IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const calendar.AndroidParams(emailInvites: []),
    );

    calendar.Add2Calendar.addEvent2Cal(calendarEvent);
  }

  String? _selectedReason;
  final List<String> _reportReasons = [
    'Nieodpowiednia treść',
    'Fałszywe wydarzenie',
    'Spam',
    'Inny powód'
  ];

  void _showReportDialog() async {
    String? selectedReason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding:
              MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16.0)),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Zgłoś wydarzenie',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Wybierz powód'),
                    items: _reportReasons.map((reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            try {
                              await DatabaseHelper.reportEvent(
                                  currentEvent.id, selectedReason!);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Zgłoszenie wysłane')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Błąd: ${e.toString()}')),
                              );
                            }
                          },
                    child: const Text('Wyślij zgłoszenie'),
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _isParticipantOwner(String participantId) {
    return participantId == currentEvent.userId.toString();
  }


  void _showRatingDialog() {
    showDialog(
        context: context,
        builder: (context) {
          int selectedRating = 3;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text('Oceń organizatora'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Jak oceniasz to wydarzenie?'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              selectedRating = index + 1;
                            });
                          },
                        );
                      }),
                    )
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await DatabaseHelper.rateOrganizer(
                          currentEvent.userId.toString(), selectedRating);
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dziękujemy za ocenę!')));
                      setState(() {
                        ratingSent = true;
                      });
                      _loadRating();
                    },
                    child: Text('Zatwierdź'),
                  )
                ],
              );
            },
          );
        });
  }

  Future<void> _initializeUser() async {
    try {
      userId = await DatabaseHelper.getUserIdFromToken();
      if (userId != null) {
        _currentUserIdInt = int.tryParse(userId!);
      }
      await _checkUserJoinedStatus();
      await _checkIfUserIsOwner();

      final hasRated =
          await DatabaseHelper.hasUserRated(currentEvent.userId.toString());
      if (mounted) {
        setState(() {
          ratingSent = hasRated;
        });
      }
    } catch (e) {
      print('Błąd podczas inicjalizacji użytkownika: $e');
    }
  }

  Future<void> _fetchEvent() async {
    try {
      final eventData = await DatabaseHelper.getEvent(widget.event.id);
      if (eventData != null) {
        if (!mounted) return;
        setState(() {
          currentEvent = Event.fromJson(eventData);
        });
      }
    } catch (e) {
      print('Błąd podczas pobierania wydarzenia: $e');
    }
  }

   void _showDiscountDialog(
      BuildContext context, double price, bool canUsePromo) async {
    if (!canUsePromo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie możesz użyć promocji na ten bilet.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Użyć promocji?'),
          content: const Text(
              'Masz aktywną promocję -10zł. Czy chcesz ją wykorzystać na ten bilet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Użyj'),
            ),
          ],
        );
      },
    );

     if (confirmed == true) {
      Navigator.pop(context); // zamknij poprzedni bottomsheet

      final paymentResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PaymentBottomSheet(
            price: price,
            hasDiscount: true,
            onDiscountTap: () =>
                _showDiscountDialog(context, price, canUsePromo),
            hasDiscountTickets: currentEvent.hasDiscountTickets,
            hasVipTickets: currentEvent.hasVipTickets,
            userId: userId!),
      );

      if (paymentResult != null && paymentResult['confirmed'] == true) {
        final ticketType = paymentResult['ticketType'] ?? 'standard';
        final finalPrice = paymentResult['finalPrice'] ?? price;
        
        await DatabaseHelper.joinEventWithTicketType(currentEvent.id, ticketType, finalPrice);
        if (!mounted) return;
        setState(() {
          isUserJoined = true;
          currentEvent = currentEvent.copyWith(
            registeredParticipants: currentEvent.registeredParticipants + 1,
          );
        });
      }
    }
  }

  void _showParticipantsModal(BuildContext context) async {
    List<String> participants =
        await DatabaseHelper.getEventParticipants(currentEvent.id);
    List<String> bannedUsers =
        await DatabaseHelper.getBannedUsers(currentEvent.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> refreshLists() async {
              final updatedParticipants =
                  await DatabaseHelper.getEventParticipants(currentEvent.id);
              final updatedBanned =
                  await DatabaseHelper.getBannedUsers(currentEvent.id);
              setModalState(() {
                participants = updatedParticipants;
                bannedUsers = updatedBanned;
              });
            }

            return Container(
              padding: const EdgeInsets.all(16),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Uczestnicy',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participantId = participants[index];
                        final isOwner = _isParticipantOwner(participantId);

                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(participantId),
                          trailing: isUserOwner && !isOwner && participantId != currentUser?['nickName']
                              ? IconButton(
                            icon: const Icon(Icons.block, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper.banUser(currentEvent.id, participants[index]);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Użytkownik został zbanowany')),
                              );
                              await refreshLists();
                            },
                          )
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Zbanowani użytkownicy',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: bannedUsers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading:
                              const Icon(Icons.person_off, color: Colors.red),
                          title: Text(bannedUsers[index]),
                          trailing: isUserOwner
                              ? IconButton(
                                  icon: const Icon(Icons.undo,
                                      color: Colors.green),
                                  onPressed: () async {
                                    await DatabaseHelper.unbanUser(
                                        currentEvent.id, bannedUsers[index]);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Użytkownik został odbanowany')),
                                    );
                                    await refreshLists();
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkIfUserIsOwner() async {
    if (userId != null) {
      if (!mounted) return;
      setState(() {
        isUserOwner = currentEvent.userId == int.tryParse(userId!);
      });
    }
  }

  Future<void> _checkUserJoinedStatus() async {
    if (userId != null) {
      try {
        final isJoined =
            await DatabaseHelper.isUserJoinedEvent(currentEvent.id, userId!);

        if (!mounted) return;
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
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Musisz być zalogowany, aby dołączyć do wydarzenia')),
        );
        return;
      }
      if (isUserJoined) {
        // Logika wypisywania
        await DatabaseHelper.leaveEvent(currentEvent.id);
        if (!mounted) return;
        setState(() {
          isUserJoined = false;
          currentEvent = currentEvent.copyWith(
            registeredParticipants: currentEvent.registeredParticipants - 1,
          );
        });
      } else {
        final isBanned = await DatabaseHelper.isUserBanned(currentEvent.id, userId!);
        if (isBanned) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Brak dostępu'),
              content: const Text(
                'Zostałeś zablokowany przez organizatora tego wydarzenia i nie możesz dołączyć.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
        // Sprawdź limit uczestników
        if (currentEvent.maxParticipants != -1 &&
            currentEvent.registeredParticipants >=
                currentEvent.maxParticipants) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wydarzenie jest już pełne!')),
          );
          return;
        }

        // Obsługa płatności dla wydarzeń płatnych
          if (currentEvent.cena > 0) {
          final hasPromo = await DatabaseHelper.hasPromotion(
              int.parse(userId!), 'promo_ticket');
          final canUsePromo = hasPromo && currentEvent.cena > 10;

          final paymentResult =
          await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => PaymentBottomSheet(
                price: currentEvent.cena,
                hasDiscount: false,
                onDiscountTap: () => _showDiscountDialog(
                    context, currentEvent.cena, canUsePromo),
                hasDiscountTickets: currentEvent.hasDiscountTickets,
                hasVipTickets: currentEvent.hasVipTickets,
                userId: userId!),
          );

          if (paymentResult == null || paymentResult['confirmed'] != true) return;

          // Pobieramy typ biletu i cenę z rezultatu
          final ticketType = paymentResult['ticketType'] ?? 'standard';
          final finalPrice = paymentResult['finalPrice'] ?? currentEvent.cena;

          // Zapisz użytkownika na wydarzenie z typem biletu
          await DatabaseHelper.joinEventWithTicketType(currentEvent.id, ticketType, finalPrice);
        } else {
          // Dla darmowych wydarzeń nadal standardowy bilet
          await DatabaseHelper.joinEvent(currentEvent.id);
        }

        if (!mounted) return;
        setState(() {
          isUserJoined = true;
          currentEvent = currentEvent.copyWith(
            registeredParticipants: currentEvent.registeredParticipants + 1,
          );
        });
      }
    } catch (e) {
      print('Błąd podczas zapisu/wypisu: $e');
    }
  }

  void _loadRating() async {
    try {
      final rating = await DatabaseHelper.getOrganizerRating(
          currentEvent.userId.toString());
      if (!mounted) return;
      setState(() {
        organizerRating = rating;
      });
    } catch (e) {
      print("Błąd ładowania oceny: $e");
    }
  }

  // Wyświetlenie okna z komentarzami
  void _showCommentsModal(BuildContext context) {
    // Używamy naszej funkcji pomocniczej z modułu comment_section.dart
    showCommentsModal(context, currentEvent.id);
  }

  @override
  Widget build(BuildContext context) {
    const double photoHeight = 300;

    return DefaultTabController( // Added DefaultTabController
      length: 2, // Number of tabs: Details and Chat
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, // Or your theme's app bar color
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(currentEvent.name, style: HiveTextStyles.title.copyWith(fontSize: 20)),
          bottom: const TabBar(
            indicatorColor: HiveColors.main,
            labelColor: HiveColors.main,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Szczegóły'),
              Tab(text: 'Czat'),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUserOwner) ...[
              FloatingActionButton(
                heroTag: 'qr',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => QrDisplayDialog(eventId: widget.event.id),
                  );
                },
                backgroundColor: HiveColors.main,
                child: const Icon(Icons.qr_code, color: Colors.black),
              ),
              const SizedBox(height: 16),
            ],
            FloatingActionButton(
              heroTag: 'chat',
              onPressed: () {
                _showCommentsModal(context);
              },
              backgroundColor: HiveColors.main,
              child: const Icon(Icons.chat, color: Colors.black),
            ),
          ],
        ),
        body: TabBarView( // Added TabBarView
          children: [
            // Details Tab
            SingleChildScrollView( // Made the details scrollable
              child: Column(
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
                      Positioned(
                        top: 16,
                        right: 16,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'report') {
                              _showReportDialog();
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'report',
                              child: ListTile(
                                leading:
                                    Icon(Icons.report_gmailerrorred, color: Colors.red),
                                title: Text('Zgłoś wydarzenie'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (organizerRating != null)
                        Positioned(
                          bottom: 0,
                          left: 16,
                          child: Text(
                            'Ocena organizatora: ⭐ ${organizerRating!.toStringAsFixed(1)} / 5',
                            style: const TextStyle(fontSize: 14, color: Colors.white),
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
                          ? '${currentEvent.registeredParticipants} / ${currentEvent.maxParticipants}'
                          : 'Wydarzenie otwarte, ${currentEvent.registeredParticipants} uczestników',
                      style: HiveTextStyles.regular,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.calendar_today,
                        color: Colors.black,
                      ),
                      label: const Text('Dodaj do Google Kalendarza',
                          style: TextStyle(color: Colors.black)),
                      onPressed: _addToGoogleCalendar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC300),
                        disabledBackgroundColor: const Color(0xFFFFC300),
                        // zachowaj żółty nawet jak disabled
                        disabledForegroundColor: Colors.black.withOpacity(0.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (currentEvent.startDate.isBefore(DateTime.now()) &&
                      isUserJoined &&
                      !isUserOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.star,
                          color: Colors.black.withOpacity(ratingSent ? 0.5 : 1.0),
                        ),
                        label: Text(
                          ratingSent ? 'Dziękujemy za ocenę!' : 'Oceń organizatora',
                          style: TextStyle(
                            color: Colors.black.withOpacity(ratingSent ? 0.5 : 1.0),
                          ),
                        ),
                        onPressed: ratingSent ? null : _showRatingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC300),
                          disabledBackgroundColor: const Color(0xFFFFC300),
                          // zachowaj żółty nawet jak disabled
                          disabledForegroundColor: Colors.black.withOpacity(0.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  if (!(currentEvent.startDate.isBefore(DateTime.now()) &&
                      isUserJoined &&
                      !isUserOwner))
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  // Wyświetl przycisk "Edytuj wydarzenie" tylko, jeśli użytkownik jest właścicielem wydarzenia
                  if (isUserOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionButton('Edytuj wydarzenie', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditEventPage(
                                  event: currentEvent,
                                  onSave: (updatedEvent) {
                                    if (!mounted) return;
                                    setState(() {
                                      currentEvent = updatedEvent;
                                    });
                                  },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          _buildActionButton(
                              currentEvent.isPromoted
                                  ? 'Usuń promocję'
                                  : 'Promuj wydarzenie', () async {
                            try {
                              final updated = currentEvent.copyWith(
                                  isPromoted: !currentEvent.isPromoted);
                              await DatabaseHelper.updateEvent(
                                currentEvent.id,
                                {
                                  'name': currentEvent.name,
                                  'location': currentEvent.location,
                                  'description': currentEvent.description,
                                  'type': currentEvent.type,
                                  'start_date':
                                      currentEvent.startDate.toIso8601String(),
                                  'max_participants': currentEvent.maxParticipants,
                                  'registered_participants':
                                      currentEvent.registeredParticipants,  
                                  'image': currentEvent.imagePath,
                                  'cena': currentEvent.cena,
                                  'is_promoted': updated.isPromoted,
                                   'has_discount_tickets': currentEvent.hasDiscountTickets ?? false,
                                  'has_vip_tickets': currentEvent.hasVipTickets ?? false,
                                },
                              );
                              if (!mounted) return;
                              setState(() {
                                currentEvent = updated;
                              });
                              widget.onUpdate(updated);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Błąd: $e')),
                              );
                            }
                          }),
                          const SizedBox(height: 12),
                          _buildActionButton('Zobacz uczestników', () {
                            _showParticipantsModal(context);
                          }),
                        ],
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC300),
                          disabledBackgroundColor: const Color(0xFFFFC300),
                          // zachowaj żółty nawet jak disabled
                          disabledForegroundColor: Colors.black.withOpacity(0.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isUserJoined ? 'Wypisz się' : 'Zapisz się',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Chat Tab
            _currentUserIdInt != null
              ? EventChatWidget(eventId: currentEvent.id.toString(), userId: _currentUserIdInt!)
              : Center(child: CircularProgressIndicator()), // Show loader while userId is fetched
          ],
        ),
      ),
    );
  }
}


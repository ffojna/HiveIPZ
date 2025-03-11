import 'package:Hive/widgets/event_type_grid.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../pages/filtered_page.dart';
import '../pages/new_event_page.dart';
import '../pages/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int MAX_RECENT_SEARCHES = 5;

/// Strona główna realizująca ideę rolek z wydarzeniami
class HomePage extends StatefulWidget {
  final List<Event> events;

  const HomePage({super.key, required this.events});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Event> events = [];
  int _selectedFromBottomBar = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _bottomCenaController = TextEditingController();
  final TextEditingController _upCenaController = TextEditingController();
  bool isSearching = false;

  // FIXME daje tutaj przykładowe, żeby zobaczyć jak działa, trzeba to wyrzucić
  List<String> recentSearches = ['pudzian', 'kremówki', 'mariusz'];

  @override
  void initState() {
    super.initState();
    _fetchAllEvents(); // Wywołanie funkcji pobierającej dane
    _loadRecentSearches(); //pobranie poprzednich wyszukiwań
  }

  // Pobieranie wydarzeń z bazy
  Future<void> _fetchAllEvents() async {
    try {
      final eventsData = await DatabaseHelper.getAllEvents();
      setState(() {
        events = eventsData.map((data) => Event.fromJson(data)).toList();
      });
    } catch (e) {
      print('Błąd podczas pobierania danych wydarzeń: $e');
    }
  }

  // pobierz poprzednie wyszukiwania (zapis do konta użytkownika np. 5 ostatnich?)
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recentSearches') ??
          ['pudzian', 'kremówki', 'mariusz'];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches.remove(query);
      recentSearches.insert(0, query);
      if (recentSearches.length > MAX_RECENT_SEARCHES) {
        recentSearches.removeLast();
      }
    });
    await prefs.setStringList('recentSearches', recentSearches);
  }

  /// Funkcja wyszukuje eventy ze słowem kluczowym w nazwie/lokalizacji i otweira filtered page ze znalezionymi wynikami
  /// args:
  ///   String query: hasło kluczowe do wyszukania
  void _filterEventsByQuery(String query) {
    query = query.trim(); // Usuń zbędne spacje
    print('Debug: Wartość query po trim = "$query"'); // Debugowanie

    if (query.isEmpty) {
      print('Debug: Pole wyszukiwania jest puste.'); // Debugowanie
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Pole wyszukania nie może być puste.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ],
          );
        },
      );
      return;
    }

    // Filtracja wydarzeń
    final filteredEvents = events
        .where((event) =>
            event.name.toLowerCase().contains(query.toLowerCase()) ||
            event.location.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (filteredEvents.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Nie znaleziono żadnych wydarzeń.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredPage(
          filteredEvents: filteredEvents,
          onUpdate: (updatedEvent) {
            setState(() {
              final index =
                  events.indexWhere((event) => event.id == updatedEvent.id);
              if (index != -1) {
                events[index] = updatedEvent;
              }
            });
          },
        ),
      ),
    );
  }

  void _filterEventsByType(String typeFilter, String query) {
    final filteredEvents = events
        .where((event) =>
            event.type.toLowerCase().contains(typeFilter.toLowerCase()))
        .toList();

    if (filteredEvents.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Nie znaleziono żadnych wydarzeń.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredPage(
          filteredEvents: filteredEvents,
          onUpdate: (updatedEvent) {
            setState(() {
              final index =
                  events.indexWhere((event) => event.id == updatedEvent.id);
              if (index != -1) {
                events[index] = updatedEvent;
              }
            });
          },
        ),
      ),
    );
  }

  void _filterEventsByPrice(double priceBottom, double priceUp) {
    final filteredEvents = events
        .where((event) => event.cena <= priceUp && event.cena >= priceBottom)
        .toList();

    if (filteredEvents.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Nie znaleziono żadnych wydarzeń.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredPage(
          filteredEvents: filteredEvents,
          onUpdate: (updatedEvent) {
            setState(() {
              final index =
                  events.indexWhere((event) => event.id == updatedEvent.id);
              if (index != -1) {
                events[index] = updatedEvent;
              }
            });
          },
        ),
      ),
    );
  }

  void _filterEventsByDate(DateTime dateBottom, DateTime dateUp) {
    final filteredEvents = events
        .where((event) =>
            event.startDate.year >= dateBottom.year &&
            event.startDate.month >= dateBottom.month &&
            event.startDate.day >= dateBottom.day &&
            event.startDate.year <= dateUp.year &&
            event.startDate.month <= dateUp.month &&
            event.startDate.day <= dateUp.day)
        .toList();

    if (filteredEvents.isEmpty) {
      print('Debug: Brak wyników wyszukiwania dla '); // Debugowanie
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              'Nie znaleziono żadnych wydarzeń.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.cancel, color: Colors.red),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredPage(
          filteredEvents: filteredEvents,
          onUpdate: (updatedEvent) {
            setState(() {
              final index =
                  events.indexWhere((event) => event.id == updatedEvent.id);
              if (index != -1) {
                events[index] = updatedEvent;
              }
            });
          },
        ),
      ),
    );
  }

  void _showCenaDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: const Text('Podaj przedział cenowy'),
              content: Column(
                children: [
                  TextField(
                    controller: _bottomCenaController,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(hintText: 'Podaj dolną granicę'),
                  ),
                  TextField(
                    controller: _upCenaController,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(hintText: 'Podaj górną granicę'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _searchController.clear();
                    },
                    child: const Icon(Icons.cancel)),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    double bottom = _bottomCenaController.text == ""
                        ? 0.0
                        : double.parse(_bottomCenaController.text);
                    double up = _upCenaController.text == ""
                        ? double.infinity
                        : double.parse(_upCenaController.text);
                    if (double.parse(_upCenaController.text) <
                        double.parse(_bottomCenaController.text)) {
                      bottom = double.parse(_upCenaController.text);
                      up = double.parse(_bottomCenaController.text);
                    }
                    _filterEventsByPrice(bottom, up);
                    _bottomCenaController.clear();
                    _upCenaController.clear(); // Wyczyść pole
                  },
                  child: const Icon(Icons.search),
                ),
              ]);
        });
  }

  void _showDateRangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? dateBottom;
        DateTime? dateUp;

        return AlertDialog(
          title: const Text('Wybierz przedział dat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    dateBottom = pickedDate;
                  }
                },
                child: const Text('Wybierz datę początkową'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: dateBottom ?? DateTime.now(),
                    firstDate: dateBottom ?? DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    dateUp = pickedDate;
                  }
                },
                child: const Text('Wybierz datę końcową'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () {
                if (dateBottom != null && dateUp != null) {
                  Navigator.of(context).pop();
                  _filterEventsByDate(dateBottom!, dateUp!);
                }
              },
              child: const Text('Filtruj'),
            ),
          ],
        );
      },
    );
  }

  /// Otwieranie okna dialogowego z wyszukiwaniem
  void _showSearchDialog({bool onlyLocation = false}) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Wyszukiwanie wydarzeń'),
            content: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: onlyLocation
                    ? 'Wprowadź lokalizację'
                    : 'Wprowadź nazwę lub lokalizację',
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _searchController.clear();
                  },
                  child: const Icon(Icons.cancel)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  print(
                      'Debug: Wartość w polu wyszukiwania: ${_searchController.text}'); // Debugowanie
                  _filterEventsByQuery(_searchController.text);
                  _searchController.clear(); // Wyczyść pole
                },
                child: const Icon(Icons.search),
              ),
            ],
          );
        });
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) _searchController.clear();
    });
  }

  void _onSearch(String query) {
    _saveSearchQuery(query);
    _filterEventsByQuery(query);
    setState(() {
      isSearching = false;
    });
  }

  /// Obsługa NavigationBara na dole ekranu
  /// args:
  ///   int index: wybrany przycisk
  void _onBarTapped(int index) {
    setState(() {
      _selectedFromBottomBar = index;
      switch (_selectedFromBottomBar) {
        case 0:
          _toggleSearch();
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(onEventCreated: (newEvent) {
                setState(() {
                  events.add(newEvent);
                  // _filteredEvents = widget.events;
                });
              }),
            ),
          );
          break;
        case 2:
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'Filtruj po:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ListTile(
                    title: const Text('Typ wydarzenia'),
                    onTap: () async {
                      Navigator.pop(context);
                      showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return EventTypeGrid(
                                onEventTypeSelected: (String typeFilter) {
                              _filterEventsByType(typeFilter, "");
                            });
                          });
                    }),
                ListTile(
                  title: const Text('Data'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDateRangeDialog();
                  },
                ),
                ListTile(
                    title: const Text('Lokalizacja'),
                    onTap: () async {
                      Navigator.pop(context);
                      _showSearchDialog(onlyLocation: true);
                    }),
                ListTile(
                    title: const Text('Cena'),
                    onTap: () async {
                      Navigator.pop(context);
                      _showCenaDialog();
                    })
              ]);
            },
          );
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(),
            ),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Szukaj...",
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                      onPressed: _toggleSearch, icon: Icon(Icons.clear)),
                ),
                onSubmitted: _onSearch,
              )
            : const Text('Strona Główna'),
        actions: [
          if (!isSearching)
            IconButton(
              onPressed: _toggleSearch,
              icon: Icon(Icons.search),
            )
        ],
      ),
      body: events.isEmpty
          ? const Center(
              child:
                  CircularProgressIndicator(), // Wyświetlanie ładowania, jeśli lista jest pusta
            )
          : RefreshIndicator(
              onRefresh: _fetchAllEvents, // Funkcja do odświeżania
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: events.length, // Liczba wydarzeń
                itemBuilder: (context, index) {
                  final event =
                      events[index]; // Pobranie konkretnego wydarzenia
                  return EventCard(
                    event: event,
                    onUpdate: (updatedEvent) {
                      setState(() {
                        events[index] = updatedEvent; // Aktualizacja wydarzenia
                      });
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        enableFeedback: false,
        backgroundColor: Colors.black54,
        currentIndex: _selectedFromBottomBar,
        onTap: _onBarTapped,
        showUnselectedLabels: false,
        showSelectedLabels: false,
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'dołącz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_alt_outlined),
            label: 'filtruj',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'profil',
          ),
        ],
      ),
    );
  }
}

import 'package:Hive/styles/hive_colors.dart';
import 'package:Hive/widgets/event_type_grid.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/event.dart';
import '../services/event_sorter_service.dart';
import '../widgets/event_card.dart';
import '../pages/filtered_page.dart';
import '../pages/new_event_page.dart';
import '../pages/profile_page.dart';
import '../pages/points_page.dart';
import '../services/event_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/sorting_modal_bottom_sheet.dart';

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
  bool isSearching = false;
  int selectedSortingType = 0;
  bool sortingAscending = false;
  double searchBarWidth = 56;
  PageController _pageController = PageController();
  int _currentPage = 0;
  Map<String, String?> userRatings = {}; // eventId -> 'like' lub 'dislike'
  final FocusNode _searchFocusNode = FocusNode();

  // FIXME daje tutaj przykładowe, żeby zobaczyć jak działa, trzeba to wyrzucić
  List<String> recentSearches = ['pudzian', 'kremówki', 'mariusz'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom]);
    isSearching = false;
    _fetchAllEvents(); // Wywołanie funkcji pobierającej dane
    _loadRecentSearches(); //pobranie poprzednich wyszukiwań
    _pageController = PageController();
  }

  void _rateEvent(String eventId, bool isLike) async {
    final token = await DatabaseHelper.getToken();
    if (token == null) {
      print('Brak tokenu – użytkownik nie jest zalogowany.');
      return;
    }

    final url =
        Uri.parse('https://vps.jakosinski.pl:5000/events/$eventId/rate');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'type': isLike ? 'like' : 'dislike'}),
      );

      if (response.statusCode == 200) {
        print('Ocena zapisana');
        _fetchUserRating(eventId); // <-- odśwież kolory ikonek
      } else {
        print('Błąd oceny: ${response.body}');
      }
    } catch (e) {
      print('Błąd sieci: $e');
    }
  }

  Future<void> _fetchUserRating(String eventId) async {
    final token = await DatabaseHelper.getToken();
    if (token == null) {
      print('Brak tokenu – użytkownik nie jest zalogowany.');
      return;
    }

    final url = Uri.parse(
        'https://vps.jakosinski.pl:5000/events/$eventId/rating_status');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userRatings[eventId] =
              data['rating']; // 'like' lub 'dislike' lub null
        });
      }
    } catch (e) {
      print('Błąd pobierania oceny: $e');
    }
  }

  // Pobieranie wydarzeń z bazy
  Future<void> _fetchAllEvents() async {
    try {
      final eventsData = await DatabaseHelper.getAllEvents();
      setState(() {
        events = eventsData.map((data) => Event.fromJson(data)).toList();
        events.sort((a, b) {
          if (a.isPromoted && !b.isPromoted) return -1;
          if (!a.isPromoted && b.isPromoted) return 1;
          return 0;
        });
      });
    } catch (e) {
      print('Błąd podczas pobierania danych wydarzeń: $e');
    }
  }

  // pobierz poprzednie wyszukiwania (zapis do konta użytkownika np. 5 ostatnich?)
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches =
          prefs.getStringList('recentSearches') ?? ['zut', 'pudzian', 'rabbit'];
    });
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      searchBarWidth =
          isSearching ? MediaQuery.of(context).size.width - 32 : 56;
      if (isSearching) {
        Future.delayed(Duration(milliseconds: 300), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchFocusNode.unfocus(); //
        _searchController.clear();
      }
    });
  }

  void _onSearch(String query) async {
    EventFilterService.filterEventsByQuery(context, events, query);

    // Dodaj do recentSearches jeśli nie ma
    if (!recentSearches.contains(query)) {
      setState(() {
        recentSearches.insert(0, query);
        if (recentSearches.length > 5) recentSearches.removeLast();
      });
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('recentSearches', recentSearches);
    }

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
          // Przejdź do strony głównej
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(events: []),
            ),
          );
          break;
        case 1:
          // Punkty
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PointsPage(),
            ),
          );
          break;
        case 2:
          // Dodawanie wydarzenia
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(onEventCreated: (newEvent) {
                setState(() {
                  events.add(newEvent);
                });
              }),
            ),
          );
          break;
        case 3:
          // Filtrowanie
          EventFilterService.showFilterModalBottomSheet(
              context: context, events: events);
          break;
        case 4:
          // Profil użytkownika
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
      body: Stack(
        children: [
          // Główna zawartość strony
          events.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchAllEvents,
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: events.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _fetchUserRating(events[index].id);
                    },
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return EventCard(
                        event: event,
                        onUpdate: (updatedEvent) {
                          setState(() {
                            events[index] = updatedEvent;
                          });
                        },
                      );
                    },
                  ),
                ),

          AnimatedOpacity(
              opacity: isSearching ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                  ignoring: !isSearching,
                  child: GestureDetector(
                      onTap: _toggleSearch,
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        width: double.infinity,
                        height: double.infinity,
                      )))),

          Positioned(
            top: 50,
            right: 16,
            left: isSearching ? 16 : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCirc,
              width: searchBarWidth,
              height: 56,
              decoration: BoxDecoration(
                color: isSearching ? HiveColors.weakAccent : HiveColors.main,
                borderRadius: BorderRadius.circular(isSearching ? 30 : 28),
              ),
              child: isSearching
                  ? Row(
                      children: [
                        Expanded(
                            child: RawAutocomplete<String>(
                          textEditingController: _searchController,
                          focusNode: FocusNode(),
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.9,
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(30),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(option),
                                            leading: Icon(Icons.history),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ));
                          },
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return recentSearches.where((search) => search
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (String selection) {
                            _searchController.text = selection;
                            _onSearch(selection);
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: "Szukaj...",
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onSubmitted: (query) {
                                _onSearch(query);
                                _toggleSearch();
                              },
                            );
                          },
                        )),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.black),
                          onPressed: _toggleSearch,
                        ),
                      ],
                    )
                  : IconButton(
                      icon: Icon(Icons.search, color: Colors.black),
                      onPressed: _toggleSearch,
                    ),
            ),
          ),

          Positioned(
              top: MediaQuery.of(context).size.height - 305,
              left: MediaQuery.of(context).size.width - 80,
              child: Row(
                children: [
                  Container(
                    width: 85,
                    child: Column(
                      verticalDirection: VerticalDirection.up,
                      children: [
                        ListTile(
                          leading: Icon(Icons.import_export,
                              size: 35, color: Colors.white),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => SortingModalBottomSheet(
                                events: events,
                                selectedSortingType: selectedSortingType,
                                sortingAscending: sortingAscending,
                                onSortingChanged: (type, asc) {
                                  setState(() {
                                    selectedSortingType = type;
                                    sortingAscending = asc;
                                  });
                                },
                                refresh: () => setState(
                                    () {}), // lub _fetchAllEvents, jeśli potrzebujesz odświeżenia z bazy
                              ),
                            );
                          },
                        ),
                        if (events.isNotEmpty)
                          ListTile(
                            leading: Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 35,
                              color: userRatings[events[_currentPage].id] ==
                                      'dislike'
                                  ? Colors.red
                                  : Colors.white,
                            ),
                            onTap: () =>
                                _rateEvent(events[_currentPage].id, false),
                          ),
                        if (events.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 17, 0),
                            child: Text(
                              events[_currentPage].userScore.toString(),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                              fontSize: 16),
                            ),
                          ),
                        if (events.isNotEmpty)
                          ListTile(
                            leading: Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 35,
                              color:
                                  userRatings[events[_currentPage].id] == 'like'
                                      ? Colors.green
                                      : Colors.white,
                            ),
                            onTap: () =>
                                _rateEvent(events[_currentPage].id, true),
                          ),
                      ],
                    ),
                  )
                ],
              ))
        ],
      ),
      bottomNavigationBar: !isSearching
          ? BottomAppBar(
              height: 80,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => _onBarTapped(0), // Strona główna
                    icon: Icon(Icons.home, color: Colors.black),
                  ),
                  IconButton(
                    onPressed: () => _onBarTapped(1), // Grywalizacja TODO
                    icon: Icon(Icons.hive, color: Colors.black),
                  ),
                  FloatingActionButton(
                    onPressed: () => _onBarTapped(2),
                    // Dodawanie wydarzenia
                    backgroundColor: Colors.amber,
                    elevation: 10.0,
                    // Wysokość unoszeinie się przycisku - tworzenie cienia
                    child: Icon(
                      Icons.add,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _onBarTapped(3), // Filtry
                    icon: Icon(Icons.filter_alt_outlined, color: Colors.black),
                  ),
                  IconButton(
                    onPressed: () => _onBarTapped(4), // Profil użytkownika
                    icon: Icon(Icons.person, color: Colors.black),
                  )
                ],
              ),
            )
          : null,
    );
  }
}

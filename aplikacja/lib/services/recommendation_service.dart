import '../database/database_helper.dart';
import '../models/event.dart';

class RecommendationService {
  /// Funkcja pobierająca listę wydarzeń, do których dołączył użytkownik sesji
  static Future<List<Event>> fetchJoinedEvents(String userId) async {
    try {
      final joinedRaw = await DatabaseHelper.getUserEvents(int.parse(userId));
      return joinedRaw.map((data) => Event.fromJson(data)).toList();
    } catch (e) {
      print('Błąd przy pobieraniu joinedEvents: $e');
      return [];
    }
  }

  static double calculateScore(Event event, List<String> preferredTypes,
      List<String> recentSearches, List<Event> joinedEvents) {
    double score = 0.0;

    // +1 jeżeli wydarzenie jest w preferowanym typie
    if (preferredTypes.contains(event.type)) {
      score += 1.0;
    }

    // +0.5, jeżeli użytkownk wyszukiwał podobne
    for (final keyword in recentSearches) {
      final lowerKeyword = keyword.toLowerCase();
      if (event.name.toLowerCase().contains(lowerKeyword) ||
          event.description.toLowerCase().contains(lowerKeyword)) {
        score += 0.5;
      }
    }

    // +1 jeżeli promowane
    if (event.isPromoted) {
      score += 1.0;
    }

    // +stosunek zapisanych do maksymalnych, jeżeli popularne (do przemyślenia)
    if (event.maxParticipants > 0) {
      score += (event.registeredParticipants / event.maxParticipants) * 2;
    }

    // + jeżeli podobne do innych dołączonych
    for (final joinedEvent in joinedEvents) {
      // sprawdzamy czy tytuły zawierają podobne
      for (final titleKeyword in joinedEvent.name.split(" ")) {
        if (titleKeyword.length < 4) continue;
        final lowerKeyword = titleKeyword.toLowerCase();
        if (event.name.toLowerCase().contains(lowerKeyword) ||
            event.description.toLowerCase().contains(lowerKeyword) ||
            event.location.toLowerCase().contains(lowerKeyword)) {
          score += 0.5;
        }
      }

      // sprawdzamy lokalizajce (mam gdzieś opis, to będzie za dużo)
      for (final locationKeyword in joinedEvent.description.split(" ")) {
        if (locationKeyword.length < 4) continue;
        final lowerKeyword = locationKeyword.toLowerCase();
        if (event.name.toLowerCase().contains(lowerKeyword) ||
            event.description.toLowerCase().contains(lowerKeyword) ||
            event.location.toLowerCase().contains(lowerKeyword)) {
          score += 0.5;
        }
      }
    }

    // +stosunek like do dislike
    // FIXME DAJ TUTAJ PRAWIDŁOWE NAZWY ZMIMENNYCH; być może będziesz musiał parsować na double obie
    score += event.userScore;

    return score;
  }

  static Future<List<Event>> attachScores(List<Event> events,
      List<String> preferredTypes, List<String> recentSearches) async {
    final userId = await DatabaseHelper.getUserIdFromToken();
    final joinedEvents = await RecommendationService.fetchJoinedEvents(userId);
    return events.map((e) {
      return e.copyWith(
        recommendationScore:
            calculateScore(e, preferredTypes, recentSearches, joinedEvents),
      );
    }).toList();
  }
}

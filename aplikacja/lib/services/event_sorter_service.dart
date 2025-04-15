import 'package:flutter/material.dart';
import '../models/event.dart';

class EventSorterService {
  static void sortByPrice(List<Event> events, bool ascending) {
    events.sort((a, b) =>
        ascending ? a.cena.compareTo(b.cena) : b.cena.compareTo(a.cena));
  }

  static void sortByParticipants(List<Event> events, bool ascending) {
    events.sort((a, b) => ascending
        ? a.registeredParticipants.compareTo(b.registeredParticipants)
        : b.registeredParticipants.compareTo(a.registeredParticipants));
  }

  static void sortByDate(List<Event> events, bool ascending) {
    events.sort((a, b) => ascending
        ? a.startDate.compareTo(b.startDate)
        : b.startDate.compareTo(a.startDate));
  }

  static void sortByRecommendations(List<Event> events) {
    events
        .sort((a, b) => a.recommendationScore.compareTo(b.recommendationScore));
  }
}

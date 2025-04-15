import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_sorter_service.dart';

class SortingModalBottomSheet extends StatefulWidget {
  final List<Event> events;
  final int selectedSortingType;
  final bool sortingAscending;
  final void Function(int, bool) onSortingChanged;
  final void Function() refresh;

  const SortingModalBottomSheet({
    super.key,
    required this.events,
    required this.selectedSortingType,
    required this.sortingAscending,
    required this.onSortingChanged,
    required this.refresh,
  });

  @override
  State<SortingModalBottomSheet> createState() =>
      _SortingModalBottomSheetState();
}

class _SortingModalBottomSheetState extends State<SortingModalBottomSheet> {
  late int selectedType;
  late bool ascending;

  @override
  void initState() {
    super.initState();
    selectedType = widget.selectedSortingType;
    ascending = widget.sortingAscending;
  }

  void _applySorting(int type) {
    setState(() {
      if (selectedType == type) {
        ascending = !ascending;
      } else {
        ascending = false;
        selectedType = type;
      }
    });

    widget.onSortingChanged(selectedType, ascending);

    switch (selectedType) {
      case 0:
        EventSorterService.sortByRecommendations(widget.events);
        break;
      case 1:
        EventSorterService.sortByPrice(widget.events, ascending);
        break;
      case 2:
        EventSorterService.sortByParticipants(widget.events, ascending);
        break;
      case 3:
        EventSorterService.sortByDate(widget.events, ascending);
        break;
    }

    widget.refresh();
  }

  Widget _buildTile(String label, int type) {
    return ListTile(
      title: Text(label),
      tileColor: selectedType == type ? Colors.amber.withOpacity(0.3) : null,
      trailing: selectedType == 0
          ? null
          : selectedType == type
              ? Icon(ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
              : null,
      onTap: () => _applySorting(type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Sortuj według:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildTile('Proponowane', 0),
            _buildTile('Cena', 1),
            _buildTile('Zapisani uczestnicy', 2),
            _buildTile('Data', 3),
          ],
        ),
      ),
    );
  }
}

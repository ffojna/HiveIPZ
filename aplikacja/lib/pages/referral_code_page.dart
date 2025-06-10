import 'package:flutter/material.dart';
import '../database/database_helper.dart'; // Adjust path if necessary
import 'package:flutter/services.dart'; // For Clipboard
import 'dart:math'; // For generating a random referral code

class ReferralCodePage extends StatefulWidget {
  final int userId;

  const ReferralCodePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ReferralCodePageState createState() => _ReferralCodePageState();
}

class _ReferralCodePageState extends State<ReferralCodePage> {
  String? _referralCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReferralCode(); // Wywołaj pobieranie kodu przy inicjalizacji
  }

  // Funkcja do pobierania istniejącego kodu referencyjnego użytkownika z bazy danych
  Future<void> _fetchReferralCode() async {
    try {
      _referralCode = await DatabaseHelper.fetchUserReferralCode(widget.userId);
      setState(() {
        _isLoading = false; // Zakończ ładowanie po pobraniu kodu
      });
    } catch (e) {
      print('Error fetching referral code: $e');
      setState(() {
        _isLoading = false;
        _referralCode = null; // Wskazuje na błąd lub brak kodu
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Błąd podczas ładowania kodu referencyjnego.')),
      );
    }
  }

  // Funkcja do generowania i zapisywania nowego kodu referencyjnego
  Future<void> _generateReferralCode() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Generowanie unikalnego kodu referencyjnego
      String newCode = _generateUniqueReferralCode();

      // Wywołanie funkcji z DatabaseHelper do zapisania kodu w bazie danych
      await DatabaseHelper.updateUserReferralCode(widget.userId, newCode);

      setState(() {
        _referralCode = newCode;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Nowy kod referencyjny został wygenerowany i zapisany!')),
      );
    } catch (e) {
      print('Error generating or saving referral code: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Błąd podczas generowania lub zapisywania kodu referencyjnego: ${e.toString()}')),
      );
    }
  }

  // Funkcja pomocnicza do generowania unikalnego kodu
  String _generateUniqueReferralCode() {
    var random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Funkcja do kopiowania kodu referencyjnego do schowka
  void _copyReferralCode() {
    if (_referralCode != null) {
      Clipboard.setData(ClipboardData(text: _referralCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod referencyjny skopiowany!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kod referencyjny'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator()) // Pokaż wskaźnik ładowania
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Twój kod referencyjny:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_referralCode != null) // Jeśli kod istnieje, wyświetl go
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _referralCode!,
                      style: const TextStyle(
                          fontSize: 24, color: Colors.blue),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _copyReferralCode,
                    tooltip: 'Kopiuj kod',
                  ),
                ],
              )
            else // Jeśli kodu nie ma, wyświetl informację i przycisk do generowania
              const Text(
                'Brak kodu referencyjnego. Wygeneruj nowy.',
                style:
                TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateReferralCode,
              child: Text(_referralCode != null
                  ? 'Generuj nowy kod' // Tekst przycisku zmienia się w zależności od stanu kodu
                  : 'Wygeneruj kod'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Użyj tego kodu podczas rejestracji, aby otrzymać punkty!',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  // 'http://212.127.78.92:5000';
  static const String link = 'https://vps.jakosinski.pl:5000';

  static Future<void> addUser(
    String name,
    String surname,
    int age,
    String nickName,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$link/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'surname': surname,
        'age': age,
        'nickName': nickName,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      print('Użytkownik zarejestrowany pomyślnie');
    } else {
      final error = jsonDecode(response.body)['error'];
      throw Exception(error);
    }
  }

  //TODO: zablkować @ dla rejestracji nickName
  static Future<Map<String, dynamic>?> getUser(
      String nickName, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$link/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nickName': nickName, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Zwracamy CAŁY obiekt odpowiedzi
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Nieznany błąd');
      }
    } catch (e) {
      throw Exception('Błąd połączenia: $e');
    }
  }

  // Update User by Patryk
  static Future<void> updateUser(
      String userId, Map<String, String> updatedFields) async {
    final url = Uri.parse('$link/update_user/$userId');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updatedFields), // Dane do aktualizacji
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['message'] ??
          'Błąd podczas aktualizacji danych użytkownika';
      throw Exception(error);
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final url = Uri.parse('$link/google_login');
    final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      print('Zalogowano przez Google jako: ${data['user']['nickName']}');
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Logowanie Google nie powiodło się: $error');
    }
  }

  static Future<void> loginWithFacebook(String email, String name) async {
    final url = Uri.parse('$link/facebook_login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data; // Zwraca user + token
    } else {
      final error = jsonDecode(response.body)['message'] ?? 'Nieznany błąd';
      throw Exception(error);
    }
  }
  static Future<void> verifyToken(String token) async {
    final url = Uri.parse(
        '$link/verify_token'); // Zakładając, że endpoint to '/verify_token'
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    // FIXME: zmieniłem to, żeby było ładniejsze, ale niech ktoś kto to bardziej ogarnia te kody sprawdzi czy to śmiga
    if (response.statusCode != 200) {
      // Token jest nieważny
      throw Exception('Token jest nieważny');
    }
  }

  // Ściąganie hasła
  static Future<String?> fetchPassword(int userId, String token) async {
    final url = Uri.parse('$link/get_password/$userId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['password'];
    } else {
      print('Error: ${response.body}');
      return null;
    }
  }

  // Zmiana hasła po starym haśle
  static Future<void> changePasswordWithOld(
      String oldPassword, String newPassword) async {
    final url = Uri.parse('$link/change_password_with_old');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': oldPassword, 'new_password': newPassword}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
      throw Exception('Błąd podczas zmiany hasła: $error');
    }
  }

  // Dodawanie wydarzeń
  static Future<void> addEvent(Map<String, dynamic> eventData) async {
    final url = Uri.parse('$link/events');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(eventData),
    );
    if (response.statusCode == 201) {
      print('Wydarzenie dodane pomyślnie');
    } else {
      throw Exception(jsonDecode(response.body)['error']);
    }
  }

  // Aktualizowanie wydarzeń
  static Future<void> updateEvent(
      String id, Map<String, dynamic> eventData) async {
    final url = Uri.parse('$link/events/$id');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(eventData),
    );

    if (response.statusCode != 200) {
      print('Błąd: ${response.statusCode}, Treść odpowiedzi: ${response.body}');
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception(error);
    }
  }

  // Usuwanie wydarzeń
  static Future<void> deleteEvent(String id) async {
    final url = Uri.parse('$link/events/$id');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      throw Exception(error);
    }
  }

  // Pobieranie wydarzenia
  static Future<Map<String, dynamic>?> getEvent(String id) async {
    final url = Uri.parse('$link/events/$id');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : null;
    } else {
      final error = jsonDecode(response.body)['message'];
      throw Exception(error);
    }
  }

  static Future<bool> hasUserRated(String organizerId) async {
    final token = await getToken();
    final url = Uri.parse('$link/has_rated/$organizerId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['hasRated'] == true;
    } else {
      throw Exception('Nie udało się sprawdzić czy użytkownik ocenił');
    }
  }


  //Pobieranie wszystkich wydarzeń
  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    var url = Uri.parse('$link/events');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Błąd parsowania odpowiedzi JSON: $e');
        throw Exception('Błąd parsowania danych wydarzeń');
      }
    } else {
      try {
        final error = jsonDecode(response.body)['error'];
        throw Exception('Błąd serwera: $error');
      } catch (e) {
        throw Exception('Błąd serwera: nieoczekiwany format odpowiedzi');
      }
    }
  }

  static Future<void> deleteAccount(String token) async {
    final url = Uri.parse('$link/delete_account');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'];
      throw Exception(error);
    }
  }

  static Future<bool> verifyPassword(String token, String password) async {
    final url = Uri.parse('$link/verify_password');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'password': password}),
    );

    if (response.statusCode == 200) {
      return true; // Hasło jest poprawne
    } else if (response.statusCode == 401) {
      return false; // Nieprawidłowe hasło
    } else {
      throw Exception('Błąd serwera: ${response.statusCode}');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
        'token'); // Zakładam, że token jest przechowywany pod kluczem 'token'
  }

  static Future<void> joinEvent(String eventId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/join');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd przy zapisie na wydarzenie: $error');
    }
  }

  static Future<void> leaveEvent(String eventId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/leave');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print('Opuszczono wydarzenie');
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd przy wypisie z wydarzenia: $error');
    }
  }

  static Future<String> getUserIdFromToken() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/verify_token');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final userId = data['user_id'];
      if (userId == null) {
        throw Exception('Brak user_id w odpowiedzi serwera.');
      }
      return userId.toString(); // Upewnij się, że zawsze zwracany jest String
    } else {
      throw Exception('Błąd przy pobieraniu userId z tokenu.');
    }
  }

  // Sprawdzanie czy user już się zapisał na wydazenie
  static Future<bool> isUserJoinedEvent(String eventId, String userId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji.');
    }

    final url = Uri.parse('$link/events/$eventId/check');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['is_joined']
          as bool; // Oczekujemy odpowiedzi serwera z kluczem 'is_joined'
    } else {
      throw Exception('Błąd przy sprawdzaniu statusu użytkownika.');
    }
  }

  // Sprawdzamy czy user jest adminem wydarzenia
  static Future<bool> isAdmin(String eventId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji.');
    }

    final url = Uri.parse('$link/events/$eventId/is_admin');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['is_admin']
          as bool; // Oczekujemy odpowiedzi serwera z kluczem 'is_admin'
    } else {
      throw Exception('Błąd przy sprawdzaniu uprawnień administratora.');
    }
  }

  // Czesć patrykowa id usera po tokenie
  static Future<Map<String, dynamic>?> getUserByToken(String token) async {
    final url = Uri.parse('$link/get_user_by_token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user'];
    } else {
      final error = jsonDecode(response.body)['message'];
      throw Exception(error);
    }
  }

  static Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception("Brak tokena, użytkownik już jest wylogowany.");
    }

    final url = Uri.parse('$link/logout');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      await prefs.remove('token'); // Usuń token z pamięci lokalnej
    } else {
      final error =
          jsonDecode(response.body)['message'] ?? 'Błąd podczas wylogowywania';
      throw Exception(error);
    }
  }

  static Future<List<String>> getEventParticipants(String eventId) async {
    final url = Uri.parse('$link/events/$eventId/participants');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => e['nickName'] as String).toList();
    } else {
      throw Exception('Nie udało się pobrać listy uczestników');
    }
  }

  static Future<bool> getUserPreferences(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$link/get_user_preferences?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hasSetPreferences = (data['hasSetPreferences'] == 1);
        return hasSetPreferences;
      } else {
        throw Exception("Błąd API: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Błąd pobierania preferencji użytkownika: $e");
      return false;
    }
  }

  static Future<void> setUserPreferences(String userId) async {
    final response = await http.post(
      Uri.parse('$link/set_user_preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Błąd zapisu preferencji użytkownika');
    }
  }

  static Future<List<String>> getUserEventPreferences(String userId) async {
    final response = await http
        .get(Uri.parse('$link/user_event_preferences?user_id=$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['preferences']);
    } else {
      throw Exception('Błąd pobierania preferencji użytkownika');
    }
  }

  // Pobieranie wydarzeń dla użytkownika
  static Future<List<Map<String, dynamic>>> getUserEvents(int userId) async {
    var url = Uri.parse('$link/events/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Błąd parsowania odpowiedzi JSON: $e');
        throw Exception('Błąd parsowania danych wydarzeń');
      }
    } else {
      try {
        final error = jsonDecode(response.body)['error'];
        throw Exception('Błąd serwera: $error');
      } catch (e) {
        throw Exception('Błąd serwera: nieoczekiwany format odpowiedzi');
      }
    }
  }

  static Future<void> banUser(String eventId, String nickName) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji.');
    }

    final url = Uri.parse('$link/events/$eventId/ban');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nickName': nickName}),  // <-- Wysyłamy nick zamiast user_id
    );

    if (response.statusCode == 200) {
      print('Użytkownik zbanowany');
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd przy banowaniu użytkownika: $error');
    }
  }


  static Future<void> updateUserEventPreferences(
      String userId, List<String> selectedTypes) async {
    final response = await http.post(
      Uri.parse('$link/user_event_preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'event_types': selectedTypes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Nie udało się zaktualizować preferencji');
    }
  }

  static Future<String?> getUserNickname() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
      }
      
      // Pobierz dane użytkownika na podstawie tokenu
      final userData = await getUserByToken(token);
      if (userData != null && userData.containsKey('nickName')) {
        return userData['nickName'];
      }
      return null;
    } catch (e) {
      print('Błąd podczas pobierania nicku użytkownika: $e');
      return null;
    }
  }

  // Pobieranie komentarzy dla wydarzenia
  static Future<List<Map<String, dynamic>>> getEventComments(String eventId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/comments');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd podczas pobierania komentarzy: $error');
    }
  }

  // Dodawanie komentarza do wydarzenia
  static Future<void> addEventComment(String eventId, String text) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/comments');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd podczas dodawania komentarza: $error');
    }
  }

  // Usuwanie komentarza do wydarzenia (dla moderatorów lub autora komentarza)
  static Future<void> deleteEventComment(String eventId, String commentId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/comments/$commentId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd podczas usuwania komentarza: $error');
    }
  }
  
  // Zgłaszanie komentarza moderatorom
  static Future<void> reportComment(String eventId, String commentId, String reason) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Brak tokenu sesji. Użytkownik nie jest zalogowany.');
    }

    final url = Uri.parse('$link/events/$eventId/comments/$commentId/report');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reason': reason}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd podczas zgłaszania komentarza: $error');
    }
  }

  static Future<List<String>> getBannedUsers(String eventId) async {
    final url = Uri.parse('$link/events/$eventId/banned_users');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.cast<String>();
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd pobierania zbanowanych użytkowników: $error');
    }
  }


  static Future<void> unbanUser(String eventId, String nickName) async {
    final token = await getToken();
    if (token == null) throw Exception('Brak tokenu sesji.');

    final url = Uri.parse('$link/events/$eventId/unban');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nickName': nickName}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Błąd podczas odbanowywania: $error');
    }
  }


  static Future<void> reportEvent(String eventId, String reason) async {
  final token = await getToken();
  if (token == null) throw Exception('Brak tokenu');

  final response = await http.post(
    Uri.parse('$link/report_event'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    },
    body: jsonEncode({
      'event_id': eventId,
      'reason': reason
    }),
  );

  if (response.statusCode != 201) {
    throw Exception(jsonDecode(response.body)['error'] ?? 'Nie udało się zgłosić wydarzenia');
  }
}


  static Future<double> getOrganizerRating(String organizerId) async {
    final url = Uri.parse('$link/organizer/$organizerId/rating');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return double.tryParse(data['average_rating'].toString()) ?? 0.0;
    } else {
      throw Exception('Błąd pobierania oceny organizatora');
    }
  }



  static Future<void> rateOrganizer(String organizerId, int rating) async {
    final token = await getToken();
    final url = Uri.parse('$link/rate_organizer');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'organizer_id': organizerId,
        'rating': rating,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Nieznany błąd';
      throw Exception('Nie udało się zapisać oceny: $error');
    }
  }



}

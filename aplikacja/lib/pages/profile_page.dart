import 'dart:io';
import 'package:Hive/styles/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Strona profilu użytkownika
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userData;
  int? userId;

  get http => null;

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

      final data = await DatabaseHelper.getUserByToken(token);
      setState(() {
        userData = data;
        userId = data?['id'];
      });
    } catch (e) {
      print('Błąd podczas pobierania danych użytkownika: $e');
    }
  }

  Future<void> _uploadNewProfilePicture(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Przygotuj plik do przesłania
        final File file = File(pickedFile.path);

        // Pobierz token do uwierzytelnienia
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token == null) {
          throw Exception("Brak tokenu w SharedPreferences");
        }

        // TODO: to nie powinno być w database_helper?
        // Wyślij obraz na serwer
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://212.127.78.92:5000/upload_image'),
        )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('image', file.path));

        final response = await request.send();

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zdjęcie profilowe zostało zmienione!')),
          );

          // Opcjonalnie: zaktualizuj obraz w interfejsie
          setState(() {
            userData?['profileImage'] = '<ścieżka_na_serwerze>'; // Zaktualizuj, jeśli serwer zwraca URL
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Błąd podczas przesyłania zdjęcia')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie wybrano żadnego zdjęcia.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wystąpił błąd: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Pomarańczowe tło
          Container(
            color: Colors.orange,
            height: MediaQuery.of(context).size.height * 0.4,
          ),
          Column(
            children: [
              const SizedBox(height: 50), // Odstęp od góry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Zdjęcie profilowe
              GestureDetector(
                onTap: () => _uploadNewProfilePicture(context),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: userData != null && userData!['profileImage'] != null
                      ? NetworkImage(userData!['profileImage']) // Ładowanie z serwera
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // Nazwa użytkownika
              Text(
                userData != null && userData!['nickName'] != null
                    ? userData!['nickName']
                    : 'Nie ustawiono',
                style: HiveTextStyles.title,
              ),
              const SizedBox(height: 20),
              // Biały kontener z zaokrąglonymi rogami
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'W przyszłości wydarzenia użytkownika',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'pages/sign_in.dart';
import 'pages/home_page.dart';
import 'pages/registration.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/password_reset_page.dart';
import 'models/event.dart';

// Inicjalizacja listy eventów, na której działa cała aplikacja
List<Event> initialEvents = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString('token');
  print("Odczytany token: $token"); // Sprawdź, czy token jest zapisany
  String? errorMessage;

  if (token != null) {
    try {
      await DatabaseHelper.verifyToken(token);
    } catch (e) {
      prefs.remove('token');
      token = null;
      errorMessage = 'Sesja wygasła, zaloguj się ponownie.';
    }
  }

  runApp(MyApp(
    initialRoute: token != null ? '/home' : '/sign_in',
    errorMessage: errorMessage,
  ));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final String? errorMessage;

  const MyApp({super.key, required this.initialRoute, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Wyłączenie debugowego banera
      title: 'Hive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),

      initialRoute: initialRoute,
      routes: {
        '/sign_in': (context) => SignInPage(events: initialEvents, errorMessage: errorMessage),
        '/register': (context) => RegisterPage(),
        '/home': (context) => HomePage(events: initialEvents),
        '/account': (context) => ProfilePage(),
        '/settings': (context) => SettingsPage(),
        '/change_password': (context) => PasswordResetPage(),
      },
    );
  }
}

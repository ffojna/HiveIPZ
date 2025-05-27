import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database/database_helper.dart';
import 'pages/sign_in.dart';
import 'pages/home_page.dart';
import 'models/event.dart';
import 'services/local_notification_service.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
List<Event> initialEvents = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicjalizacja powiadomień lokalnych
  await LocalNotificationService.initialize(flutterLocalNotificationsPlugin);
  await LocalNotificationService().requestPermisions();

  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString('token');
  print("Odczytany token: $token");

  String? errorMessage;
  Widget homeWidget = SignInPage(events: [],);

  if (token != null) {
    try {
      await DatabaseHelper.verifyToken(token);
      homeWidget = HomePage(events: [],);
    } catch (e) {
      prefs.remove('token');
    }
  }

  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    home: homeWidget,
    debugShowCheckedModeBanner: false,
  ));
}

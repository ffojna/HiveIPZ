import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../database/database_helper.dart';
import 'home_page.dart';
import '../models/event.dart';
import 'registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInPage extends StatefulWidget {
  final List<Event> events;
  final String? errorMessage;

  const SignInPage({Key? key, required this.events, this.errorMessage}) : super(key: key);

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorMessage!)),
        );
      });
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _signIn() async {
    final nickName = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (nickName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wprowadź login i hasło')),
      );
      return;
    }

    try {
      final userData = await DatabaseHelper.getUser(nickName, password);

      if (userData != null) {
        final prefs = await SharedPreferences.getInstance();
        final storedPin = prefs.getString('pin_') ?? '';

        if (storedPin.isNotEmpty) {
          _showPinVerificationDialog(userData, storedPin);
        } else {
          _completeLogin(userData['token']);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nieprawidłowe dane logowania')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd połączenia: $e')),
      );
    }
  }

  void _completeLogin(String token) async {
    await saveToken(token);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zalogowano pomyślnie')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage(events: [])),
    );
  }

  void _showPinVerificationDialog(Map<String, dynamic> userData, String storedPin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Weryfikacja 2FA'),
        content: TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Wprowadź PIN',
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFC300)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFC300), width: 2),
            ),
          ),
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pinController.clear(); // Wyczyść pole PINu
              Navigator.pop(context);
            },
            child: Text('Anuluj', style: TextStyle(color: Color(0xFFFFC300))),
          ),
          ElevatedButton(
            onPressed: () {
              final enteredPin = _pinController.text.trim();
              if (enteredPin == storedPin) {
                _pinController.clear(); // Wyczyść pole PINu
                Navigator.pop(context);
                _completeLogin(userData['token']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nieprawidłowy PIN')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFC300),
              foregroundColor: Colors.black,
            ),
            child: const Text('Zweryfikuj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFC300), Color(0xFFFBFBFB)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFC300), Color(0xFFFBFBFB)],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Hive',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _loginController,
                    decoration: InputDecoration(
                      labelText: 'Email / Nazwa użytkownika',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Hasło',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/change_password'),
                    child: const Text('Zapomniałem hasła'),
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFC300),
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: const Text('Zaloguj', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  const Text('lub zaloguj się przez'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: SvgPicture.asset('assets/facebook_icon.svg', width: 35, height: 35),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: SvgPicture.asset('assets/google_icon.svg', width: 35, height: 35),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Dołącz do nas!'),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        ),
                        child: Text('Zarejestruj się', style: TextStyle(color: Color(0xFFFFC300))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
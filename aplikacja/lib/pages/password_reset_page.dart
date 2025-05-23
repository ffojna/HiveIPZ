import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Strona resetu hasła z użyciem maila
class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({Key? key}) : super(key: key);

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
  }

class _PasswordResetPageState extends State<PasswordResetPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _showPassword = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola')),
      );
      return;
    }

    // Walidacja nowego hasła
    final passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[!@#\$&*~_-]).{8,}$');
      if (!passwordRegExp.hasMatch(newPassword)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hasło musi mieć co najmniej 8 znaków, zawierać wielką literę i znak specjalny.',
            ),
          ),
        );
        return;
      }

      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasła się nie zgadzają')),
        );
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('http://212.127.78.92:5000/change_password'), // Endpoint na backendzie
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'new_password': newPassword}),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hasło zostało zmienione')),
          );
          Navigator.pop(context);
        } else if (response.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Użytkownik o podanym emailu nie istnieje')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd serwera: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd połączenia: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zmień hasło'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showPassword,
              decoration: const InputDecoration(
                labelText: 'Nowe hasło',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showPassword,
              decoration: const InputDecoration(
                labelText: 'Potwierdź nowe hasło',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _showPassword,
                  onChanged: (value) {
                    setState(() {
                      _showPassword = value!;
                    });
                  }
                ),
                const Text("Pokaż hasło")
              ]
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetPassword,
              child: const Text('Potwierdź'),
            ),
          ],
        ),
      ),
    );
  }
}

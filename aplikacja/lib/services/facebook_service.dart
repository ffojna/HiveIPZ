import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookService {
  static Future<void> loginWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();

    if (result.status == LoginStatus.success) {
      final AccessToken accessToken = result.accessToken!;
      final userData = await FacebookAuth.instance.getUserData();

      final String email = userData['email'] ?? '';
      final String name = userData['name'] ?? '';


    } else {
      print('Logowanie przez Facebook nieudane: ${result.status}');
    }
  }
}
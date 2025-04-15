import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TwitterService {

  static Future<void> loginWithTwitter(BuildContext context) async {
    const backendUrl = 'https://vps.jakosinski.pl:5000/twitter/login';

    if (await canLaunchUrl(Uri.parse(backendUrl))) {
      await launchUrl(
        Uri.parse('intent://vps.jakosinski.pl:5000/twitter/login#Intent;scheme=https;package=com.android.chrome;end'),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można otworzyć Twitter login.')),
      );
    }
  }
}
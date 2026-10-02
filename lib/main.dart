import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/messaging_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await MessagingService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed/bypassed: $e');
  }
  runApp(const MedGuardApp());
}
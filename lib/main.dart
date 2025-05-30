import 'package:dtx/views/audioprompt.dart';
import 'package:dtx/views/gender.dart';
import 'package:dtx/views/height.dart';
import 'package:dtx/views/home.dart';
import 'package:dtx/views/media.dart';
import 'package:dtx/views/name.dart';
import 'package:dtx/views/profile_screens.dart';
import 'package:dtx/views/prompt.dart';
import 'package:flutter/material.dart';
import 'package:dtx/views/splash_screen.dart';
import 'package:dtx/views/writeprompt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(
    // Adding ProviderScope at the root of the app
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Change StatelessWidget to ConsumerWidget to use Riverpod
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DTX',
      debugShowCheckedModeBanner: false, // Optional: removes debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // You can add more theme configurations here
      ),
      // You can change the home screen here based on your flow
      // For example, start with PhoneInputScreen for authentication flow
      home: const SplashScreen(),
    );
  }
}

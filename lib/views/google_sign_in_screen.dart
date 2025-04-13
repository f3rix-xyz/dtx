// File: views/google_sign_in_screen.dart
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/utils/app_enums.dart'; // *** ADDED: Import FeedType ***
import 'package:dtx/views/home.dart';
import 'package:dtx/views/location.dart';
import 'package:dtx/views/name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/auth_model.dart';

class GoogleSignInScreen extends ConsumerWidget {
  const GoogleSignInScreen({super.key});

  Future<void> _handleSignIn(BuildContext context, WidgetRef ref) async {
    final status = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!context.mounted) return;

    // --- FIX: Pass initialFeedType to HomeScreen ---
    Widget destination;
    switch (status) {
      case AuthStatus.home:
        destination =
            const HomeScreen(initialFeedType: FeedType.home); // Pass home
        break;
      case AuthStatus.onboarding1:
        destination = const LocationInputScreen();
        break;
      case AuthStatus.onboarding2:
        // If logic dictates going straight to quick feed after step 1:
        destination =
            const HomeScreen(initialFeedType: FeedType.quick); // Pass quick
        // If logic dictates going to step 2 screens first:
        // destination = const NameInputScreen();
        break;
      case AuthStatus.login:
      case AuthStatus.unknown:
        // Default case removed as it's unreachable if all AuthStatus values are handled
        // default:
        // Stay on this screen, error provider handles message
        return; // Don't navigate if sign-in failed or status is unexpected login/unknown
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
    // --- END FIX ---
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... (rest of build method likely okay, ensure GoogleFonts import) ...
    final authState = ref.watch(authProvider);
    final errorState = ref.watch(errorProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Spacer(flex: 2),
                  Text(
                    'Peeple',
                    style: GoogleFonts.pacifico(
                      fontSize: screenSize.width * 0.15,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.03),
                  Text(
                    'Connect Authentically',
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.045,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (authState.isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    ElevatedButton.icon(
                      // Ensure you have 'assets/google_logo.png' or handle missing asset
                      icon: Image.asset('assets/google_logo.png',
                          height: 24.0,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.login, size: 24)),
                      label: Text(
                        'Sign In with Google',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _handleSignIn(context, ref),
                    ),
                  SizedBox(height: screenSize.height * 0.02),
                  if (errorState != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Text(
                        errorState.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.redAccent[100],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      'By signing in, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

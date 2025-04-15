import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import FeedProvider
import 'package:dtx/providers/filter_provider.dart'; // Import FilterProvider
import 'package:dtx/views/location.dart';
import 'package:dtx/views/main_navigation_screen.dart'; // Import MainNavigationScreen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/models/auth_model.dart';
// Removed FeedType import
// Removed Home import
// Removed NameInputScreen import

class GoogleSignInScreen extends ConsumerWidget {
  const GoogleSignInScreen({super.key});

  void _initiateEarlyFetches(WidgetRef ref) {
    print(
        "[GoogleSignInScreen] Initiating early data fetches (Filters, HomeFeed).");
    // Don't await, let them run in background
    ref.read(filterProvider.notifier).loadFilters();
    ref.read(feedProvider.notifier).fetchFeed();
  }

  Future<void> _handleSignIn(BuildContext context, WidgetRef ref) async {
    final status = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!context.mounted) return;

    Widget destination;
    switch (status) {
      case AuthStatus.home:
      case AuthStatus.onboarding2: // Both go to main screen now
        print('[GoogleSignInScreen] Navigating to MainNavigationScreen');
        _initiateEarlyFetches(ref); // Start loading data
        destination = const MainNavigationScreen();
        break;
      case AuthStatus.onboarding1:
        print('[GoogleSignInScreen] Navigating to LocationInputScreen');
        destination = const LocationInputScreen();
        break;
      case AuthStatus.login:
      case AuthStatus.unknown:
      default:
        // Stay on this screen if sign-in failed or status is unexpected
        print(
            '[GoogleSignInScreen] Sign in failed or status unknown/login. Staying on screen.');
        return;
    }
    // Use pushReplacement to prevent going back to the sign-in screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build method remains largely the same, only navigation logic changed
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

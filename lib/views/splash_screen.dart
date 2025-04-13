// File: views/splash_screen.dart
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/models/auth_model.dart';
import 'package:dtx/utils/app_enums.dart'; // Import FeedType
import 'package:dtx/views/google_sign_in_screen.dart'; // Import Google Sign-In screen
import 'package:dtx/views/home.dart';
import 'package:dtx/views/location.dart'; // Import location screen for onboarding1
import 'package:dtx/views/name.dart'; // Import name screen for onboarding2 start
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Remove Phone/OTP imports if they exist
// import 'package:dtx/views/phone.dart';
// import 'package:dtx/views/youtube.dart'; // Remove if replaced by GoogleSignInScreen

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  // late Animation<double> _rotateAnim; // Rotate animation can be removed if not desired
  bool _animationComplete = false;
  bool _statusCheckComplete = false;
  AuthStatus _authStatus = AuthStatus.unknown;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkAuthStatus(); // Start checking auth status immediately
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Slightly faster maybe?
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve:
            const Interval(0.0, 0.8, curve: Curves.easeIn), // Fade in earlier
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut, // Keep the bounce effect
      ),
    );

    // _rotateAnim = Tween<double>(begin: -0.1, end: 0).animate( // Simple rotate
    //   CurvedAnimation(
    //     parent: _controller,
    //     curve: Curves.elasticOut,
    //   ),
    // );

    _controller.forward();

    // Mark animation as complete
    // Use a shorter delay, navigation depends more on auth check now
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _animationComplete = true;
        });
        _navigateIfReady();
      }
    });
  }

  // --- UPDATED: Auth Check Logic ---
  Future<void> _checkAuthStatus() async {
    print('[SplashScreen] Checking Auth Status...');
    try {
      // Perform the check without updating AuthProvider's state directly from here
      final status = await ref.read(authProvider.notifier).checkAuthStatus(
          updateState: false); // Key change: updateState: false

      print('[SplashScreen] Auth Status Check Result: $status');

      // Ensure widget is still mounted before updating state and navigating
      if (!mounted) return;

      setState(() {
        _authStatus = status;
        _statusCheckComplete = true;
      });
      _navigateIfReady(); // Attempt navigation now that status is known
    } catch (e) {
      print('[SplashScreen] Error during Auth Status Check: $e');
      if (!mounted) return;
      // If check fails, assume login is needed
      setState(() {
        _authStatus = AuthStatus.login;
        _statusCheckComplete = true;
      });
      _navigateIfReady(); // Attempt navigation even on error (to login)
    }
  }
  // --- END UPDATED ---

  // --- UPDATED: Navigation Logic ---
  void _navigateIfReady() {
    print(
        '[SplashScreen] Navigate If Ready: Animation Complete=$_animationComplete, Status Check Complete=$_statusCheckComplete, Status=$_authStatus');
    // Only navigate if *both* animation has played sufficiently and status check is done
    if (_animationComplete && _statusCheckComplete) {
      print('[SplashScreen] Conditions met. Navigating...');
      Widget destination;

      switch (_authStatus) {
        case AuthStatus.home:
          print('[SplashScreen] Navigating to HomeScreen (Home Feed)');
          // We will need to modify HomeScreen to accept this parameter
          destination = const HomeScreen(initialFeedType: FeedType.home);
          break;
        case AuthStatus.onboarding1:
          print(
              '[SplashScreen] Navigating to LocationInputScreen (Onboarding Step 1)');
          destination = const LocationInputScreen();
          break;
        case AuthStatus.onboarding2:
          print('[SplashScreen] Navigating to HomeScreen (Quick Feed)');
          // Navigate to HomeScreen but tell it to load the Quick Feed
          destination = const HomeScreen(initialFeedType: FeedType.quick);
          break;
        case AuthStatus.login:
        case AuthStatus.unknown:
        default:
          print('[SplashScreen] Navigating to GoogleSignInScreen (Login)');
          destination =
              const GoogleSignInScreen(); // Navigate to Google Sign In
          break;
      }

      // Use pushReplacement to prevent user going back to splash screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      print('[SplashScreen] Conditions not met. Waiting...');
    }
  }
  // --- END UPDATED ---

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double responsiveFontSize = screenSize.width * 0.18; // Adjusted size
    final double subtitleFontSize = screenSize.width * 0.04; // Adjusted size
    final double bottomPadding = screenSize.height * 0.05;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      // Removed Rotate Transform for simplicity unless needed
                      // child: Transform.rotate(
                      //   angle: _rotateAnim.value,
                      child: FittedBox(
                        // Ensures text fits if screen is small
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Peeple',
                          style: GoogleFonts.pacifico(
                            fontSize: responsiveFontSize,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black
                                    .withOpacity(0.6), // Darker shadow
                                blurRadius: 15,
                                offset:
                                    const Offset(0, 4), // Slightly more offset
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ),
                    ),
                  );
                },
              ),
            ),
            // Subtitle remains similar
            Positioned(
              bottom: bottomPadding,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Text(
                      'Connect. Share. Thrive.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        // Use Poppins for consistency maybe?
                        color: Colors.white.withOpacity(0.9),
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5, // Add slight spacing
                      ),
                    ),
                  );
                },
              ),
            ),
            // Loading indicator if waiting for auth check after animation
            if (_animationComplete && !_statusCheckComplete)
              Positioned(
                bottom: bottomPadding + 50, // Position above subtitle
                left: 0,
                right: 0,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

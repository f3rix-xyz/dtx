import 'package:dtx/models/auth_model.dart';
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import FeedProvider
import 'package:dtx/providers/filter_provider.dart'; // Import FilterProvider
import 'package:dtx/services/api_service.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/google_sign_in_screen.dart';
import 'package:dtx/views/main_navigation_screen.dart'; // Import MainNavigationScreen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/error_model.dart';
import '../providers/user_provider.dart';
import '../providers/error_provider.dart';
import '../providers/service_provider.dart';
// Removed Home import

class GenderSelectionScreen extends ConsumerStatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  ConsumerState<GenderSelectionScreen> createState() =>
      _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends ConsumerState<GenderSelectionScreen> {
  bool _isSubmitting = false;

  void _initiateEarlyFetches() {
    print(
        "[GenderSelectionScreen] Initiating early data fetches (Filters, HomeFeed).");
    // Don't await, let them run in background
    ref.read(filterProvider.notifier).loadFilters();
    ref.read(feedProvider.notifier).fetchFeed();
  }

  Future<void> _submitLocationAndGender() async {
    final userState = ref.read(userProvider);
    final errorNotifier = ref.read(errorProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    errorNotifier.clearError();

    if (userState.latitude == null || userState.longitude == null) {
      errorNotifier.setError(
          AppError.validation("Location data is missing. Please go back."));
      return;
    }
    if (userState.gender == null) {
      errorNotifier.setError(AppError.validation("Please select a gender."));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userRepository = ref.read(userRepositoryProvider);
      final success = await userRepository.updateLocationGender(
        userState.latitude!,
        userState.longitude!,
        userState.gender!,
      );

      if (success) {
        print(
            "[GenderSelectionScreen] Location/Gender submitted successfully.");
        final finalStatus =
            await authNotifier.checkAuthStatus(updateState: true);
        print("[GenderSelectionScreen] Auth status updated to: $finalStatus");

        if (mounted) {
          Widget nextScreen;
          // Navigate to MainNavigationScreen if onboarding is complete (status onboarding2 or home)
          if (finalStatus == AuthStatus.onboarding2 ||
              finalStatus == AuthStatus.home) {
            print(
                "[GenderSelectionScreen] Navigating to MainNavigationScreen.");
            _initiateEarlyFetches(); // Start loading data
            nextScreen = const MainNavigationScreen();
          } else {
            // Fallback to GoogleSignInScreen if status is unexpectedly login/unknown
            print(
                "[GenderSelectionScreen] Unexpected status ($finalStatus), navigating to GoogleSignInScreen.");
            nextScreen = const GoogleSignInScreen();
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => nextScreen),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        print(
            "[GenderSelectionScreen] Location/Gender submission failed (API returned false).");
        if (ref.read(errorProvider) == null) {
          errorNotifier
              .setError(AppError.server("Failed to update location/gender."));
        }
      }
    } on ApiException catch (e) {
      print(
          "[GenderSelectionScreen] API Exception during submit: ${e.message}");
      errorNotifier.setError(AppError.server(e.message));
    } catch (e) {
      print(
          "[GenderSelectionScreen] Unexpected error during submit: ${e.toString()}");
      errorNotifier.setError(
          AppError.generic("An unexpected error occurred. Please try again."));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build method remains largely the same, only navigation logic changed
    final screenSize = MediaQuery.of(context).size;
    final userState = ref.watch(userProvider);
    final errorState = ref.watch(errorProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey[600]),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              Text(
                "Which gender best\ndescribes you?",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.075,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              SizedBox(height: screenSize.height * 0.05),
              Column(
                children: [Gender.man, Gender.woman]
                    .map((gender) => _buildOption(gender))
                    .toList(),
              ),
              const Spacer(),
              if (errorState != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    errorState.message,
                    style: GoogleFonts.poppins(
                        color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Color(0xFF8B5CF6))
                      : FloatingActionButton(
                          heroTag: 'gender_next_fab',
                          onPressed: userState.gender != null
                              ? _submitLocationAndGender
                              : null,
                          backgroundColor: userState.gender != null
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.arrow_forward_rounded),
                        ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(Gender gender) {
    // _buildOption implementation remains the same
    final bool isSelected = ref.watch(userProvider).gender == gender;
    final errorNotifier = ref.read(errorProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFFEDE9FE) : Colors.grey.shade50,
        elevation: isSelected ? 1 : 0,
        shadowColor: const Color(0xFF8B5CF6).withOpacity(0.3),
        child: InkWell(
          onTap: () {
            errorNotifier.clearError();
            ref.read(userProvider.notifier).updateGender(gender);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  gender.label,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey.shade800,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade400, width: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

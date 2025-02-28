
import 'package:dtx/views/home.dart';
import 'package:dtx/views/selfie_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerificationMessageScreen extends StatelessWidget {
  const VerificationMessageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Top spacing
              // Illustration or Icon
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 100,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                "Profile Verification",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle/Description
              Text(
                "We are verifying your profile to ensure that no one else can use your photo. This helps us keep our community safe and authentic.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(), // Pushes the button to the bottom
              // Continue Button
              GestureDetector(
onTap: () {
  // Navigate to HomeScreen
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const SelfieCaptureScreen(),
  ));
},
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "Continue",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32), // Bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}

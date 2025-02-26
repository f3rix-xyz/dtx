import 'package:dtx/views/name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/error_provider.dart';
import 'phone.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isResendVisible = false;
  bool _isButtonEnabled = false;
  bool _isVerifying = false;
  Timer? _timer;
  int _remainingTime = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer(); // Start the countdown when the screen loads
  }

  void _startResendTimer() {
    setState(() {
      _remainingTime = 60;
      _isResendVisible = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        if (mounted) {
          setState(() {
            _remainingTime--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isResendVisible = true;
          });
        }
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose(); // Dispose safely
    _timer?.cancel(); // Cancel the timer
    super.dispose();
  }

  void _onOtpChanged(String value) {
    setState(() {
      _isButtonEnabled = value.length == 6;
    });
  }

  void _resendOtp() async {
    final authState = ref.read(authProvider);
    if (authState.unverifiedPhone != null) {
      setState(() {
        _isResendVisible = false;
      });
      
      await ref.read(authProvider.notifier).sendOtp(authState.unverifiedPhone!);
      _startResendTimer();
    }
  }

  void _verifyOtp() async {
    final authState = ref.read(authProvider);
    if (authState.unverifiedPhone != null && _otpController.text.length == 6) {
      setState(() {
        _isVerifying = true;
      });
      
      final success = await ref.read(authProvider.notifier).verifyOtp(
        authState.unverifiedPhone!,
        _otpController.text,
      );
      
      setState(() {
        _isVerifying = false;
      });
      
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NameInputScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final authState = ref.watch(authProvider);
    final error = ref.watch(errorProvider);

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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenSize.height * 0.08), // Top padding

                // Title: Enter your verification code
                Text(
                  "Enter your\nverification code",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.09, // Large title font size
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: screenSize.height * 0.02),

                // Subtitle: Sent to phone number Edit
                Row(
                  children: [
                    // Phone number text
                    Text(
                      "Sent to ${authState.unverifiedPhone ?? ''}",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.045,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Edit button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PhoneInputScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Edit",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.045,
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: screenSize.height * 0.05),

                // OTP Input Fields
                PinCodeTextField(
                  length: 6,
                  controller: _otpController,
                  appContext: context,
                  keyboardType: TextInputType.number,
                  cursorColor: Colors.white,
                  textStyle: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.underline,
                    fieldHeight: screenSize.height * 0.08,
                    fieldWidth: screenSize.width * 0.1,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white54,
                    selectedColor: Colors.white,
                    errorBorderColor: Colors.redAccent,
                  ),
                  onChanged: _onOtpChanged,
                ),

                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      error.message,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ),

                SizedBox(height: screenSize.height * 0.02),

                // Resend OTP or Countdown timer
                Center(
                  child: _isResendVisible
                      ? GestureDetector(
                          onTap: _resendOtp,
                          child: Text(
                            "Resend OTP",
                            style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.045,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          "Resend OTP in $_remainingTime seconds",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.045,
                            color: Colors.white70,
                          ),
                        ),
                ),

                const Spacer(),

                // Next button: Enabled only when 6 digits are entered
                Center(
                  child: authState.isLoading || _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : GestureDetector(
                          onTap: _isButtonEnabled ? _verifyOtp : null,
                          child: Container(
                            width: screenSize.width * 0.18,
                            height: screenSize.width * 0.18,
                            decoration: BoxDecoration(
                              color: _isButtonEnabled ? Colors.white : Colors.white38,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (_isButtonEnabled)
                                  BoxShadow(
                                    color: const Color(0xFF4C1D95).withOpacity(0.6),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4), // Shadow position
                                  ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 28,
                              color: _isButtonEnabled
                                  ? const Color(0xFF8B5CF6)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),

                SizedBox(height: screenSize.height * 0.05), // Space below
              ],
            ),
          ),
        ),
      ),
    );
  }
}

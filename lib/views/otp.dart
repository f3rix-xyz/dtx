import 'package:dtx/views/name.dart';
import 'package:dtx/views/phone.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isResendVisible = false;
  bool _isButtonEnabled = false;
  Timer? _timer;
  int _remainingTime = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer(); // Start the countdown when the screen loads
  }

  void _startResendTimer() {
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

  @override
  Widget build(BuildContext context) {
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

                // Subtitle: Sent to 85809 65219 Edit
                Row(
                  children: [
                    // Phone number text
                    Text(
                      "Sent to 85809 65219",
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
                            builder: (context) => PhoneInputScreen(),
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
                  ),
                  onChanged: _onOtpChanged,
                ),

                SizedBox(height: screenSize.height * 0.02),

                // Resend OTP or Countdown timer
                Center(
                  child: _isResendVisible
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _remainingTime = 60;
                              _isResendVisible = false;
                              _startResendTimer();
                            });
                          },
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

                Spacer(),

                // Next button: Enabled only when 6 digits are entered
                Center(
                  child: GestureDetector(
                    onTap: _isButtonEnabled
                        ? () {
                            Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NameInputScreen()),
                  );
                          }
                        : null,
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

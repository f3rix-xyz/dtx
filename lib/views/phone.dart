import 'package:dtx/views/otp.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  _PhoneInputScreenState createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

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

                // Title: What's your phone number?
                Text(
                  "What's your\nphone number?",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.09, // Large title font size
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: screenSize.height * 0.02),

                // Subtitle: Subtle helper text
                Text(
                  "You'll receive an OTP on this number.",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.045,
                    color: Colors.white70, // Subtle gray color
                  ),
                ),

                SizedBox(height: screenSize.height * 0.05),

                // Phone number input field
                Container(
                  padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2.5,
                        color: _errorText == null ? Color(0xFFFFFFFF) : Colors.red, // Red if error
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "+91", // Static country code
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: screenSize.width * 0.02),

                      // Input TextField
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.06, // Large font
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: "Enter phone number",
                            hintStyle: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.05,
                              color: Colors.white70,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _validatePhoneNumber(value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Error message if validation fails
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorText!,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ),

                Spacer(),

                // Next button: Enabled only when valid input
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_validatePhoneNumber(_phoneController.text)) {
                        // Navigate to OTP Verification Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OtpVerificationScreen(),
                          ),
                        );
                      } else {
                        // Show an error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Invalid phone number! Please try again."),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: screenSize.width * 0.18,
                      height: screenSize.width * 0.18,
                      decoration: BoxDecoration(
                        color: _errorText == null ? Colors.white : Colors.grey.shade400, // Disable if invalid
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 28,
                        color: _errorText == null ? Color(0xFF8B5CF6) : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenSize.height * 0.05), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Phone number validation logic
  bool _validatePhoneNumber(String value) {
    if (value.isEmpty) {
      _errorText = "Phone number can't be empty.";
      return false;
    } else if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      _errorText = "Enter a valid 10-digit phone number.";
      return false;
    } else {
      _errorText = null; // No error
      return true;
    }
  }
}

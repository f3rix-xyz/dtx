import 'package:dtx/models/error_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/error_provider.dart';
import 'otp.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

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
                SizedBox(height: screenSize.height * 0.08),
                Text(
                  "What's your\nphone number?",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.09,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenSize.height * 0.02),
                Text(
                  "You'll receive an OTP on this number.",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.045,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: screenSize.height * 0.05),
                Container(
                  padding:
                      EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2.5,
                        color: error?.type == ErrorType.validation
                            ? Colors.red
                            : const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "+91",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: screenSize.width * 0.02),
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.06,
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
                            ref.read(authProvider.notifier).verifyPhone(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (error?.type == ErrorType.validation || error?.type == ErrorType.server)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      error!.message,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ),
                const Spacer(),
                Center(
                  child: authState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : GestureDetector(
                          onTap: authState.unverifiedPhone != null && !_isSubmitting
                              ? () async {
                                  setState(() {
                                    _isSubmitting = true;
                                  });
                                  
                                  final success = await ref.read(authProvider.notifier)
                                      .sendOtp(authState.unverifiedPhone!);
                                      
                                  setState(() {
                                    _isSubmitting = false;
                                  });
                                  
                                  if (success) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const OtpVerificationScreen(),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Container(
                            width: screenSize.width * 0.18,
                            height: screenSize.width * 0.18,
                            decoration: BoxDecoration(
                              color: authState.unverifiedPhone != null && !_isSubmitting
                                  ? Colors.white
                                  : Colors.grey.shade400,
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
                              color: authState.unverifiedPhone != null && !_isSubmitting
                                  ? const Color(0xFF8B5CF6)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                ),
                SizedBox(height: screenSize.height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

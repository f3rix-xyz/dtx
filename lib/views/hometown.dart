import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/job.dart';

class HometownScreen extends ConsumerStatefulWidget {
  const HometownScreen({super.key});

  @override
  ConsumerState<HometownScreen> createState() => _HometownScreenState();
}

class _HometownScreenState extends ConsumerState<HometownScreen> {
  final TextEditingController _hometownController = TextEditingController();

  @override
  void dispose() {
    _hometownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Consumer(
      builder: (context, ref, child) {
        final userState = ref.watch(userProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.04),

                  // Top Navigation Bar with Skip Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.home_rounded,
                          color: const Color(0xFF8B5CF6),
                          size: 32,
                        ),
                        onPressed: () {
                          // Handle home button action
                        },
                      ),
                      // Skip Button - Top Right
                      TextButton(
                        onPressed: () {
                          ref.read(userProvider.notifier).updateHometown(null);
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const JobTitleScreen())
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600, // Subdued color
                          padding: EdgeInsets.zero, // Remove default padding
                          minimumSize: Size.zero, // Make button size adjust to text
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                        ),
                        child: Text(
                          "Skip",
                          style: GoogleFonts.poppins(
                            fontSize: 16, // Smaller font size than title
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenSize.height * 0.07),

                  // Question Text
                  Text(
                    "Where's your home\ntown?",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.1,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                      height: 1.1,
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.05),

                  // Text Field
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.02),
                    child: TextField(
                      controller: _hometownController,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Udaipur",
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 22,
                          color: Colors.grey.shade500,
                        ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1.0),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Forward Button
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                      child: GestureDetector(
                        onTap: () {
                          String? hometown; // Changed to String? to allow null
                          if (_hometownController.text.isNotEmpty) {
                            hometown = _hometownController.text;
                            ref.read(userProvider.notifier).updateHometown(hometown);
                          } else {
                            hometown = null; // Set to null if text field is empty
                          }

                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const JobTitleScreen())
                          );
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

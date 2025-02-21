import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/study.dart';

class JobTitleScreen extends ConsumerStatefulWidget {
  const JobTitleScreen({super.key});

  @override
  ConsumerState<JobTitleScreen> createState() => _JobTitleScreenState();
}

class _JobTitleScreenState extends ConsumerState<JobTitleScreen> {
  final TextEditingController _jobTitleController = TextEditingController();

  @override
  void dispose() {
    _jobTitleController.dispose();
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
                        icon: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 32),
                        onPressed: () {
                          // Handle home button action
                        },
                      ),
                      // Skip Button - Top Right
                      TextButton(
                        onPressed: () {
                          ref.read(userProvider.notifier).updateJobTitle(null);
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const StudyLocationScreen())
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Skip",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenSize.height * 0.07),

                  // Question Text
                  Text(
                    "What's your job title?",
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
                      controller: _jobTitleController,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "SDE",
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
                          String? jobTitle;
                          if (_jobTitleController.text.isNotEmpty) {
                            jobTitle = _jobTitleController.text;
                            ref.read(userProvider.notifier).updateJobTitle(jobTitle);
                          } else {
                            jobTitle = null;
                          }

                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const StudyLocationScreen())
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

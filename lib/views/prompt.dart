import 'package:dtx/views/media.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';

class ProfileAnswersScreen extends StatefulWidget {
  const ProfileAnswersScreen({super.key});

  @override
  State<ProfileAnswersScreen> createState() => _ProfileAnswersScreenState();
}

class _ProfileAnswersScreenState extends State<ProfileAnswersScreen> {
  List<String?> _answers = List.generate(
      3, (index) => null); // Keeping 3 prompts, even without answer boxes
  bool _isForwardButtonEnabled =
      false; // Still using forward button logic (can be adjusted if needed)

  void _updateForwardButtonState() {
    // Logic might need adjustment if forward button functionality changes without answers
    int filledAnswers =
        _answers.where((answer) => answer != null && answer.isNotEmpty).length;
    setState(() {
      _isForwardButtonEnabled = filledAnswers >=
          0; // Always enabled now since no answer needed for button? Adjust as needed
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03), // Slight top spacing

              // Top Navigation Bar (No Icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const SizedBox(width: 48),
                ],
              ),

              SizedBox(height: screenSize.height * 0.04), // Spacing below nav

              // Heading Text - Lexend Deca Font
              Text(
                "Write your profile answers",
                textAlign: TextAlign.left,
                style: GoogleFonts.lexendDeca(
                  fontSize: screenSize.width * 0.095,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.0,
                ),
              ),

              SizedBox(
                  height: screenSize.height *
                      0.045), // **Increased spacing below heading** for visual balance

              // Prompt Box Section 1 - No Answer Box now
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 1,
                onAnswerChanged: (text) {
                  _answers[0] =
                      text; // Keeping answer update logic, even if not used in UI right now
                  _updateForwardButtonState();
                },
              ),

              SizedBox(
                  height: screenSize.height *
                      0.035), // **Increased spacing between boxes**

              // Prompt Box Section 2 - No Answer Box
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 2,
                onAnswerChanged: (text) {
                  _answers[1] = text;
                  _updateForwardButtonState();
                },
              ),

              SizedBox(
                  height: screenSize.height *
                      0.035), // **Increased spacing between boxes**

              // Prompt Box Section 3 - No Answer Box
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 3,
                onAnswerChanged: (text) {
                  _answers[2] = text;
                  _updateForwardButtonState();
                },
              ),

              SizedBox(
                  height: screenSize.height *
                      0.04), // **Increased spacing before "required answers"** for balance

              // "3 answers required" Text - Poppins font
              Padding(
                padding: EdgeInsets.only(left: screenSize.width * 0.01),
                child: Text(
                  "3 answers required",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.04,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const Spacer(),

              // Forward Button - Keep for now, functionality can be adjusted
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.03),
                  child: GestureDetector(
                    onTap: () {
                      if (_isForwardButtonEnabled) {
                        // Keep button enabled logic for now
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Navigating to next screen (MediaPickerScreen)..."), // Updated message
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MediaPickerScreen()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Continue to Media Selection."), // Updated message - no longer answer-related
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isForwardButtonEnabled
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _isForwardButtonEnabled
                            ? Colors.white
                            : Colors.grey.shade600,
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
  }

  Widget _buildPromptAnswerSection({
    required Size screenSize,
    required int promptNumber,
    required ValueChanged<String>
        onAnswerChanged, // Keep callback for potential future use
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Select a Prompt" - BIGGER Box, No Answer Input
        GestureDetector(
          onTap: () {},
          child: DottedBorder(
            dashPattern: const [6, 3],
            color: const Color(0xFF8B5CF6),
            strokeWidth:
                2.2, // **Slightly Thicker Border for visual prominence**
            borderType: BorderType.RRect,
            radius:
                const Radius.circular(15), // **Slightly more rounded corners**
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.035,
                  horizontal: screenSize.width *
                      0.04), // **Increased padding - BIGGER BOXES**
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                    15), // **Matching BorderRadius to DottedBorder**
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                        left: screenSize.width *
                            0.03), // **Slightly more left padding for text**
                    child: Text(
                      "Select a Prompt",
                      style: GoogleFonts.poppins(
                        fontSize:
                            19, // **Increased font size for "Select a Prompt"**
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.add,
                      color: Colors.grey.shade600,
                      size: 26, // **Slightly bigger "+" icon**
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // **Removed TextFormField - No answer box anymore**
        // SizedBox(height: screenSize.height * 0.01), // No longer needed spacing below answer box
      ],
    );
  }
}

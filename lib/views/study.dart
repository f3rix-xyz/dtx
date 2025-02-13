import 'package:dtx/views/job.dart';
import 'package:dtx/views/religion.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudyLocationScreen extends StatefulWidget {
  const StudyLocationScreen({super.key});

  @override
  State<StudyLocationScreen> createState() => _StudyLocationScreenState();
}

class _StudyLocationScreenState extends State<StudyLocationScreen> {
  final TextEditingController _studyLocationController = TextEditingController();

  @override
  void dispose() {
    _studyLocationController.dispose();
    super.dispose();
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
              SizedBox(height: screenSize.height * 0.04),

              // Top Navigation Bar with Skip Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.school_rounded, color: Color(0xFF8B5CF6), size: 32), // Using school_rounded icon
                    onPressed: () {
                      // Handle home button action
                    },
                  ),
                  // Skip Button - Top Right
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Study location step skipped."),
                        ),
                      );
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReligionScreen()) // Navigate to JobTitleScreen
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
                "Where did you study?",
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
                  controller: _studyLocationController,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Chut", // Placeholder text as per image
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
                      String? studyLocation; // Allow null value
                      if (_studyLocationController.text.isNotEmpty) {
                        studyLocation = _studyLocationController.text;
                      } else {
                        studyLocation = null; // Set to null if empty
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Study Location Selected: ${studyLocation ?? 'No study location selected'}",
                          ),
                        ),
                      );
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReligionScreen()) // Navigate to JobTitleScreen
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
  }
}
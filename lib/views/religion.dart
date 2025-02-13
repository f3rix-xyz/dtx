import 'package:dtx/views/drinking.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReligionScreen extends StatefulWidget { // Class name changed to ReligionScreen
  const ReligionScreen({super.key});

  @override
  State<ReligionScreen> createState() => _ReligionScreenState(); // State class name also updated
}

class _ReligionScreenState extends State<ReligionScreen> { // State class name changed
  String? _selectedReligion; // Changed from Set<String> to String? for single selection
  List<String> religions = [      // List of religion options - Removed specific religions
    'Agnostic', 'Atheist', 'Buddhist', 'Christian', 'Hindu',
    'Jain', 'Jewish', 'Muslim', 'Zoroastrian',
    'Sikh', 'Spiritual'
  ];

  void _toggleReligion(String religion) {
    setState(() {
      if (_selectedReligion == religion) {
        _selectedReligion = null; // Deselect if already selected
      } else {
        _selectedReligion = religion; // Select the tapped religion
      }
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
              SizedBox(height: screenSize.height * 0.04),

              // Top Navigation Bar - Removed Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), // Placeholder to keep alignment of Skip button - No Icon Now
                  const SizedBox(width: 48), // Spacing for alignment
                ],
              ),

              SizedBox(height: screenSize.height * 0.07),

              // Question Text - Changed Heading Text
              Text(
                "What are your religious beliefs?",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.1,
                ),
              ),

              SizedBox(height: screenSize.height * 0.05),

              // Removed Description Text and Religion Label

              // Religion Buttons Grid (using Wrap for flexible layout)
              Wrap(
                spacing: screenSize.width * 0.03, // Horizontal spacing between buttons
                runSpacing: screenSize.height * 0.015, // Vertical spacing between rows
                children: religions.map((religion) => _buildReligionButton(religion, screenSize)).toList(),
              ),

              const Spacer(),

              Padding(
                padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip Button
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Religion step skipped."), // Updated SnackBar message
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DrinkingScreen()) // Navigate to DrinkingScreen
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

                    // Forward Button
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Selected Religion: ${_selectedReligion ?? 'None'}", // Updated SnackBar message for single selection
                            ),
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DrinkingScreen()) // Navigate to DrinkingScreen
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReligionButton(String religion, Size screenSize) {
    bool isSelected = _selectedReligion == religion; // Check for single selection match
    return GestureDetector(
      onTap: () => _toggleReligion(religion),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: screenSize.height * 0.015),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white, // Changed to primary theme color
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Important for Wrap layout
          children: [
            Text(
              religion,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            // Removed the 'x' icon as it's less relevant in single selection UX
          ],
        ),
      ),
    );
  }
}
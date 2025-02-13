import 'package:dtx/views/height.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DatingIntentionsScreen extends StatefulWidget {
  const DatingIntentionsScreen({super.key});

  @override
  State<DatingIntentionsScreen> createState() => _DatingIntentionsScreenState();
}

class _DatingIntentionsScreenState extends State<DatingIntentionsScreen> {
  String _selectedIntention = ""; // Currently selected option
  bool _isVisibleOnProfile = true; // Checkbox state

  final List<String> _options = [
    "Life partner",
    "Long-term relationship",
    "Long-term relationship, open to short",
    "Short-term relationship, open to long",
    "Short-term relationship",
    "Figuring out my dating goals",
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress and Header Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.02),

                  // Dots Progress Bar
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        10,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index < 7 ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.03),

                  // Title
                  Text(
                    "What's your dating intention?",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.065,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),

            // Options List with Cascading Effect
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  return _buildOption(index);
                },
              ),
            ),

            // "Visible on Profile" Checkbox
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.06, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    value: _isVisibleOnProfile,
                    onChanged: (bool? value) {
                      setState(() {
                        _isVisibleOnProfile = value ?? true;
                      });
                    },
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                  Text(
                    "Visible on profile",
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),

            // Forward Arrow Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                child: GestureDetector(
                  onTap: _selectedIntention.isNotEmpty
                      ? () {
                          Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HeightSelectionScreen()),
                  );
                        }
                      : null, // Disable when no option is selected
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _selectedIntention.isNotEmpty
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_selectedIntention.isNotEmpty)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 8,
                          ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 28,
                      color: _selectedIntention.isNotEmpty
                          ? Colors.white
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.04),
          ],
        ),
      ),
    );
  }

  // Build Option Tiles
  Widget _buildOption(int index) {
    final String option = _options[index];
    final bool isSelected = _selectedIntention == option;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIntention = option;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              option,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
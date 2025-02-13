import 'package:dtx/views/hometown.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math'; // Import dart:math for rounding functions

class HeightSelectionScreen extends StatefulWidget {
  const HeightSelectionScreen({super.key});

  @override
  State<HeightSelectionScreen> createState() => _HeightSelectionScreenState();
}

class _HeightSelectionScreenState extends State<HeightSelectionScreen> {
  String _unit = "FT"; // Default unit is Feet
  int _selectedFeetIndex = 12; // Start at 5'0" (index 12) - Correct starting index
  int _selectedCmIndex = 30; // Start at 150 cm (index 30)


  // Feet and CM values
  final List<String> _feetValues = [
    "4' 0\"",
    "4' 1\"",
    "4' 2\"",
    "4' 3\"",
    "4' 4\"",
    "4' 5\"",
    "4' 6\"",
    "4' 7\"",
    "4' 8\"",
    "4' 9\"",
    "4' 10\"",
    "4' 11\"",
    "5' 0\"",
    "5' 1\"",
    "5' 2\"",
    "5' 3\"",
    "5' 4\"",
    "5' 5\"",
    "5' 6\"",
    "5' 7\"",
    "5' 8\"",
    "5' 9\"",
    "5' 10\"",
    "5' 11\"",
    "6' 0\"",
    "6' 1\"",
    "6' 2\"",
    "6' 3\"",
    "6' 4\"",
    "6' 5\"",
  ];
  final List<String> _cmValues = List.generate(81, (index) => "${120 + index} cm");

  // Function to convert CM to Feet and Inches string
  String _cmToFeet(int cm) {
    double totalInches = cm * 0.393701;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round(); // Round inches to nearest whole number
    if (inches == 12) { // Handle cases where inches round up to 12
      feet++;
      inches = 0;
    }
    return "$feet' $inches\"";
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Use appropriate values for the current unit
    final List<String> currentValues = _unit == "FT" ? _feetValues : _cmValues;
    int currentIndex = _unit == "FT" ? _selectedFeetIndex : _selectedCmIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4), // Light background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.06), // Increased spacing

              // Title
              Center(
                child: Text(
                  "How tall are you?",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.1, // Increased font size for title
                    fontWeight: FontWeight.w700, // More bold title
                    color: const Color(0xFF333333), // Darker title color
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.05), // Increased spacing below title

              // Height Selector
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 70, // Increased item extent for better spacing
                  diameterRatio: 1.3, // Adjusted for better visual
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      if (_unit == "FT") {
                        _selectedFeetIndex = index;
                      } else {
                        _selectedCmIndex = index;
                      }
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: currentValues.length,
                    builder: (context, index) {
                      final isSelected = index == currentIndex;
                      return Center(
                        child: Text(
                          currentValues[index],
                          style: GoogleFonts.poppins(
                            fontSize: isSelected ? 30 : 22, // Larger font sizes for list items
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, // Adjusted weight
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade700, // Highlighted selected color, darker unselected
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.03), // Reduced spacing above buttons

              // Unit Toggle Buttons - Improved UI
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.1), // Add horizontal padding for buttons
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // Space buttons evenly
                  children: [
                    _buildUnitButton("FT", screenSize),
                    _buildUnitButton("CM", screenSize),
                  ],
                ),
              ),

              SizedBox(height: screenSize.height * 0.04), // Spacing before forward button

              // Forward Button - More prominent and centered
              Center(
                child: GestureDetector(
                  onTap: () {
                    String savedHeightFeet;
                    String selectedValue = currentValues[currentIndex];

                    if (_unit == "CM") {
                      savedHeightFeet = _cmToFeet(int.parse(selectedValue.replaceAll(" cm", "")));
                    } else {
                      savedHeightFeet = selectedValue;
                    }

                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HometownScreen()),
                  );
                    // In a real app, you would save 'savedHeightFeet' to your database here.
                  },
                  child: Container(
                    width: 70, // Even larger button
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(35), // More rounded
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 32, // Larger icon
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.06), // Increased bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(String unit, Size screenSize) {
    final isSelected = _unit == unit;
    return GestureDetector(
      onTap: () {
        setState(() {
          _unit = unit;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: screenSize.width * 0.08), // Dynamic horizontal padding
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white, // White background for unselected
          border: Border.all(color: Colors.grey.shade300), // Subtle border
          borderRadius: BorderRadius.circular(30), // Even more rounded corners
          boxShadow: [ // Subtle shadow for depth
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 0,
              blurRadius: 3,
              offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: Text(
          unit,
          style: GoogleFonts.poppins(
            fontSize: 18, // Larger font size for buttons
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, // Slightly bolder for selected
            color: isSelected ? Colors.white : const Color(0xFF555555), // Darker text for unselected
          ),
        ),
      ),
    );
  }
}
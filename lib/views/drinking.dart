import 'package:dtx/views/religion.dart'; // Import the next screen - ReligionScreen or your actual next screen
import 'package:dtx/views/smoking.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DrinkingScreen extends StatefulWidget {
  const DrinkingScreen({super.key});

  @override
  State<DrinkingScreen> createState() => _DrinkingScreenState();
}

class _DrinkingScreenState extends State<DrinkingScreen> {
  String? _selectedDrinkingHabit; // To store the selected drinking habit
  bool _isOptionSelected = false;     // To track if an option is selected - for disabling forward button

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

              // Top Navigation Bar (No Icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), // Placeholder for alignment
                  const SizedBox(width: 48), // Spacing
                ],
              ),

              SizedBox(height: screenSize.height * 0.07),

              // Icon above Heading, Left Aligned, Black Color, Bigger Size
              Icon(
                Icons.local_bar_rounded, // Using a drinking related icon - local_bar_rounded
                color: Colors.black,      // Black icon color as requested
                size: 48,               // Increased icon size - bigger now
              ),
              SizedBox(height: screenSize.height * 0.02), // Spacing between icon and heading

              // Question Text - Left Aligned under Icon
              Text(
                "Do you drink?",
                textAlign: TextAlign.left, // Ensure text is left-aligned below icon
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.1,
                ),
              ),


              SizedBox(height: screenSize.height * 0.06),

              // Option - Yes
              _buildDrinkingOptionTile(
                screenSize: screenSize,
                title: "Yes",
                value: "yes",
              ),

              SizedBox(height: screenSize.height * 0.02),

              // Option - Sometimes
              _buildDrinkingOptionTile(
                screenSize: screenSize,
                title: "Sometimes",
                value: "sometimes",
              ),

              SizedBox(height: screenSize.height * 0.02),

              // Option - No
              _buildDrinkingOptionTile(
                screenSize: screenSize,
                title: "No",
                value: "no",
              ),

              const Spacer(),

              // Forward Button - Disabled initially, enabled on selection
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                  child: GestureDetector(
                    onTap: () {
                      if (_isOptionSelected) { // Enable navigation only if an option is selected
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Drinking Habit Selected: ${_selectedDrinkingHabit ?? 'Not selected'}",
                            ),
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SmokingScreen()) // Navigate to ReligionScreen
                        );
                      } else {
                        // Optionally show a message if button is tapped when disabled
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select an option to continue."),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isOptionSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade400, // Grey when disabled
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _isOptionSelected ? Colors.white : Colors.grey.shade600, // Grey icon when disabled
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

  Widget _buildDrinkingOptionTile({
    required Size screenSize,
    required String title,
    required String value,
  }) {
    bool isSelected = _selectedDrinkingHabit == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDrinkingHabit = value;
          _isOptionSelected = true; // Enable forward button when option selected
        });
      },
      child: Container(
        width: double.infinity, // Full width
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white, // Purple background when selected
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300, // Purple border when selected
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.05,
          vertical: screenSize.height * 0.025,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedDrinkingHabit,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedDrinkingHabit = newValue;
                  _isOptionSelected = true; // Enable forward button when radio selected as well (for robustness)
                });
              },
              fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.grey.shade500; // Default radio color
              }),
            ),
          ],
        ),
      ),
    );
  }
}
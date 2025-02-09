import 'package:dtx/views/location.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart'; // For segmented fields

class DateOfBirthScreen extends StatefulWidget {
  const DateOfBirthScreen({super.key});

  @override
  _DateOfBirthScreenState createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends State<DateOfBirthScreen> {
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

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
                SizedBox(height: screenSize.height * 0.1), // Space from the top

                // Title: What's your date of birth?
                Text(
                  "What's your date of birth?",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.08,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: screenSize.height * 0.04),

                // Date Input Fields (DD/MM/YYYY)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDateInput("DD", _dayController, 2),
                    _buildDateInput("MM", _monthController, 2),
                    _buildDateInput("YYYY", _yearController, 4),
                  ],
                ),

                SizedBox(height: screenSize.height * 0.03),

                // Helper Text
                Text(
                  "We use this to calculate the age on your profile.",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.04,
                    color: Colors.white70,
                  ),
                ),

                Spacer(),

                // Circular "Next" Button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // Validate input and proceed
                      if (_validateDob()) {
                         Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocationInputScreen())
                    );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please enter a valid date of birth!"),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: screenSize.width * 0.15,
                      height: screenSize.width * 0.15,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4), // Shadow position
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 28,
                        color: Color(0xFF8B5CF6),
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

  // Widget for individual date input fields
  Widget _buildDateInput(String hint, TextEditingController controller, int maxLength) {
    return Expanded(
      flex: maxLength == 4 ? 2 : 1, // Flex for wider fields (YYYY)
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
          counterText: "", // Remove counter below the text field
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white54, width: 2.0),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2.5),
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Function to validate the date input
  bool _validateDob() {
    final day = int.tryParse(_dayController.text) ?? 0;
    final month = int.tryParse(_monthController.text) ?? 0;
    final year = int.tryParse(_yearController.text) ?? 0;

    if (day < 1 || day > 31) return false;
    if (month < 1 || month > 12) return false;
    if (year < 1900 || year > DateTime.now().year) return false;

    return true;
  }
}

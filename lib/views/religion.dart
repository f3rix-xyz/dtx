import 'package:dtx/views/drinking.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';

class ReligionScreen extends StatefulWidget {
  const ReligionScreen({super.key});

  @override
  State<ReligionScreen> createState() => _ReligionScreenState();
}

class _ReligionScreenState extends State<ReligionScreen> {
  Religion? _selectedReligion;

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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const SizedBox(width: 48),
                ],
              ),

              SizedBox(height: screenSize.height * 0.07),

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

              Wrap(
                spacing: screenSize.width * 0.03,
                runSpacing: screenSize.height * 0.015,
                children: Religion.values.map((religion) => 
                  _buildReligionButton(religion, screenSize)).toList(),
              ),

              const Spacer(),

              Padding(
                padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Religion step skipped."),
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DrinkingScreen())
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

                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Selected Religion: ${_selectedReligion?.label ?? 'None'}",
                            ),
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DrinkingScreen())
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

  Widget _buildReligionButton(Religion religion, Size screenSize) {
    bool isSelected = _selectedReligion == religion;
    return GestureDetector(
      onTap: () => setState(() => _selectedReligion = religion),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: screenSize.height * 0.015),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              religion.label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

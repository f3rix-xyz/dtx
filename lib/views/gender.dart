import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/views/dating_intentions.dart';
import 'package:dtx/utils/app_enums.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  Gender? _selectedGender;
  bool _isVisibleOnProfile = true;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    10,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: index < 6
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.05),
              Text(
                "Which gender best\ndescribes you?",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.065,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              SizedBox(height: screenSize.height * 0.04),
              Column(
                children: Gender.values
                    .map((gender) => _buildOption(gender))
                    .toList(),
              ),
              SizedBox(height: screenSize.height * 0.04),
              GestureDetector(
                onTap: () =>
                    setState(() => _isVisibleOnProfile = !_isVisibleOnProfile),
                child: Row(
                  children: [
                    Icon(
                      _isVisibleOnProfile
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Visible on profile",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _selectedGender != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DatingIntentionsScreen(),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    width: screenSize.width * 0.15,
                    height: screenSize.width * 0.15,
                    decoration: BoxDecoration(
                      color: _selectedGender != null
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _selectedGender != null
                              ? Colors.grey.shade400
                              : Colors.transparent,
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 28,
                      color:
                          _selectedGender != null ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.04),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(Gender gender) {
    final isSelected = _selectedGender == gender;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          onTap: () => setState(() => _selectedGender = gender),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Text(
              gender.label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

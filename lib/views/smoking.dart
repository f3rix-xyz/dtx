import 'package:dtx/views/media.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';

class SmokingScreen extends StatefulWidget {
  const SmokingScreen({super.key});

  @override
  State<SmokingScreen> createState() => _SmokingScreenState();
}

class _SmokingScreenState extends State<SmokingScreen> {
  DrinkingSmokingHabits? _selectedSmokingHabit;
  bool _isOptionSelected = false;

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

              Icon(
                Icons.smoking_rooms_rounded,
                color: Colors.black,
                size: 48,
              ),
              SizedBox(height: screenSize.height * 0.02),

              Text(
                "Do you smoke?",
                textAlign: TextAlign.left,
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.1,
                ),
              ),

              SizedBox(height: screenSize.height * 0.06),

              Column(
                children: DrinkingSmokingHabits.values.map((habit) => 
                  _buildSmokingOptionTile(
                    screenSize: screenSize,
                    title: habit.label,
                    value: habit,
                  )).toList(),
              ),

              const Spacer(),

              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                  child: GestureDetector(
                    onTap: () {
                      if (_isOptionSelected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Smoking Habit Selected: ${_selectedSmokingHabit?.label ?? 'Not selected'}",
                            ),
                          ),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MediaPickerScreen())
                        );
                      } else {
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
                        color: _isOptionSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _isOptionSelected ? Colors.white : Colors.grey.shade600,
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

  Widget _buildSmokingOptionTile({
    required Size screenSize,
    required String title,
    required DrinkingSmokingHabits value,
  }) {
    bool isSelected = _selectedSmokingHabit == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSmokingHabit = value;
          _isOptionSelected = true;
        });
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
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
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            Radio<DrinkingSmokingHabits>(
              value: value,
              groupValue: _selectedSmokingHabit,
              onChanged: (DrinkingSmokingHabits? newValue) {
                setState(() {
                  _selectedSmokingHabit = newValue;
                  _isOptionSelected = true;
                });
              },
              fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.grey.shade500;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:dtx/views/height.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';

class DatingIntentionsScreen extends StatefulWidget {
  const DatingIntentionsScreen({super.key});

  @override
  State<DatingIntentionsScreen> createState() => _DatingIntentionsScreenState();
}

class _DatingIntentionsScreenState extends State<DatingIntentionsScreen> {
  DatingIntention? _selectedIntention;
  bool _isVisibleOnProfile = true;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.02),

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

            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                itemCount: DatingIntention.values.length,
                itemBuilder: (context, index) {
                  return _buildOption(DatingIntention.values[index]);
                },
              ),
            ),

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

            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                child: GestureDetector(
                  onTap: _selectedIntention != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => HeightSelectionScreen()),
                          );
                        }
                      : null,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _selectedIntention != null
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_selectedIntention != null)
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
                      color: _selectedIntention != null
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

  Widget _buildOption(DatingIntention intention) {
    final bool isSelected = _selectedIntention == intention;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIntention = intention;
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
              intention.label,
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

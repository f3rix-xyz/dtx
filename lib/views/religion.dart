// File: lib/views/religion.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/drinking.dart'; // Keep for onboarding flow

class ReligionScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const ReligionScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<ReligionScreen> createState() => _ReligionScreenState();
}

class _ReligionScreenState extends ConsumerState<ReligionScreen> {
  Religion? _selectedReligion; // Local state

  @override
  void initState() {
    super.initState();
    // Load initial value if editing
    if (widget.isEditing) {
      _selectedReligion = ref.read(userProvider).religiousBeliefs;
    }
  }

  void _handleNext() {
    if (_selectedReligion != null) {
      ref.read(userProvider.notifier).updateReligiousBeliefs(_selectedReligion);
      if (widget.isEditing) {
        print("[ReligionScreen] Editing done, popping back.");
        Navigator.of(context).pop();
      } else {
        // Original onboarding navigation
        print("[ReligionScreen] Onboarding next: Drinking.");
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const DrinkingScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // final userState = ref.watch(userProvider); // Only needed if UI depends on it dynamically

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Adjusted Header for Edit Mode ---
              Padding(
                padding: EdgeInsets.only(
                  top: screenSize.height * 0.02,
                  left: screenSize.width * 0.02,
                  right: screenSize.width * 0.06,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else // Keep placeholder for alignment in onboarding
                      const SizedBox(
                          width: 48), // Matches IconButton width approx

                    Text(
                      widget.isEditing ? "Edit Religion" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),

                    if (widget.isEditing)
                      TextButton(
                        onPressed:
                            _selectedReligion != null ? _handleNext : null,
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: _selectedReligion != null
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else // Keep placeholder for alignment in onboarding
                      const SizedBox(
                          width: 48), // Matches TextButton width approx
                  ],
                ),
              ),
              // --- End Adjusted Header ---

              SizedBox(height: screenSize.height * 0.07),
              Text(
                widget.isEditing
                    ? "Edit your religious beliefs"
                    : "What are your religious beliefs?",
                style: GoogleFonts.poppins(
                  fontSize: widget.isEditing
                      ? screenSize.width * 0.08
                      : screenSize.width * 0.1,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.1,
                ),
              ),
              SizedBox(height: screenSize.height * 0.05),
              Wrap(
                spacing: screenSize.width * 0.03,
                runSpacing: screenSize.height * 0.015,
                children: Religion.values
                    .map((religion) =>
                        _buildReligionButton(religion, screenSize))
                    .toList(),
              ),
              const Spacer(),
              // --- Hide FAB in Edit Mode ---
              if (!widget.isEditing)
                Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _selectedReligion != null ? _handleNext : null,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _selectedReligion != null
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey.shade300,
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
              // --- End Hide FAB ---
              if (widget.isEditing)
                SizedBox(
                    height:
                        screenSize.height * 0.04) // Add padding if FAB hidden
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReligionButton(Religion religion, Size screenSize) {
    bool isSelected = _selectedReligion == religion; // Use local state
    return GestureDetector(
      onTap: () =>
          setState(() => _selectedReligion = religion), // Update local state
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: screenSize.height * 0.015),
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
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

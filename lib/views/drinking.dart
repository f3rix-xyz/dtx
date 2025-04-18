// File: lib/views/drinking.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/smoking.dart'; // Keep for onboarding flow

class DrinkingScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const DrinkingScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<DrinkingScreen> createState() => _DrinkingScreenState();
}

class _DrinkingScreenState extends ConsumerState<DrinkingScreen>
    with SingleTickerProviderStateMixin {
  DrinkingSmokingHabits? _selectedDrinkingHabit; // Local state
  // Removed _isOptionSelected, use _selectedDrinkingHabit directly
  late AnimationController _controller; // Keep for animations if desired
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Load initial value if editing
    if (widget.isEditing) {
      _selectedDrinkingHabit = ref.read(userProvider).drinkingHabit;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_selectedDrinkingHabit != null) {
      ref
          .read(userProvider.notifier)
          .updateDrinkingHabit(_selectedDrinkingHabit);
      if (widget.isEditing) {
        print("[DrinkingScreen] Editing done, popping back.");
        Navigator.of(context).pop();
      } else {
        // Original onboarding navigation
        print("[DrinkingScreen] Onboarding next: Smoking.");
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const SmokingScreen()));
      }
    } else {
      // This should not happen if button is properly disabled, but as a fallback
      if (!widget.isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Please select an option", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // final userState = ref.watch(userProvider); // Only needed if UI depends on it dynamically
    final bool canProceed = _selectedDrinkingHabit != null; // Check local state

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                    else // Keep placeholder icon for onboarding
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.local_bar_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 30), // Slightly smaller icon
                      ),
                    Text(
                      widget.isEditing ? "Edit Drinking Habit" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: canProceed ? _handleNext : null,
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: canProceed
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else // Keep placeholder for onboarding
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              // --- End Adjusted Header ---

              SizedBox(height: screenSize.height * 0.03),
              Text(
                widget.isEditing
                    ? "Edit your drinking habits"
                    : "Do you drink?",
                textAlign: TextAlign.left,
                style: GoogleFonts.poppins(
                  fontSize: widget.isEditing
                      ? screenSize.width * 0.07
                      : screenSize.width * 0.08,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                  height: 1.1,
                ),
              ),
              if (!widget.isEditing) // Show subtitle only during onboarding
                Text(
                  "Select your drinking habits",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              SizedBox(height: screenSize.height * 0.04),
              Expanded(
                child: ListView.separated(
                  itemCount: DrinkingSmokingHabits.values.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final habit = DrinkingSmokingHabits.values[index];
                    return _buildDrinkingOptionTile(
                      screenSize: screenSize,
                      title: habit.label,
                      value: habit,
                    );
                  },
                ),
              ),
              // --- Hide FAB in Edit Mode ---
              if (!widget.isEditing)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                    child: AnimatedScale(
                      scale: canProceed ? 1.0 : 0.95, // Use local state
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _handleNext, // Use unified handler
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: canProceed
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: canProceed
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: canProceed
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildDrinkingOptionTile({
    required Size screenSize,
    required String title,
    required DrinkingSmokingHabits value,
  }) {
    bool isSelected = _selectedDrinkingHabit == value; // Use local state

    return AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDrinkingHabit = value; // Update local state
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: screenSize.height * 0.022,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF2D3748),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: Color(0xFF8B5CF6),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

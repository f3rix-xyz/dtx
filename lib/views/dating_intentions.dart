// File: lib/views/dating_intentions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';
import '../providers/user_provider.dart';
import 'height.dart'; // Keep for onboarding flow

class DatingIntentionsScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const DatingIntentionsScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<DatingIntentionsScreen> createState() =>
      _DatingIntentionsScreenState();
}

class _DatingIntentionsScreenState
    extends ConsumerState<DatingIntentionsScreen> {
  DatingIntention? _selectedIntention; // Local state for selection

  @override
  void initState() {
    super.initState();
    // Load current value if editing
    if (widget.isEditing) {
      _selectedIntention = ref.read(userProvider).datingIntention;
    }
  }

  void _handleNext() {
    if (_selectedIntention != null) {
      ref.read(userProvider.notifier).updateDatingIntention(_selectedIntention);
      if (widget.isEditing) {
        print("[DatingIntentionsScreen] Editing done, popping back.");
        Navigator.of(context).pop(); // Pop back to ProfileScreen
      } else {
        // Original onboarding navigation
        print("[DatingIntentionsScreen] Onboarding next: Height.");
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const HeightSelectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Watch userState only to update UI if needed externally (unlikely here)
    // final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Adjusted Header for Edit Mode ---
            Padding(
              padding: EdgeInsets.only(
                top: screenSize.height * 0.02,
                left: screenSize.width * 0.02,
                right: screenSize.width * 0.06,
              ),
              child: Row(
                mainAxisAlignment: widget.isEditing
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  if (widget.isEditing)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(
                        width:
                            40), // Placeholder for alignment during onboarding

                  Text(
                    widget.isEditing
                        ? "Edit Intention"
                        : "", // Title only in edit mode
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (widget.isEditing)
                    TextButton(
                      onPressed:
                          _selectedIntention != null ? _handleNext : null,
                      child: Text(
                        "Done",
                        style: GoogleFonts.poppins(
                          color: _selectedIntention != null
                              ? const Color(0xFF8B5CF6)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40), // Placeholder during onboarding
                ],
              ),
            ),
            // --- End Adjusted Header ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06)
                  .copyWith(
                      top: widget.isEditing
                          ? 20
                          : screenSize.height *
                              0.01), // Less top padding if editing
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isEditing) // Show title only during onboarding
                    Text(
                      "What's your dating intention?",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.065,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  SizedBox(height: widget.isEditing ? 30 : 65),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                itemCount: DatingIntention.values.length,
                itemBuilder: (context, index) {
                  return _buildOption(DatingIntention.values[index]);
                },
              ),
            ),
            // --- Hide FAB in Edit Mode ---
            if (!widget.isEditing)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                  child: GestureDetector(
                    onTap: _selectedIntention != null
                        ? _handleNext
                        : null, // Use local state
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
            // --- End Hide FAB ---
            SizedBox(height: screenSize.height * 0.04),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(DatingIntention intention) {
    final bool isSelected = _selectedIntention == intention; // Use local state

    return GestureDetector(
      onTap: () {
        setState(() {
          // Update local state
          _selectedIntention = intention;
        });
        // No need to update provider here, only on save/next
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
            Expanded(
              child: Text(
                intention.label,
                style: GoogleFonts.poppins(
                  fontSize: intention.label.length > 20 ? 14 : 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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

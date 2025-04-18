// File: lib/views/hometown.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/job.dart'; // Keep for onboarding flow

class HometownScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const HometownScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<HometownScreen> createState() => _HometownScreenState();
}

class _HometownScreenState extends ConsumerState<HometownScreen> {
  final TextEditingController _hometownController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load initial value if editing
    if (widget.isEditing) {
      _hometownController.text = ref.read(userProvider).hometown ?? '';
    }
    // Add listener to enable/disable Done button
    _hometownController.addListener(() {
      if (widget.isEditing) setState(() {});
    });
  }

  @override
  void dispose() {
    _hometownController.dispose();
    super.dispose();
  }

  void _handleNext() {
    String? hometown;
    if (_hometownController.text.trim().isNotEmpty) {
      hometown = _hometownController.text.trim();
    } else {
      hometown = null; // Explicitly set to null if empty
    }
    ref.read(userProvider.notifier).updateHometown(hometown);

    if (widget.isEditing) {
      print("[HometownScreen] Editing done, popping back.");
      Navigator.of(context).pop();
    } else {
      // Original onboarding navigation
      print("[HometownScreen] Onboarding next: Job.");
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const JobTitleScreen()));
    }
  }

  void _handleSkipOrClear() {
    FocusScope.of(context).unfocus();
    _hometownController.clear(); // Clear text field
    ref
        .read(userProvider.notifier)
        .updateHometown(null); // Update provider to null
    if (widget.isEditing) {
      print("[HometownScreen] Clearing field and popping back.");
      Navigator.of(context).pop(); // Pop back immediately after clearing
    } else {
      // Original onboarding skip navigation
      print("[HometownScreen] Skipping to Job.");
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const JobTitleScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // final userState = ref.watch(userProvider); // Only needed if UI depends on it dynamically

    // Determine if Done button should be enabled in Edit mode
    final bool canProceedEditing =
        widget.isEditing && _hometownController.text.trim().isNotEmpty;

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
                    else
                      IconButton(
                        // Keep original icon for onboarding
                        icon: const Icon(Icons.home_rounded,
                            color: Color(0xFF8B5CF6), size: 32),
                        onPressed: () {}, // No action needed here
                      ),

                    Text(
                      widget.isEditing ? "Edit Hometown" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),

                    // Show "Done" in edit mode, "Skip" in onboarding
                    if (widget.isEditing)
                      TextButton(
                        onPressed:
                            _handleNext, // Always enabled, saves empty as null
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color:
                                const Color(0xFF8B5CF6), // Always enabled color
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _handleSkipOrClear, // Use unified handler
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Skip",
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              // --- End Adjusted Header ---

              SizedBox(height: screenSize.height * 0.07),

              // Question Text
              Text(
                widget.isEditing
                    ? "Edit your hometown"
                    : "Where's your home\ntown?",
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

              // Text Field
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: screenSize.width * 0.02),
                child: TextField(
                  controller: _hometownController,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: "e.g., New Delhi",
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 22,
                      color: Colors.grey.shade500,
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                    ),
                    // Add clear button in edit mode if text exists
                    suffixIcon: widget.isEditing &&
                            _hometownController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _hometownController.clear();
                              // Optionally update provider immediately on clear
                              // ref.read(userProvider.notifier).updateHometown(null);
                            },
                          )
                        : null,
                  ),
                ),
              ),

              const Spacer(),

              // --- Hide FAB in Edit Mode ---
              if (!widget.isEditing)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: screenSize.height * 0.04),
                    child: GestureDetector(
                      onTap: _handleNext, // Always enabled for onboarding
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
}

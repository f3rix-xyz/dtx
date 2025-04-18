// File: lib/views/prompt.dart
import 'package:dtx/models/user_model.dart';
import 'package:dtx/views/audioprompt.dart'; // Keep for onboarding flow
// Removed unused audiopromptsselect import
// Removed unused media import
import 'package:dtx/views/textpromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';

class ProfileAnswersScreen extends ConsumerStatefulWidget {
  final bool isEditing; // <<< ADDED

  const ProfileAnswersScreen({
    super.key,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<ProfileAnswersScreen> createState() =>
      _ProfileAnswersScreenState();
}

class _ProfileAnswersScreenState extends ConsumerState<ProfileAnswersScreen> {
  // Removed _isForwardButtonEnabled - logic handled by checking prompt count now

  // --- No need for initState/updateForwardButtonState ---

  void _handlePromptTap(Prompt? prompt, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextSelectPromptScreen(
          editIndex: prompt != null ? index : null,
          isEditing: widget.isEditing, // <<< Pass editing flag
        ),
      ),
    ); // No need for .then() as UI updates reactively
  }

  void _handleRemovePrompt(int index) {
    // Add confirmation dialog?
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Remove Prompt?"),
        content:
            const Text("Are you sure you want to remove this prompt answer?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ref.read(userProvider.notifier).removePromptAtIndex(index);
              Navigator.pop(dialogContext);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    final prompts = ref.read(userProvider).prompts;
    // Onboarding requires at least one prompt
    if (!widget.isEditing &&
        prompts.where((p) => p.answer.trim().isNotEmpty).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please answer at least one prompt.",
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    if (widget.isEditing) {
      print("[ProfileAnswersScreen] Editing done, popping back.");
      Navigator.of(context).pop();
    } else {
      // Original onboarding navigation
      print("[ProfileAnswersScreen] Onboarding next: Audio Prompt.");
      Navigator.pushReplacement(
        // Use replacement for onboarding
        context,
        MaterialPageRoute(builder: (context) => const VoicePromptScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final userState = ref.watch(userProvider);
    final prompts = userState.prompts;
    final bool canProceed =
        prompts.where((p) => p.answer.trim().isNotEmpty).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Adjusted Header for Edit Mode ---
              Padding(
                padding: EdgeInsets.only(
                  top: screenSize.height * 0.02,
                  left: 0, // No back button needed here typically
                  right: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else // Keep placeholder for onboarding alignment
                      const SizedBox(width: 48),
                    Text(
                      widget.isEditing ? "Edit Prompts" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed:
                            _handleNext, // Always enabled for edit? Or check canProceed? Let's allow saving empty.
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8B5CF6), // Always enabled
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

              const SizedBox(height: 20), // Reduced top space
              Text(
                widget.isEditing ? "Edit Your Prompts" : "Profile Prompts",
                style: GoogleFonts.poppins(
                  fontSize: widget.isEditing
                      ? 28
                      : 36, // Slightly smaller title in edit
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isEditing
                    ? "Tap a prompt to edit or remove it."
                    : "Share three interesting facts about yourself",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final prompt =
                        index < prompts.length ? prompts[index] : null;
                    return _buildPromptCard(prompt, index);
                  },
                ),
              ),
              const SizedBox(height: 16),
              // --- Hide Bottom Bar in Edit Mode ---
              if (!widget.isEditing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "At least 1 prompt required",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    _buildForwardButton(canProceed), // Pass enabled state
                  ],
                ),
              // --- End Hide Bottom Bar ---
              SizedBox(
                  height: widget.isEditing ? 16 : 32), // Adjust bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(Prompt? prompt, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: prompt != null ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handlePromptTap(prompt, index),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prompt?.question.label ?? "Add a prompt",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: prompt != null
                              ? Colors.black87
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                    // Show Edit or Add Icon
                    Icon(
                      prompt != null
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      color: const Color(0xFF8B5CF6),
                      size: 24,
                    ),
                    // Add Remove Icon if editing and prompt exists
                    if (widget.isEditing && prompt != null) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.redAccent.withOpacity(0.7), size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "Remove Prompt",
                        onPressed: () => _handleRemovePrompt(index),
                      ),
                    ]
                  ],
                ),
                if (prompt?.answer.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    prompt!.answer,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[700], // Slightly muted answer color
                      height: 1.4,
                    ),
                    maxLines: 3, // Limit display lines
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Onboarding Forward Button
  Widget _buildForwardButton(bool isEnabled) {
    return GestureDetector(
      onTap: isEnabled ? _handleNext : null,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF8B5CF6) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: isEnabled ? Colors.white : Colors.grey.shade600,
          size: 32,
        ),
      ),
    );
  }
}

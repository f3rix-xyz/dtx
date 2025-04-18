// File: lib/views/writeprompt.dart
import 'package:dtx/utils/app_enums.dart';
// Removed unused prompt.dart import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed unused google_fonts import
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/models/user_model.dart';

class WriteAnswerScreen extends ConsumerStatefulWidget {
  final PromptCategory category;
  final PromptType question;
  final int? editIndex;
  final bool isEditing; // <<< ADDED

  const WriteAnswerScreen({
    super.key,
    required this.category,
    required this.question,
    this.editIndex,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  ConsumerState<WriteAnswerScreen> createState() => _WriteAnswerScreenState();
}

class _WriteAnswerScreenState extends ConsumerState<WriteAnswerScreen> {
  late final TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _loadExistingAnswer();

    // Add listener to update UI when text changes
    _answerController.addListener(() {
      if (mounted) {
        setState(() {}); // Trigger rebuild to enable/disable Done button
      }
    });
  }

  void _loadExistingAnswer() {
    // Load only if editing an *existing* prompt (editIndex is not null)
    if (widget.editIndex != null && widget.isEditing) {
      final prompts = ref.read(userProvider).prompts;
      if (widget.editIndex! < prompts.length) {
        // Check if the question being edited matches the passed question
        // This prevents loading the wrong answer if the user selected a different question for the same slot
        if (prompts[widget.editIndex!].question == widget.question) {
          _answerController.text = prompts[widget.editIndex!].answer;
        } else {
          print(
              "Warning: Editing index ${widget.editIndex} but question changed. Starting fresh.");
        }
      }
    }
  }

  void _saveAnswer() {
    final answerText = _answerController.text.trim();
    bool actionTaken = false; // Flag to check if any action was performed

    if (answerText.isNotEmpty) {
      final newPrompt = Prompt(
        category: widget.category,
        question: widget.question,
        answer: answerText,
      );

      int targetIndex =
          widget.editIndex ?? ref.read(userProvider).prompts.length;

      if (widget.editIndex != null &&
          widget.editIndex! < ref.read(userProvider).prompts.length) {
        ref
            .read(userProvider.notifier)
            .updatePromptAtIndex(widget.editIndex!, newPrompt);
        print("Updated prompt at index: ${widget.editIndex}");
        actionTaken = true;
      } else if (ref.read(userProvider).prompts.length < 3) {
        ref.read(userProvider.notifier).addPrompt(newPrompt);
        print("Added new prompt.");
        actionTaken = true;
      } else {
        print("Error: Cannot add prompt, maximum reached.");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can only have 3 prompts.")));
        return;
      }

      // Navigate back
      if (widget.isEditing) {
        // Pop twice for editing
        int popCount = 0;
        Navigator.of(context).popUntil((route) => popCount++ == 2);
      } else {
        // Onboarding: Pop once and signal success
        Navigator.of(context).pop(true); // <-- Signal success
      }
    } else if (widget.isEditing && widget.editIndex != null) {
      // Handle clearing existing prompt during edit
      print(
          "Removing prompt at index: ${widget.editIndex} due to empty answer.");
      ref.read(userProvider.notifier).removePromptAtIndex(widget.editIndex!);
      actionTaken = true;
      // Pop twice for editing
      int popCount = 0;
      Navigator.of(context).popUntil((route) => popCount++ == 2);
    } else if (!widget.isEditing) {
      // Don't allow saving empty prompt during onboarding if "Done" is pressed
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter an answer.")));
      return; // Stay on the screen
    }

    // If no action was taken but user pressed Done (e.g., editing non-existent index with empty text)
    if (!actionTaken) {
      // Just pop back once (likely from TextSelectPromptScreen)
      Navigator.of(context).pop(false); // Signal no change made
    }
  }

  @override
  void dispose() {
    _answerController.dispose(); // Clean up the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _answerController.text.trim().isNotEmpty;
    // Or, if clearing is allowed via Done button:
    // final bool canSave = true; // Always allow Done, handle empty in _saveAnswer

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          widget.editIndex != null && widget.isEditing
              ? 'Edit Answer'
              : 'Write Answer', // Dynamic title
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingWidth: 80,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context), // Always pop back to selection
          child: const Center(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            // Enable based on whether text is present OR if editing an existing prompt (to allow clearing)
            onPressed: canSave || (widget.isEditing && widget.editIndex != null)
                ? _saveAnswer
                : null,
            child: Text(
              'Done',
              style: TextStyle(
                // Adjust color based on combined condition
                color: canSave || (widget.isEditing && widget.editIndex != null)
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF8B5CF6).withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Wrap in SingleChildScrollView
        child: Column(
          children: [
            const SizedBox(height: 64),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    // Dynamic icon based on action
                    widget.editIndex != null && widget.isEditing
                        ? Icons.edit_note_rounded
                        : Icons.question_answer_outlined,
                    color: const Color(0xFF8B5CF6).withOpacity(0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 54),
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _answerController,
                      maxLength: 255,
                      maxLines: null, // Allows multiline input
                      minLines: 5, // Set a minimum line count
                      keyboardType: TextInputType
                          .multiline, // Explicitly set keyboard type
                      textCapitalization:
                          TextCapitalization.sentences, // Capitalize sentences
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type your answer here...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        counterText: '', // Hide the default counter
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        // Use characters method for accurate length including newlines
                        '${_answerController.text.characters.length}/255',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

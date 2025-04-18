// File: lib/views/textpromptsselect.dart
import 'package:dtx/models/user_model.dart';
import 'package:dtx/views/writeprompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:dtx/providers/user_provider.dart'; // Import UserProvider
import 'package:dtx/utils/app_enums.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts

// Change StatefulWidget to ConsumerStatefulWidget
class TextSelectPromptScreen extends ConsumerStatefulWidget {
  final int? editIndex;
  final bool isEditing;

  const TextSelectPromptScreen({
    super.key,
    this.editIndex,
    this.isEditing = false,
  });

  @override
  ConsumerState<TextSelectPromptScreen> createState() =>
      _TextSelectPromptScreenState();
}

// Change State to ConsumerState
class _TextSelectPromptScreenState
    extends ConsumerState<TextSelectPromptScreen> {
  PromptCategory selectedCategory = PromptCategory.storyTime;
  bool showAllPrompts = false;

  List<PromptType> get currentPrompts {
    if (showAllPrompts) {
      return PromptCategory.values
          .expand((category) => category.getPrompts())
          .toList();
    }
    return selectedCategory.getPrompts();
  }

  // Function to check for duplicates
  bool _isDuplicate(PromptType selectedPromptType) {
    final existingPrompts = ref.read(userProvider).prompts;
    for (int i = 0; i < existingPrompts.length; i++) {
      // Skip check if editing the current index
      if (widget.isEditing && widget.editIndex == i) {
        continue;
      }
      if (existingPrompts[i].question == selectedPromptType) {
        return true; // Found a duplicate
      }
    }
    return false; // No duplicate found
  }

  @override
  Widget build(BuildContext context) {
    // Read existing prompts to disable selected ones
    final existingPromptQuestions = ref.watch(userProvider
        .select((user) => user.prompts.map((p) => p.question).toSet()));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showAllPrompts = !showAllPrompts;
                      });
                    },
                    child: Text(
                      showAllPrompts ? 'View by Category' : 'View all',
                      style: TextStyle(
                        color: const Color(0xFF8b5cf6),
                        fontSize: 16,
                        fontWeight:
                            showAllPrompts ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Prompts', // Keep title centered
                    style: GoogleFonts.poppins(
                      // Use GoogleFonts if desired
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!showAllPrompts)
              SingleChildScrollView(
                // ... Category chips (unchanged) ...
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: PromptCategory.values.map((category) {
                    final isSelected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => selectedCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF8b5cf6)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF8b5cf6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            category.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF8b5cf6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: currentPrompts.length,
                itemBuilder: (context, index) {
                  final promptType = currentPrompts[index];
                  final bool isAlreadySelected =
                      existingPromptQuestions.contains(promptType);
                  final bool isEditingThisPrompt = widget.isEditing &&
                      widget.editIndex != null &&
                      ref.read(userProvider).prompts.length >
                          widget.editIndex! &&
                      ref
                              .read(userProvider)
                              .prompts[widget.editIndex!]
                              .question ==
                          promptType;

                  final bool isDisabled = isAlreadySelected &&
                      !isEditingThisPrompt; // Disable if selected elsewhere

                  return GestureDetector(
                    onTap: isDisabled
                        ? null
                        : () async {
                            // Make onTap async
                            final category = promptType.getCategory();
                            // Navigate and wait for result
                            final result = await Navigator.push(
                              // <-- Use await
                              context,
                              MaterialPageRoute(
                                builder: (context) => WriteAnswerScreen(
                                  category: category,
                                  question: promptType,
                                  editIndex: widget.editIndex,
                                  isEditing: widget.isEditing,
                                ),
                              ),
                            );

                            // If NOT editing and WriteAnswerScreen popped with success (true)
                            if (!widget.isEditing &&
                                result == true &&
                                context.mounted) {
                              // Pop this screen (TextSelectPromptScreen) to go back to ProfileAnswersScreen
                              Navigator.pop(context);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        promptType.label,
                        style: TextStyle(
                          fontSize: 16,
                          // Dim text if disabled
                          color: isDisabled ? Colors.grey[400] : Colors.black87,
                          // Add strike-through if disabled? (Optional)
                          // decoration: isDisabled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

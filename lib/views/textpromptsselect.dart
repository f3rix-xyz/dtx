// File: lib/views/textpromptsselect.dart
import 'package:dtx/models/user_model.dart';
import 'package:dtx/views/writeprompt.dart';
import 'package:flutter/material.dart';
// Removed unused Riverpod import
// Removed unused google_fonts import
import 'package:dtx/utils/app_enums.dart';

class TextSelectPromptScreen extends StatefulWidget {
  final int? editIndex;
  final bool isEditing; // <<< ADDED

  const TextSelectPromptScreen({
    super.key,
    this.editIndex,
    this.isEditing = false, // <<< ADDED default
  });

  @override
  State<TextSelectPromptScreen> createState() => _TextSelectPromptScreenState();
}

class _TextSelectPromptScreenState extends State<TextSelectPromptScreen> {
  PromptCategory selectedCategory = PromptCategory.storyTime;
  bool showAllPrompts = false;
  // Removed unused selectedPrompt state

  List<PromptType> get currentPrompts {
    if (showAllPrompts) {
      return PromptCategory.values
          .expand((category) => category.getPrompts())
          .toList();
    }
    return selectedCategory.getPrompts();
  }

  @override
  Widget build(BuildContext context) {
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
                      showAllPrompts
                          ? 'View by Category'
                          : 'View all', // Toggle text
                      style: TextStyle(
                        color: const Color(0xFF8b5cf6),
                        fontSize: 16,
                        fontWeight:
                            showAllPrompts ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  const Text(
                    'Prompts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pop(context), // Always pop back from here
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!showAllPrompts)
              SingleChildScrollView(
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
                  return GestureDetector(
                    onTap: () {
                      final category = promptType.getCategory();
                      // Navigate to WriteAnswerScreen, potentially replacing this one
                      // if we don't want the user coming back here after writing.
                      // Using push ensures they can come back to select a different prompt if needed.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WriteAnswerScreen(
                            category: category,
                            question: promptType,
                            editIndex: widget.editIndex,
                            isEditing:
                                widget.isEditing, // <<< Pass editing flag
                          ),
                        ),
                      );
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
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
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

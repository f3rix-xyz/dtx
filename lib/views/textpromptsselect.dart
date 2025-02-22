import 'package:dtx/models/user_model.dart';
import 'package:dtx/views/writeprompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';

class TextSelectPromptScreen extends StatefulWidget {
  final int? editIndex;

  const TextSelectPromptScreen({
    super.key,
    this.editIndex,
  });

  @override
  State<TextSelectPromptScreen> createState() => _TextSelectPromptScreenState();
}

class _TextSelectPromptScreenState extends State<TextSelectPromptScreen> {
  PromptCategory selectedCategory = PromptCategory.storyTime;
  bool showAllPrompts = false;
  PromptType? selectedPrompt;

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
                      'View all',
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
                    onTap: () => Navigator.pop(context),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WriteAnswerScreen(
                            category: category,
                            question: promptType.label,
                            editIndex: widget.editIndex,
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

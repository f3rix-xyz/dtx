import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/views/prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/models/user_model.dart';

class WriteAnswerScreen extends ConsumerStatefulWidget {
  final PromptCategory category;
  final String question;
  final int? editIndex;

  const WriteAnswerScreen({
    super.key,
    required this.category,
    required this.question,
    this.editIndex,
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
      setState(() {}); // This triggers a rebuild when text changes
    });
  }

  void _loadExistingAnswer() {
    if (widget.editIndex != null) {
      final prompts = ref.read(userProvider).prompts;
      if (widget.editIndex! < prompts.length) {
        _answerController.text = prompts[widget.editIndex!].answer;
      }
    }
  }

  void _saveAnswer() {
    if (_answerController.text.trim().isNotEmpty) {
      final newPrompt = Prompt(
        category: widget.category,
        question: widget.question,
        answer: _answerController.text.trim(),
      );

      if (widget.editIndex != null) {
        ref.read(userProvider.notifier).updatePromptAtIndex(
              widget.editIndex!,
              newPrompt,
            );
      } else {
        ref.read(userProvider.notifier).addPrompt(newPrompt);
      }

      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _answerController.dispose(); // Clean up the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Write Answer',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingWidth: 80,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
            onPressed:
                _answerController.text.trim().isNotEmpty ? _saveAnswer : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: _answerController.text.trim().isNotEmpty
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF8B5CF6).withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
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
                    widget.question,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.edit_rounded,
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
                    maxLines: null,
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
                      counterText: '',
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
                      '${_answerController.text.length}/255',
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
    );
  }
}

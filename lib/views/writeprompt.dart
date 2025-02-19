import 'package:flutter/material.dart';

class WriteAnswerScreen extends StatefulWidget {
  const WriteAnswerScreen({Key? key}) : super(key: key);

  @override
  State<WriteAnswerScreen> createState() => _WriteAnswerScreenState();
}

class _WriteAnswerScreenState extends State<WriteAnswerScreen> {
  final TextEditingController _answerController = TextEditingController();
  final String prompt = "A life goal of mine"; // Hardcoded for now

  @override
  void initState() {
    super.initState();
    _answerController.addListener(() {
      setState(() {}); // Triggers rebuild on text change
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
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
        leadingWidth: 80, // Add this to give more width to the leading section
        leading: GestureDetector(
          // Changed to GestureDetector
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
            onPressed: _answerController.text.trim().isNotEmpty
                ? () => Navigator.pop(context)
                : null, // Disable button if text field is empty
            child: Text(
              'Done',
              style: TextStyle(
                color: _answerController.text.trim().isNotEmpty
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF8B5CF6)
                        .withOpacity(0.5), // Change color if disabled
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Added top spacing
          const SizedBox(height: 64),

          // Prompt Card
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
                    prompt,
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

          // Added spacing between prompt and answer box
          const SizedBox(height: 54),

          // Input Container with fixed height
          Container(
            height: 200, // Fixed height for more squarish appearance
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
                    maxLines: null, // Allow text to scroll within container
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

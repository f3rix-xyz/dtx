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
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF8b5cf6),
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        title: const Text(
          'Write answer',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Text(
                'Done',
                style: TextStyle(
                  color: Color(0xFF8b5cf6),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.grey[800],
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: _answerController,
                    maxLength: 225,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                      hintText: 'Type your answer here...',
                      hintStyle: TextStyle(
                        color: Colors.black38,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                      counterText: '',
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Text(
                      '225',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

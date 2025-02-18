import 'package:flutter/material.dart';

class AudioSelectPromptScreen extends StatelessWidget {
  const AudioSelectPromptScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> prompts = [
      "Can we talk about?",
      "Caption this photo",
      "Caught in the act",
      "Change my mind about",
      "Choose our first date",
      "Comment if you've been here",
      "Cook with me",
      "Dating me is like",
      "Dating me will look like",
      "Do you agree or disagree that",
      "Don't hate me if I",
      "Don't judge me",
      "#MondaysAmIRight?",
      "A boundary of mine is",
      "A daily essential",
      "A dream home must include",
      "A favourite memory of mine",
      "A friend's review of me",
      "A life goal of mine",
      "A quick rant about",
      "A random fact I love is",
      "A special talent of mine",
      "A thought I recently had in the shower",
      "All I ask is that you",
      "Guess where this photo was taken",
      "Help me identify this photo bomber",
      "Hi from me and my pet",
      "How I fight the Sunday scaries",
      "How history will remember me",
      "How my friends see me",
      "How to pronounce my name",
      "I beat my blues by",
      "I bet you can't",
      "I can teach you how to",
      "I feel famous when",
      "I feel most supported when",
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select a Prompt",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: prompts.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      // Will handle selection later with provider
                      Navigator.pop(context);
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
                        prompts[index],
                        style: const TextStyle(
                          fontSize: 18,
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

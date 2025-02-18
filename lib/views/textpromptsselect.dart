import 'package:flutter/material.dart';

class TextSelectPromptScreen extends StatefulWidget {
  const TextSelectPromptScreen({Key? key}) : super(key: key);

  @override
  State<TextSelectPromptScreen> createState() => _TextSelectPromptScreenState();
}

class _TextSelectPromptScreenState extends State<TextSelectPromptScreen> {
  String selectedCategory = 'My type';
  bool showAllPrompts = false;

  final Map<String, List<String>> promptsByCategory = {
    'Story time': [
      'Two truths and a lie',
      'Worst idea I\'ve ever had',
      'Biggest risk I\'ve taken',
      'My biggest date fail',
      'Never have I ever',
      'Best travel story',
      'Weirdest gift I\'ve given or received',
      'Most spontaneous thing I\'ve done',
      'One thing I\'ll never do again',
    ],
    'My type': [
      'Something that\'s non-negotiable for me is',
      'The hallmark of a good relationship is',
      'I\'m looking for',
      'I\'m weirdly attracted to',
      'All I ask is that you',
      'We\'ll get along if',
      'I want someone who',
      'Green flags I look out for',
      'We\'re the same type of weird if',
      'I\'d fall for you if',
      'I\'ll brag about you to my friends if',
    ],
    'Getting personal': [
      'The one thing you should know about me is',
      'My Love Language is',
      'The dorkiest thing about me is',
      'Don\'t hate me if I',
      'I geek out on',
      'If loving this is wrong, I don\'t want to be right',
      'The key to my heart is',
      'I won\'t shut up about',
      'You should *not* go out with me if',
      'What if I told you that',
    ],
    'Date vibes': [
      'Together, we could',
      'First round is on me if',
      'What I order for the table',
      'I know the best spot in town for',
      'The best way to ask me out is by',
    ],
  };

  List<String> get currentPrompts {
    if (showAllPrompts) {
      return promptsByCategory.values.expand((prompts) => prompts).toList();
    }
    return promptsByCategory[selectedCategory] ?? [];
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
                  children: promptsByCategory.keys.map((category) {
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
                            category,
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
                  return Container(
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
                      currentPrompts[index],
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
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

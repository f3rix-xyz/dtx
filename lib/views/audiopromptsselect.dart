// views/audiopromptsselect.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/providers/audio_upload_provider.dart';

class AudioSelectPromptScreen extends ConsumerWidget {
  const AudioSelectPromptScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPrompt = ref.watch(audioUploadProvider.notifier).selectedPrompt;

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
                itemCount: AudioPrompt.values.length,
                itemBuilder: (context, index) {
                  final prompt = AudioPrompt.values[index];
                  final isSelected = prompt == currentPrompt;
                  
                  return GestureDetector(
                    onTap: () {
                      ref.read(audioUploadProvider.notifier).setSelectedPrompt(prompt);
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
                        color: isSelected ? const Color(0xFFEDE9FE) : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              prompt.label,
                              style: TextStyle(
                                fontSize: 18,
                                color: isSelected ? const Color(0xFF8B5CF6) : Colors.black87,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF8B5CF6),
                            ),
                        ],
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

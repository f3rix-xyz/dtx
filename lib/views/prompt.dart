import 'package:dtx/models/user_model.dart';
import 'package:dtx/views/media.dart';
import 'package:dtx/views/textpromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/providers/user_provider.dart';

class ProfileAnswersScreen extends ConsumerStatefulWidget {
  const ProfileAnswersScreen({super.key});

  @override
  ConsumerState<ProfileAnswersScreen> createState() =>
      _ProfileAnswersScreenState();
}

class _ProfileAnswersScreenState extends ConsumerState<ProfileAnswersScreen> {
  bool _isForwardButtonEnabled = false;

  void _updateForwardButtonState() {
    final userState = ref.watch(userProvider);
    final prompts = userState.prompts;
    bool hasValidPrompt =
        prompts.any((prompt) => prompt.answer.trim().isNotEmpty);
    setState(() {
      _isForwardButtonEnabled = hasValidPrompt;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateForwardButtonState();
    });
  }

  void _handlePromptTap(Prompt? prompt, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextSelectPromptScreen(
          editIndex: prompt != null ? index : null,
        ),
      ),
    ).then((_) => _updateForwardButtonState());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final userState = ref.watch(userProvider);
    final prompts = userState.prompts;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                "Profile Prompts",
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Share three interesting facts about yourself",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final prompt =
                        index < prompts.length ? prompts[index] : null;
                    return _buildPromptCard(prompt, index);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "At least 1 prompt required",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  _buildForwardButton(),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(Prompt? prompt, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: prompt != null ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handlePromptTap(prompt, index),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prompt?.question ?? "Add a prompt",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      prompt != null ? Icons.edit : Icons.add,
                      color: const Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ],
                ),
                if (prompt?.answer.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    prompt!.answer,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForwardButton() {
    return GestureDetector(
      onTap: _isForwardButtonEnabled
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MediaPickerScreen(),
                ),
              )
          : null,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: _isForwardButtonEnabled
              ? const Color(0xFF8B5CF6)
              : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: _isForwardButtonEnabled ? Colors.white : Colors.grey.shade600,
          size: 32,
        ),
      ),
    );
  }
}

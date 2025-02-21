import 'package:dtx/views/media.dart';
import 'package:dtx/views/textpromptsselect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
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
    final prompts = userState.prompts ?? [];
    int filledAnswers =
        prompts.where((prompt) => prompt.answer.isNotEmpty).length;
    setState(() {
      _isForwardButtonEnabled = filledAnswers >= 3;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateForwardButtonState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const SizedBox(width: 48),
                ],
              ),
              SizedBox(height: screenSize.height * 0.04),
              Text(
                "Write your profile answers",
                textAlign: TextAlign.left,
                style: GoogleFonts.lexendDeca(
                  fontSize: screenSize.width * 0.095,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.0,
                ),
              ),
              SizedBox(height: screenSize.height * 0.045),
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 1,
                onPromptSelected: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TextSelectPromptScreen()),
                  );
                },
              ),
              SizedBox(height: screenSize.height * 0.035),
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 2,
                onPromptSelected: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TextSelectPromptScreen()),
                  );
                },
              ),
              SizedBox(height: screenSize.height * 0.035),
              _buildPromptAnswerSection(
                screenSize: screenSize,
                promptNumber: 3,
                onPromptSelected: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TextSelectPromptScreen()),
                  );
                },
              ),
              SizedBox(height: screenSize.height * 0.04),
              Padding(
                padding: EdgeInsets.only(left: screenSize.width * 0.01),
                child: Text(
                  "3 answers required",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.04,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.03),
                  child: GestureDetector(
                    onTap: () {
                      if (_isForwardButtonEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Navigating to next screen (MediaPickerScreen)..."),
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MediaPickerScreen()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Continue to Media Selection."),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isForwardButtonEnabled
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _isForwardButtonEnabled
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptAnswerSection({
    required Size screenSize,
    required int promptNumber,
    required VoidCallback onPromptSelected,
  }) {
    final userState = ref.watch(userProvider);
    final prompt = userState.prompts?.elementAtOrNull(promptNumber - 1);

    return GestureDetector(
      onTap: onPromptSelected,
      child: DottedBorder(
        dashPattern: const [6, 3],
        color: prompt != null
            ? const Color(0xFF8B5CF6).withOpacity(0.8)
            : const Color(0xFF8B5CF6),
        strokeWidth: 2.2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(15),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.035,
            horizontal: screenSize.width * 0.04,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: screenSize.width * 0.03),
                    child: Text(
                      prompt != null
                          ? "${prompt.question.substring(0, 20)}..."
                          : "Select a Prompt",
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (prompt != null && prompt.answer.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: screenSize.width * 0.03,
                        top: 4,
                      ),
                      child: Text(
                        "${prompt.answer.substring(0, 30)}...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Icon(
                  prompt != null ? Icons.edit_rounded : Icons.add,
                  color:
                      prompt != null ? Colors.grey[600]! : Colors.grey.shade600,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

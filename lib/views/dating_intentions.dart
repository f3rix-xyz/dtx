import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dtx/utils/app_enums.dart';
import '../providers/user_provider.dart';
import 'height.dart';

class DatingIntentionsScreen extends ConsumerStatefulWidget {
  const DatingIntentionsScreen({super.key});

  @override
  ConsumerState<DatingIntentionsScreen> createState() =>
      _DatingIntentionsScreenState();
}

class _DatingIntentionsScreenState
    extends ConsumerState<DatingIntentionsScreen> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenSize.height * 0.02),
                  Text(
                    "What's your dating intention?",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.065,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 65),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                itemCount: DatingIntention.values.length,
                itemBuilder: (context, index) {
                  return _buildOption(DatingIntention.values[index]);
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
                child: GestureDetector(
                  onTap: userState.datingIntention != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => HeightSelectionScreen()),
                          );
                        }
                      : null,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: userState.datingIntention != null
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (userState.datingIntention != null)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 8,
                          ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 28,
                      color: userState.datingIntention != null
                          ? Colors.white
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.04),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(DatingIntention intention) {
    final bool isSelected =
        ref.watch(userProvider).datingIntention == intention;

    return GestureDetector(
      onTap: () {
        ref.read(userProvider.notifier).updateDatingIntention(intention);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                intention.label,
                style: GoogleFonts.poppins(
                  fontSize: intention.label.length > 20 ? 14 : 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// File: lib/widgets/reaction_emoji_picker.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReactionEmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final List<String> reactionEmojis = const [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😠'
  ];

  // --- START: Values to Tweak ---
  final double emojiSize = 16.0; // <<< TWEAK THIS: Font size of the emoji text
  final double emojiPadding =
      5.0; // <<< TWEAK THIS: Padding around each emoji inside InkWell
  final double horizontalSpacing =
      6.0; // <<< TWEAK THIS: Space between emojis horizontally
  final double verticalPadding =
      6.0; // <<< TWEAK THIS: Vertical padding inside the main container
  final double horizontalPadding =
      10.0; // <<< TWEAK THIS: Horizontal padding inside the main container
  final double borderRadius =
      18.0; // <<< TWEAK THIS: Roundness of the picker box
  // --- END: Values to Tweak ---

  const ReactionEmojiPicker({
    Key? key,
    required this.onEmojiSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("[ReactionEmojiPicker] Building picker widget.");
    return Material(
      elevation: 4.0, // Keep elevation reasonable
      borderRadius: BorderRadius.circular(borderRadius), // Use tweakable value
      color: Colors.white,
      child: Padding(
        // Use tweakable padding for the overall container
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding),
        child: Wrap(
          spacing: horizontalSpacing, // Use tweakable horizontal spacing
          runSpacing: 0.0, // Likely still 0 for a single row
          alignment: WrapAlignment.center,
          children: reactionEmojis.map((emoji) {
            return InkWell(
              onTap: () {
                print("[ReactionEmojiPicker] Emoji selected: $emoji");
                onEmojiSelected(emoji);
              },
              borderRadius: BorderRadius.circular(borderRadius - 2 > 0
                  ? borderRadius - 2
                  : borderRadius), // Slightly smaller radius for tap effect
              child: Padding(
                padding:
                    EdgeInsets.all(emojiPadding), // Use tweakable emoji padding
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: emojiSize, // Use tweakable emoji font size
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

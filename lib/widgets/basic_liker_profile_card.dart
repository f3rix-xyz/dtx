// File: widgets/basic_liker_profile_card.dart
import 'package:dtx/models/like_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

class BasicLikerProfileCard extends StatelessWidget {
  final BasicProfileLiker liker;
  final VoidCallback onTap;

  const BasicLikerProfileCard({
    super.key,
    required this.liker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = liker.likedAt != null
        ? DateFormat.yMd().add_jm().format(liker.likedAt!) // Example format
        : 'Some time ago';

    return InkWell(
      // Make the card tappable
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          children: [
            // Profile Picture Placeholder/Image
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: (liker.firstProfilePicUrl != null)
                  ? NetworkImage(liker.firstProfilePicUrl!)
                  : null,
              child: (liker.firstProfilePicUrl == null)
                  ? Icon(Icons.person, color: Colors.grey[400])
                  : null,
            ),
            const SizedBox(width: 12),
            // Name and Like Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liker.name.isNotEmpty ? liker.name : 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Liked you $timeAgo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rose/Comment Indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (liker.isRose)
                  Icon(Icons.star_rounded,
                      color: Colors.purple.shade300, size: 20),
                if (liker.likeComment != null &&
                    liker.likeComment!.isNotEmpty) ...[
                  if (liker.isRose) const SizedBox(width: 4), // Spacing if both
                  Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.blue.shade300, size: 18),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}

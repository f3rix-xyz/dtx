// File: widgets/full_liker_profile_card.dart
import 'package:dtx/models/like_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

class FullLikerProfileCard extends StatelessWidget {
  // --- FIX: Correct class name ---
  final FullProfileLiker liker;
  // --- END FIX ---
  final VoidCallback onTap;

  const FullLikerProfileCard({
    super.key,
    required this.liker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = liker.profile;
    final age = profile.age;
    final firstImage = profile.firstMediaUrl;
    final timeAgo = liker.likedAt != null
        ? DateFormat.yMd().add_jm().format(liker.likedAt!) // Example format
        : 'Some time ago';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15.0),
      child: Container(
        // Removed fixed height to allow content to define height
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          image: firstImage != null
              ? DecorationImage(
                  image: NetworkImage(firstImage),
                  fit: BoxFit.cover,
                  onError: (err, st) => print(
                      "Error loading image $firstImage: $err"), // Add error logging
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                )
              : null, // No image if null
          color: firstImage == null
              ? Colors.grey[300]
              : Colors.white, // Placeholder color or white background
        ),
        child: Stack(
          children: [
            // Placeholder Icon if no image
            if (firstImage == null)
              Center(
                  child: Icon(Icons.person, size: 60, color: Colors.grey[500])),

            // Gradient Overlay for text (only if image exists)
            if (firstImage != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15.0),
                    gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0]),
                  ),
                ),
              ),

            // Info Text
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Age
                  Text(
                    '${profile.name ?? 'Unknown User'}${age != null ? ', $age' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // Adjust text color based on background
                      color: firstImage != null ? Colors.white : Colors.black87,
                      shadows: firstImage != null
                          ? [
                              Shadow(
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.7))
                            ]
                          : [],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Like Timestamp
                  Text(
                    'Liked you $timeAgo',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: firstImage != null
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Comment Preview (if exists)
                  if (liker.likeComment != null &&
                      liker.likeComment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: firstImage != null
                                ? Colors.white.withOpacity(0.8)
                                : Colors.blue.shade300,
                            size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '"${liker.likeComment!}"',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: firstImage != null
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Rose Indicator (Top Right)
            if (liker.isRose)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star_rounded,
                      color: Colors.yellow.shade600, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

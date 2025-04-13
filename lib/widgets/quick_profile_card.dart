// File: widgets/quick_profile_card.dart
import 'package:dtx/models/feed_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickProfileCard extends StatelessWidget {
  final QuickFeedProfile profile;

  const QuickProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final age = profile.age; // Use the calculated age getter

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200], // Placeholder color
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.person_outline,
                  size: screenSize.width * 0.2,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Age (Wireframe style)
                Container(
                  height: 20, // Simulate text height
                  width: screenSize.width * 0.3, // Simulate text width
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                // Distance (Wireframe style)
                if (profile.distanceKm != null)
                  Container(
                    height: 16, // Simulate text height
                    width: screenSize.width * 0.2, // Simulate text width
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4)),
                  )
                else // Fallback if distance is null
                  Container(
                    height: 16,
                    width: screenSize.width * 0.2,
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

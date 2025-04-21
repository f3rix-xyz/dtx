// lib/widgets/match_list_tile.dart
import 'package:dtx/models/user_model.dart'; // Using UserModel as MatchUser
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchListTile extends StatelessWidget {
  final UserModel matchUser; // Use UserModel
  final VoidCallback onTap;

  const MatchListTile({
    super.key,
    required this.matchUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[200],
        backgroundImage: matchUser.firstMediaUrl != null
            ? NetworkImage(matchUser.firstMediaUrl!)
            : null,
        child: matchUser.firstMediaUrl == null
            ? Icon(Icons.person, size: 30, color: Colors.grey[400])
            : null,
      ),
      title: Text(
        matchUser.name ?? 'Unknown Match',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "Matched with you", // Replace with last message later if needed
        style: GoogleFonts.poppins(
          color: Colors.grey[600],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}

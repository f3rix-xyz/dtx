// File: lib/widgets/match_list_tile.dart
import 'package:dtx/models/user_model.dart';
import 'package:dtx/utils/date_formatter.dart'; // <-- IMPORT ADDED
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class MatchListTile extends StatelessWidget {
  final UserModel matchUser;
  final VoidCallback onTap;

  const MatchListTile({
    super.key,
    required this.matchUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // --- ADDED LOGGING ---
    if (kDebugMode) {
      print(
          "[MatchListTile build] UserID: ${matchUser.id}, Name: ${matchUser.name}, isOnline: ${matchUser.isOnline}, lastOnline: ${matchUser.lastOnline}");
    }
    // --- END LOGGING ---

    // Determine subtitle content based on status
    Widget subtitleWidget;
    if (matchUser.isOnline) {
      subtitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: Colors.green[600]),
          const SizedBox(width: 4),
          Text(
            'Online',
            style: GoogleFonts.poppins(
              color: Colors.green[700],
              fontSize: 13,
              fontWeight: FontWeight.w500, // Make 'Online' slightly bolder
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Use the formatter function
      final lastSeenText = formatLastSeen(matchUser.lastOnline, short: true);
      subtitleWidget = Text(
        lastSeenText.isNotEmpty ? 'Last seen: $lastSeenText' : '',
        // Using short format from helper
        style: GoogleFonts.poppins(
          color: Colors.grey[600],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

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
      subtitle:
          subtitleWidget, // <-- USE THE DYNAMIC SUBTITLE WIDGET CREATED ABOVE
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}

// lib/models/match_user.dart
import 'package:dtx/models/user_model.dart'; // Re-use UserModel for consistency?

// Option 1: Simple Match User (if /api/matches returns minimal data)
// class MatchUser {
//   final int id;
//   final String name;
//   final String? avatarUrl;

//   MatchUser({
//     required this.id,
//     required this.name,
//     this.avatarUrl,
//   });

//   factory MatchUser.fromJson(Map<String, dynamic> json) {
//     // Adjust keys based on your ACTUAL /api/matches response
//     return MatchUser(
//       id: json['id'] as int? ?? 0,
//       name: json['name'] as String? ?? 'Unknown Match',
//       avatarUrl: json['avatar_url'] as String?,
//     );
//   }
// }

// Option 2: Reuse UserModel (if /api/matches returns full user profiles)
// This might be slightly heavier but avoids creating a separate model if the data is similar
typedef MatchUser = UserModel; // Use UserModel as the MatchUser type

// If using Option 2, no separate fromJson is needed here,
// just ensure your repository parses the response using UserModel.fromJson

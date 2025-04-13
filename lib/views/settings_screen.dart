// File: lib/views/settings_screen.dart
import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/views/google_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showLogoutConfirmationDialog(
      BuildContext context, WidgetRef ref) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to log out?',
              style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Logout',
                  style: GoogleFonts.poppins(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close the dialog first
                await _performLogout(context, ref); // Perform logout
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    print("[SettingsScreen] Performing logout...");
    // Call the logout method from the auth provider
    await ref.read(authProvider.notifier).logout();
    print("[SettingsScreen] Logout complete. Navigating to SignInScreen.");

    // Navigate to the sign-in screen and remove all previous routes
    // Check if context is still valid before navigating
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const GoogleSignInScreen()),
        (Route<dynamic> route) => false, // Remove all routes
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for settings
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        children: [
          // Example Setting (can add more later)
          // ListTile(
          //   leading: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
          //   title: Text('Notifications', style: GoogleFonts.poppins()),
          //   trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[500]),
          //   onTap: () {
          //     // TODO: Navigate to Notification Settings
          //   },
          // ),
          // Divider(), // Separator

          // Logout Option
          ListTile(
            leading: Icon(Icons.logout_rounded, color: Colors.redAccent[200]),
            title: Text('Logout',
                style: GoogleFonts.poppins(color: Colors.redAccent[200])),
            onTap: () => _showLogoutConfirmationDialog(context, ref),
          ),
          Divider(),
        ],
      ),
    );
  }
}

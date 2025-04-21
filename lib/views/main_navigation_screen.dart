// File: lib/views/main_navigation_screen.dart
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/providers/user_provider.dart';
// *** ADDED Import ***
import 'package:dtx/views/matches_screen.dart';
// *** END ADDED ***
import 'package:dtx/views/home.dart';
import 'package:dtx/views/profile_screens.dart';
import 'package:dtx/views/who_liked_you_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed chat_screen import as we now have MatchesScreen

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  // *** UPDATED Widget List ***
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    WhoLikedYouScreen(),
    MatchesScreen(), // Changed from ChatPlaceholderScreen
    ProfileScreen(),
  ];
  // *** END UPDATE ***

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          "[MainNavigationScreen] Post-frame callback: Initiating Likes and Profile fetches if needed.");

      // Fetch Likes only if data is empty (initial load)
      final likesState = ref.read(receivedLikesProvider);
      if (likesState.fullProfiles.isEmpty &&
          likesState.otherLikers.isEmpty &&
          !likesState.isLoading) {
        print(
            "[MainNavigationScreen] Likes data is empty, calling fetchLikes.");
        ref.read(receivedLikesProvider.notifier).fetchLikes();
      } else {
        print(
            "[MainNavigationScreen] Likes data already present or loading, skipping fetchLikes call.");
      }

      // Fetch Profile only if data is missing (initial load)
      final userState = ref.read(userProvider);
      if (userState.name == null && !ref.read(userLoadingProvider)) {
        // Also check userLoadingProvider
        print(
            "[MainNavigationScreen] User profile data is empty, calling fetchProfile.");
        ref.read(userProvider.notifier).fetchProfile();
      } else {
        print(
            "[MainNavigationScreen] User profile data already present or loading, skipping fetchProfile call.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IndexedStack(
          // Use IndexedStack to preserve state of tabs
          index: _selectedIndex,
          children: _widgetOptions,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // *** UPDATED Items ***
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'Likes',
          ),
          BottomNavigationBarItem(
            // Changed icon and label for Matches/Chat
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Matches', // Changed label
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        // *** END UPDATE ***
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Keep labels visible
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 5.0,
        selectedLabelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
    );
  }
}

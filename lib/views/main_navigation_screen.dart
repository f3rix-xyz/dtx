// File: lib/views/main_navigation_screen.dart
import 'package:dtx/providers/recieved_likes_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/chat_screen.dart';
import 'package:dtx/views/home.dart';
import 'package:dtx/views/profile_screens.dart';
import 'package:dtx/views/who_liked_you_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    WhoLikedYouScreen(),
    ChatPlaceholderScreen(),
    ProfileScreen(),
  ];

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

      // --- Simplified Fetch Logic ---
      // Fetch Likes only if data is empty (initial load)
      final likesState = ref.read(receivedLikesProvider);
      if (likesState.fullProfiles.isEmpty && likesState.otherLikers.isEmpty) {
        print(
            "[MainNavigationScreen] Likes data is empty, calling fetchLikes.");
        // We don't check isLoading here, let the notifier handle it if needed.
        // Adding a direct read+call might be slightly risky if the user switches tabs
        // VERY fast, but generally okay for initial load. A safer pattern might
        // involve listening or using FutureProvider if concurrent calls are a major concern.
        ref.read(receivedLikesProvider.notifier).fetchLikes();
      } else {
        print(
            "[MainNavigationScreen] Likes data already present, skipping fetchLikes call.");
      }

      // Fetch Profile only if data is missing (initial load)
      final userState = ref.read(userProvider);
      if (userState.name == null) {
        print(
            "[MainNavigationScreen] User profile data is empty, calling fetchProfile.");
        // Same note as above regarding potential concurrency.
        ref.read(userProvider.notifier).fetchProfile();
      } else {
        print(
            "[MainNavigationScreen] User profile data already present, skipping fetchProfile call.");
      }
      // --- End Simplified Fetch Logic ---
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
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

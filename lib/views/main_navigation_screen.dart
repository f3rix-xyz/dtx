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
  int _selectedIndex = 0; // Default to Home Feed (index 0)

  // Define the pages corresponding to the navigation items
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(), // Home Feed Tab (index 0)
    WhoLikedYouScreen(), // Likes Tab (index 1)
    ChatPlaceholderScreen(), // Chat Tab (index 2)
    ProfileScreen(), // Profile Tab (index 3)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Optionally trigger fetches when a tab is selected for the first time
    // or if data is considered stale, but initial load is handled in initState.
  }

  @override
  void initState() {
    super.initState();
    // Initiate later data loads when MainNavigationScreen is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("[MainNavigationScreen] Initiating Likes and Profile fetches.");
      // Check if fetches are already in progress or data exists to avoid redundant calls
      if (ref.read(receivedLikesProvider).fullProfiles.isEmpty &&
          ref.read(receivedLikesProvider).otherLikers.isEmpty &&
          !ref.read(receivedLikesProvider).isLoading) {
        ref.read(receivedLikesProvider.notifier).fetchLikes();
      }
      if (ref.read(userProvider).name == null &&
          !ref.read(userLoadingProvider)) {
        ref.read(userProvider.notifier).fetchProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Display the selected page
        child: IndexedStack(
          // Use IndexedStack to keep state of pages
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
        selectedItemColor: const Color(0xFF8B5CF6), // Theme color for selected
        unselectedItemColor: Colors.grey[600], // Grey for unselected
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        showUnselectedLabels: true, // Show labels for unselected items
        backgroundColor: Colors.white, // Background color of the bar
        elevation: 5.0, // Add some shadow
        selectedLabelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
    );
  }
}

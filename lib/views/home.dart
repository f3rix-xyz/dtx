import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  double _angle = 0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      // Reduced angle factor for more subtle rotation
      _angle = (_dragOffset.dx / 50).clamp(-0.3, 0.3);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_dragOffset.dx.abs() > screenWidth * 0.4) {
      // Swipe completed
      setState(() {
        _dragOffset = Offset.zero;
        _angle = 0;
      });
    } else {
      // Return to center
      setState(() {
        _dragOffset = Offset.zero;
        _angle = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.local_fire_department),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Swipeable Card Area
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Transform.translate(
                    offset: _dragOffset,
                    child: Transform(
                      // Set transform origin to bottom center
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateZ(_angle)
                        ..translate(0.0, 0.0, 0.0),
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Card(
                          margin: const EdgeInsets.all(16),
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Profile Image Section
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Profile Image
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft,
                                            colors: [
                                              Colors.purple.shade200,
                                              Colors.blue.shade200,
                                            ],
                                          ),
                                        ),
                                        child: const Icon(Icons.person,
                                            size: 100, color: Colors.white),
                                      ),

                                      // Gradient Overlay
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: 240,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.8),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Profile Info Overlay
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Name and Age
                                            const Row(
                                              children: [
                                                Text(
                                                  'Sarah',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  '25',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 28,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Job & Location
                                            Row(
                                              children: [
                                                Icon(Icons.work,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Software Developer',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Icon(Icons.location_on,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '5 miles away',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Interests
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _buildInterestChip('Travel'),
                                                _buildInterestChip(
                                                    'Photography'),
                                                _buildInterestChip('Cooking'),
                                                _buildInterestChip('Reading'),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Bio
                                            Text(
                                              'Coffee enthusiast. Adventure seeker. Book lover. Looking for someone to share adventures with! 🌟',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.close, Colors.red),
                  _buildActionButton(Icons.star, Colors.blue),
                  _buildActionButton(Icons.favorite, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

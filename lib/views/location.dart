// File: views/location.dart
import 'package:dtx/models/error_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_settings/app_settings.dart'; // Keep for opening settings
import '../providers/location_provider.dart';
import '../providers/error_provider.dart';
import '../providers/user_provider.dart'; // Ensure user provider is imported
import 'gender.dart'; // Ensure GenderSelectionScreen is imported

class LocationInputScreen extends ConsumerStatefulWidget {
  const LocationInputScreen({super.key});

  @override
  ConsumerState<LocationInputScreen> createState() =>
      _LocationInputScreenState();
}

class _LocationInputScreenState extends ConsumerState<LocationInputScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Fetch location after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only fetch if location isn't already valid in the user state
      // This prevents unnecessary fetches if the user navigates back and forth
      if (!ref.read(userProvider.notifier).isLocationValid()) {
        print("[LocationInputScreen] Initial location fetch triggered.");
        ref.read(locationProvider.notifier).fetchCurrentLocation();
      } else {
        print(
            "[LocationInputScreen] Skipping initial fetch, location already set.");
        // Ensure the map moves to the existing location if needed
        _moveToCurrentLocation();
      }
    });
  }

  void _onMapReady() {
    print("[LocationInputScreen] Map Ready.");
    // It might be safer to set map ready state in the provider
    // ref.read(locationProvider.notifier).setMapReady(true);
    _moveToCurrentLocation();
  }

  void _moveToCurrentLocation() {
    final locationState = ref.read(locationProvider);
    final userLocation =
        ref.read(userProvider); // Get location from user provider

    // Use user provider's location if valid, otherwise use location provider's state
    final LatLng targetLocation = LatLng(
      userLocation.latitude ?? locationState.latitude,
      userLocation.longitude ?? locationState.longitude,
    );

    print("[LocationInputScreen] Moving map to: $targetLocation");
    // Check if mapController is initialized and ready
    // Note: FlutterMap doesn't have a direct 'isReady' flag accessible here easily.
    // We rely on onMapReady having been called implicitly before this might be needed.
    // A small delay could be a workaround if needed, but usually direct call is fine.
    try {
      _mapController.move(targetLocation, _mapController.camera.zoom);
    } catch (e) {
      print(
          "[LocationInputScreen] Error moving map (potentially before ready): $e");
      // Optionally, schedule the move again slightly later
      // Future.delayed(Duration(milliseconds: 100), () => _moveToCurrentLocation());
    }
  }

  // Dialog for location services disabled
  Future<void> _showLocationServiceDialog() async {
    // Prevent showing multiple dialogs
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      print("[LocationInputScreen] Showing Location Service Dialog.");
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          // Use different context name
          return AlertDialog(
            title: Text('Location Services Required',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(
                      'To show you relevant places around you, we need access to your location.',
                      style: GoogleFonts.poppins()),
                  const SizedBox(height: 15),
                  Text(
                      'Please enable location services in your device settings.',
                      style: GoogleFonts.poppins()),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Open Settings',
                    style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6))),
                onPressed: () {
                  Navigator.pop(dialogContext); // Use dialogContext
                  ref.read(locationProvider.notifier).openLocationSettings();
                },
              ),
              TextButton(
                child: Text('Retry',
                    style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6))),
                onPressed: () {
                  Navigator.pop(dialogContext); // Use dialogContext
                  ref.read(errorProvider.notifier).clearError();
                  ref.read(locationProvider.notifier).fetchCurrentLocation();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Listen to location provider for map center and loading state
    final locationState = ref.watch(locationProvider);
    // Listen to user provider for the marker position (the confirmed location)
    final userState = ref.watch(userProvider);
    final error = ref.watch(errorProvider);

    // Use user's location for the marker if available, otherwise default
    final markerLatLng = LatLng(userState.latitude ?? locationState.latitude,
        userState.longitude ?? locationState.longitude);

    // Show location service dialog if needed after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (error?.type == ErrorType.locationService) {
        _showLocationServiceDialog();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white, // Use a clean white background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.04),
              // Progress Indicator (Optional) - Can use a step indicator if preferred
              // Center(child: Text("Step 1 of X", style: GoogleFonts.poppins(color: Colors.grey))),

              SizedBox(height: screenSize.height * 0.03),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: const Color(0xFF8B5CF6), // Themed icon color
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Where do you live?",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A), // Darker text color
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Drag the map to set your approximate location. Only your general area will be shown.",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.04,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              Expanded(
                child: locationState.isLoading && !userState.isLocationValid()
                    ? const Center(
                        child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ))
                    : ClipRRect(
                        // Use ClipRRect for rounded corners
                        borderRadius: BorderRadius.circular(15.0),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                markerLatLng, // Start centered on user/default
                            initialZoom: 14.0,
                            onMapReady: _onMapReady,
                            // Update location provider AND user provider on tap/drag end
                            onTap: (tapPosition, latlng) {
                              print(
                                  "[LocationInputScreen] Map Tapped: $latlng");
                              ref
                                  .read(locationProvider.notifier)
                                  .updateLocation(
                                      latlng.latitude, latlng.longitude);
                            },
                            // Optional: Update on position changed (can be laggy)
                            // onPositionChanged: (position, hasGesture) {
                            //   if (hasGesture) {
                            //     final center = position.center;
                            //     if (center != null) {
                            //       ref.read(locationProvider.notifier)
                            //          .updateLocation(center.latitude, center.longitude);
                            //     }
                            //   }
                            // },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              // Use standard OSM tiles
                              userAgentPackageName:
                                  'com.peeple.dating', // Replace with your app's package name
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point:
                                      markerLatLng, // Marker follows user's selected location
                                  width: 50, // Slightly larger marker
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_pin, // Use a pin icon
                                    color: Color(0xFF8B5CF6),
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                            // Add a button to re-center on fetched location
                            if (locationState.cachedLatitude != null &&
                                locationState.cachedLongitude != null)
                              Positioned(
                                bottom:
                                    80, // Position above the main next button
                                right: 16,
                                child: FloatingActionButton.small(
                                  // Smaller FAB
                                  heroTag: 'recenter_fab', // Unique heroTag
                                  onPressed: () {
                                    print(
                                        "[LocationInputScreen] Recenter button pressed.");
                                    ref
                                        .read(locationProvider.notifier)
                                        .useCachedLocation();
                                    // Move map after state updates
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => _moveToCurrentLocation());
                                  },
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  child: Icon(
                                      locationState.isFetching
                                          ? Icons
                                              .location_searching // Indicate fetching
                                          : Icons.my_location,
                                      color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              // Show error messages from ErrorProvider
              if (error != null &&
                  error.type !=
                      ErrorType
                          .locationService) // Don't show non-service errors here if dialog handles it
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    error.message,
                    style: GoogleFonts.poppins(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Next Button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 16.0), // Add some bottom padding
                  child: FloatingActionButton(
                    heroTag: 'next_fab', // Unique heroTag
                    onPressed: userState
                            .isLocationValid() // Enable only if location is set
                        ? () {
                            print(
                                "[LocationInputScreen] Next button pressed. Navigating to Gender.");
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const GenderSelectionScreen()));
                          }
                        : null, // Disable button if location is not valid
                    backgroundColor: userState.isLocationValid()
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              SizedBox(
                  height: screenSize.height * 0.02), // Adjust bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Avoid potential errors if _mapController wasn't initialized
    // _mapController?.dispose(); // No need to dispose MapController typically
    super.dispose();
  }
}

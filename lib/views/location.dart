import 'package:dtx/views/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart'; // Import app_settings package

class LocationInputScreen extends StatefulWidget {
  const LocationInputScreen({super.key});

  @override
  State<LocationInputScreen> createState() => _LocationInputScreenState();
}

class _LocationInputScreenState extends State<LocationInputScreen> {
  late final MapController _mapController;
  LatLng _currentLocation = const LatLng(19.2183, 73.0864); // Default location
  bool _isLoading = true; // Track initial loading state
  bool _isMapReady = false; // Track if the map is ready
  bool _isFetchingLocation = false; // Track FAB loading state
  LatLng? _cachedLocation; // Store the cached location

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchCurrentLocation(); // Fetch the current location on startup
  }

  // Handle map readiness
  void _onMapReady() {
    setState(() => _isMapReady = true);
    _moveToCurrentLocation(); // Move to current location once map is ready
  }

  // Safely move the map only if ready
  void _moveToCurrentLocation() {
    if (_isMapReady) {
      _mapController.move(
        _currentLocation,
        _mapController.camera.zoom,
      );
    }
  }

  // Function to show a dialog prompting user to enable location services
  Future<void> _showLocationServiceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Location Services Required',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'To show you relevant places around you, we need access to your location.',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 15),
                Text(
                  'Please enable location services in your device settings.',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Open Settings',
                style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6)),
              ),
              onPressed: () async { // Make onPressed async
                try {
                  await AppSettings.openAppSettings(type: AppSettingsType.location); // Call the settings function
                } catch (e) {
                  // Print any error that occurs during opening settings
                  debugPrint("Error opening location settings: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Could not open settings. Please open manually.")),
                  );
                }
              },
            ),
            TextButton(
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _fetchCurrentLocation();
              },
            ),
          ],
        );
      },
    );
  }

  // Fetch the user's current location (only once)
  Future<void> _fetchCurrentLocation() async {
    if (_cachedLocation != null) {
      // Use cached location if available
      setState(() {
        _currentLocation = _cachedLocation!;
        _isLoading = false;
      });
      _moveToCurrentLocation();
      return;
    }

    setState(() => _isFetchingLocation = true);
    setState(() => _isLoading = true); // Start loading when fetching starts

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false); // Stop loading if service is disabled
        await _showLocationServiceDialog(); // Show dialog to enable location
        return; // Stop further location fetching for now, retry will happen after dialog action
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false); // Stop loading if permission is denied
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied.")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false); // Stop loading if permission is denied forever
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied.")),
        );
        return;
      }

      // Fetch the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cache the location
      _cachedLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = _cachedLocation!;
        _isLoading = false; // Stop loading after successful fetch
      });

      _moveToCurrentLocation();
    } catch (e) {
      setState(() => _isLoading = false); // Stop loading in case of error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching location: $e")),
      );
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // Relocate to cached location instantly
  void _relocateToCachedLocation() {
    if (_cachedLocation != null) {
      setState(() => _currentLocation = _cachedLocation!);
      _moveToCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.04),

              // Progress Bar (dots)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    10,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index < 5
                            ? const Color(0xFF8B5CF6)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.03),

              // Title and subtitle
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Where do you live?",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Only the neighbourhood name will appear on your profile.",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.04,
                  color: Colors.grey.shade600,
                ),
              ),

              SizedBox(height: screenSize.height * 0.03),

              // Map Widget with floating button positioned over it
              Expanded(
                child: !_isLoading
                    ? Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _currentLocation,
                                initialZoom: 14.0,
                                onTap: (tapPosition, latlng) {
                                  setState(() => _currentLocation = latlng);
                                },
                                onMapReady: _onMapReady,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _currentLocation,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFF8B5CF6),
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Floating Action Button for instant relocation
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton(
                              onPressed: _relocateToCachedLocation,
                              backgroundColor: const Color(0xFF8B5CF6),
                              child: Icon(
                                  _isFetchingLocation ? Icons.location_searching : Icons.my_location, // Change icon based on loading state
                                  color: Colors.white
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
              ),

              SizedBox(height: screenSize.height * 0.02),

              // Next Button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GenderSelectionScreen())
                    );
                  },
                  child: Container(
                    width: screenSize.width * 0.15,
                    height: screenSize.width * 0.15,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:dtx/views/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

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

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied.")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
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
        _isLoading = false;
      });

      _moveToCurrentLocation();
    } catch (e) {
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
                              child: const Icon(Icons.my_location, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6),
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
                    MaterialPageRoute(builder: (context) => GenderSelectionScreen())
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
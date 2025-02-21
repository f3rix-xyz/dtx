import 'package:dtx/models/error_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/location_provider.dart';
import '../providers/error_provider.dart';
import 'gender.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).fetchCurrentLocation();
    });
  }

  void _onMapReady() {
    ref.read(locationProvider.notifier).setMapReady(true);
    _moveToCurrentLocation();
  }

  void _moveToCurrentLocation() {
    final locationState = ref.read(locationProvider);
    if (locationState.isMapReady) {
      _mapController.move(
        LatLng(locationState.latitude, locationState.longitude),
        _mapController.camera.zoom,
      );
    }
  }

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
              onPressed: () {
                Navigator.pop(context);
                ref.read(locationProvider.notifier).openLocationSettings();
              },
            ),
            TextButton(
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ref.read(errorProvider.notifier).clearError();
                ref.read(locationProvider.notifier).fetchCurrentLocation();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final locationState = ref.watch(locationProvider);
    final error = ref.watch(errorProvider);

    // Show location service dialog if needed
    if (error?.type == ErrorType.locationService) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationServiceDialog();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.04),
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
              Expanded(
                child: !locationState.isLoading
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
                                initialCenter: LatLng(locationState.latitude,
                                    locationState.longitude),
                                initialZoom: 14.0,
                                onTap: (tapPosition, latlng) {
                                  ref
                                      .read(locationProvider.notifier)
                                      .updateLocation(
                                        latlng.latitude,
                                        latlng.longitude,
                                      );
                                },
                                onMapReady: _onMapReady,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(locationState.latitude,
                                          locationState.longitude),
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
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton(
                              onPressed: () => ref
                                  .read(locationProvider.notifier)
                                  .useCachedLocation(),
                              backgroundColor: const Color(0xFF8B5CF6),
                              child: Icon(
                                  locationState.isFetching
                                      ? Icons.location_searching
                                      : Icons.my_location,
                                  color: Colors.white),
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
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const GenderSelectionScreen()));
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

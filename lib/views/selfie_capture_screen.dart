// File: views/selfie_capture_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:dtx/providers/media_upload_provider.dart';
import 'package:dtx/views/verification_pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelfieCaptureScreen extends ConsumerStatefulWidget {
  const SelfieCaptureScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends ConsumerState<SelfieCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _hasError = false;
  double _aspectRatio = 1.0;
  bool _isUploading = false; // Track uploading state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras available');

      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      final previewSize = _cameraController!.value.previewSize!;
      _aspectRatio = previewSize.width / previewSize.height;

      if (mounted) setState(() => _isCameraInitialized = true);
      
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
      print('Camera Error: $e');
    }
  }

  Widget _buildCameraPreview() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 50),
            const SizedBox(height: 20),
            Text(
              'Camera Error',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: CameraPreview(_cameraController!),
    );
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      setState(() => _isUploading = true);

      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path);

      // Set verification image in provider
      ref.read(mediaUploadProvider.notifier).setVerificationImage(imageFile);

      // Upload verification image
      final success = await ref.read(mediaUploadProvider.notifier).uploadVerificationImage();

      setState(() => _isUploading = false);

      if (success) {
        // Navigate to verification pending screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const VerificationPendingScreen()),
          );
        }
      } else {
        // Handle upload failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload verification image. Please try again.')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      print('Capture Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture Error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Take Selfie",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildCameraPreview(),
                ),
              ],
            ),

            // Loading indicator overlay
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: !_isUploading ? FloatingActionButton(
        backgroundColor: const Color(0xFF8B5CF6),
        onPressed: _captureImage,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

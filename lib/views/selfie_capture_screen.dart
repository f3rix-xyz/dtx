import 'dart:async';
import 'dart:io';
import 'package:dtx/views/verification_pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';

class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({Key? key}) : super(key: key);

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _hasError = false;
  double _aspectRatio = 1.0;

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen camera preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF8B5CF6),
                onPressed: _captureImage,
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      final image = await _cameraController!.takePicture();
      // Handle navigation to next screen with the captured image
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPendingScreen(
            selfieImage: File(image.path),
          ),
        ),
      );
    } catch (e) {
      print('Capture Error: $e');
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
        child: Column(
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
      ),
    );
  }
}

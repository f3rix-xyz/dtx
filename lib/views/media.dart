// File: lib/views/media.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/media_upload_provider.dart'; // Keep for potential size checks?
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/prompt.dart'; // Keep for onboarding flow
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:dotted_border/dotted_border.dart';
import '../models/error_model.dart'; // Keep

// Wrapper class remains the same
class EditableMediaItem {
  final String? url;
  final File? file;
  final MediaType type;
  final UniqueKey key;

  EditableMediaItem({
    this.url,
    this.file,
    required this.type,
    required this.key,
  }) : assert(
            url != null || file != null, 'Either url or file must be provided');

  bool get isNewFile => file != null;
  String get displayIdentifier => url ?? file!.path; // Use path for new files
}

class MediaPickerScreen extends ConsumerStatefulWidget {
  final bool isEditing;

  const MediaPickerScreen({
    super.key,
    this.isEditing = false,
  });

  @override
  ConsumerState<MediaPickerScreen> createState() => _MediaPickerState();
}

class _MediaPickerState extends ConsumerState<MediaPickerScreen> {
  late List<EditableMediaItem?> _editableMedia;
  bool _isForwardButtonEnabled = false;
  bool _mediaHasChanged = false;

  // Allowed types (keep as before)
  final Set<String> _allowedImageMime = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/jpg'
  };
  final Set<String> _allowedVideoMime = {
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/mpeg',
    'video/3gpp',
    'video/mp2t'
  };
  final Set<String> _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'tiff'
  };
  final Set<String> _allowedVideoExtensions = {
    'mp4',
    'mov',
    'avi',
    'mpeg',
    'mpg',
    '3gp',
    'ts',
    'mkv'
  };

  @override
  void initState() {
    super.initState();
    _initializeMedia();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateForwardButtonState());
  }

  void _initializeMedia() {
    _editableMedia = List.filled(6, null);
    if (widget.isEditing) {
      final currentUrls = ref.read(userProvider).mediaUrls ?? [];
      for (int i = 0; i < currentUrls.length && i < 6; i++) {
        final url = currentUrls[i];
        final isVideo = url.toLowerCase().endsWith('.mp4') ||
            url.toLowerCase().endsWith('.mov');
        _editableMedia[i] = EditableMediaItem(
          url: url,
          type: isVideo ? MediaType.video : MediaType.image,
          key: UniqueKey(),
        );
      }
    }
    // Ensure list has 6 elements
    while (_editableMedia.length < 6) {
      _editableMedia.add(null);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickMedia(int index) async {
    ref.read(errorProvider.notifier).clearError();
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media != null) {
      final mimeType = media.mimeType?.toLowerCase();
      final extension = media.path.split('.').last.toLowerCase();
      final filePath = media.path.replaceFirst('file://', '');
      final file = File(filePath);

      final isValidImage = _allowedImageMime.contains(mimeType) ||
          _allowedImageExtensions.contains(extension);
      final isValidVideo = _allowedVideoMime.contains(mimeType) ||
          _allowedVideoExtensions.contains(extension);
      final fileSize = await file.length();
      final isImage = isValidImage;
      final isVideo = isValidVideo;

      if (isImage && fileSize > 10 * 1024 * 1024) {
        ref.read(errorProvider.notifier).setError(
            AppError.validation("Image is too large. Maximum size is 10 MB."));
        _clearSlot(index);
        return;
      }
      if (isVideo && fileSize > 50 * 1024 * 1024) {
        ref.read(errorProvider.notifier).setError(
            AppError.validation("Video is too large. Maximum size is 50 MB."));
        _clearSlot(index);
        return;
      }
      if (index == 0 && !isValidImage) {
        await _showErrorDialog(context, isMainImage: true);
        _clearSlot(index);
        return;
      }
      if (!isValidImage && !isValidVideo) {
        await _showErrorDialog(context);
        _clearSlot(index);
        return;
      }

      setState(() {
        _editableMedia[index] = EditableMediaItem(
          file: file,
          type: isVideo ? MediaType.video : MediaType.image,
          key: UniqueKey(),
        );
        _mediaHasChanged = true;
        _updateForwardButtonState();
      });
    }
  }

  void _clearSlot(int index) {
    // Prevent clearing main photo if <= 3 items
    final currentCount = _countSelectedMedia();
    if (index == 0 && currentCount <= 3 && _editableMedia[index] != null) {
      ref.read(errorProvider.notifier).setError(AppError.validation(
          "Cannot remove the main photo when less than 3 items are present."));
      return;
    }
    // Prevent clearing any item if it would result in less than 3 items remaining
    if (_editableMedia[index] != null && currentCount <= 3) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("Minimum of 3 media items required."));
      return;
    }
    setState(() {
      _editableMedia[index] = null;
      _mediaHasChanged = true;
      _updateForwardButtonState();
    });
  }

  Future<void> _showErrorDialog(BuildContext context,
      {bool isMainImage = false}) async {
    // ... (same as before) ...
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMainImage ? 'Invalid Main Image' : 'Invalid File Type'),
        content: Text(isMainImage
            ? 'Main image must be an image file.\nAllowed formats: JPG, JPEG, PNG, GIF, WEBP, BMP, TIFF'
            : 'Allowed formats:\n• Images: JPG, JPEG, PNG, GIF, WEBP, BMP, TIFF\n• Videos: MP4, MOV, AVI, MPEG, 3GP, TS, MKV'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _reorderMedia(int oldGridIndex, int newGridIndex) {
    if (oldGridIndex == 0 || newGridIndex == 0) return;
    setState(() {
      final EditableMediaItem? item = _editableMedia.removeAt(oldGridIndex);
      if (item != null) {
        _editableMedia.insert(newGridIndex, item);
        _mediaHasChanged = true;
      } else {
        _editableMedia.insert(newGridIndex, null);
      }
      while (_editableMedia.length > 6) {
        _editableMedia.removeLast();
      }
      while (_editableMedia.length < 6) {
        _editableMedia.add(null);
      }
      _updateForwardButtonState();
    });
  }

  int _countSelectedMedia() {
    return _editableMedia.where((item) => item != null).length;
  }

  void _updateForwardButtonState() {
    int selectedCount = _countSelectedMedia();
    setState(() {
      _isForwardButtonEnabled = selectedCount >= 3;
    });
  }

  void _handleDone() {
    if (!_isForwardButtonEnabled) return;

    // --- *** CORE CHANGE for EDITING *** ---
    if (widget.isEditing) {
      // Create the list of strings (URLs or local paths)
      final List<String> finalMediaIdentifiers = _editableMedia
          .where((item) => item != null)
          .map((item) => item!.displayIdentifier) // Use url or file path
          .toList();

      // Update the user provider directly with this mixed list
      ref.read(userProvider.notifier).updateMediaUrls(finalMediaIdentifiers);

      // Set the flag if changes were made
      if (_mediaHasChanged) {
        ref.read(userProvider.notifier).setMediaChangedFlag(true);
      }
      print("[MediaPickerScreen Edit] Updated provider. Popping back.");
      Navigator.of(context).pop(); // Pop back to ProfileScreen
    } else {
      // --- ONBOARDING Flow (remains the same conceptually) ---
      final List<File> filesToUpload = _editableMedia
          .where((item) => item?.isNewFile == true)
          .map((item) => item!.file!)
          .toList();

      if (filesToUpload.isEmpty) {
        print(
            "[MediaPickerScreen Onboarding] No files selected? Navigating anyway.");
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const ProfileAnswersScreen()));
        return;
      }

      final uploadNotifier = ref.read(mediaUploadProvider.notifier);
      // Create a temporary list matching the desired order
      List<File?> orderedFilesForUpload = List.filled(6, null);
      for (int i = 0; i < _editableMedia.length; i++) {
        if (_editableMedia[i]?.isNewFile == true) {
          orderedFilesForUpload[i] = _editableMedia[i]!.file;
        }
      }
      // Set the files in the provider
      for (int i = 0; i < orderedFilesForUpload.length; i++) {
        if (orderedFilesForUpload[i] != null) {
          uploadNotifier.setMediaFile(i, orderedFilesForUpload[i]!);
        } else {
          // uploadNotifier.removeMedia(i); // If provider needs explicit removal
        }
      }
      print(
          "[MediaPickerScreen Onboarding] Files set in provider. Navigating to Prompts.");
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const ProfileAnswersScreen()));
      // --- End ONBOARDING Flow ---
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method remains the same, header and bottom bar logic unchanged) ...
    final errorState = ref.watch(errorProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Lighter background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Adjusted Header for Edit Mode ---
              Padding(
                padding: EdgeInsets.only(
                  top: screenSize.height * 0.02,
                  left: screenSize.width * 0.02,
                  right: screenSize.width * 0.06,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.photo_library_rounded,
                            color: const Color(0xFF8B5CF6), size: 30),
                      ),
                    Text(
                      widget.isEditing ? "Edit Media" : "",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: _isForwardButtonEnabled ? _handleDone : null,
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: _isForwardButtonEnabled
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              // --- End Adjusted Header ---
              SizedBox(height: screenSize.height * 0.02),
              Text(
                widget.isEditing
                    ? "Manage Your Gallery"
                    : "Create Your Gallery",
                style: GoogleFonts.poppins(
                  fontSize: widget.isEditing
                      ? screenSize.width * 0.07
                      : screenSize.width * 0.08,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                widget.isEditing
                    ? "Add, remove, or reorder photos/videos (min 3)"
                    : "Select at least 3 photos or videos",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.04,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ReorderableGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: List.generate(_editableMedia.length,
                        (index) => _buildMediaPlaceholder(index)),
                    onReorder: _reorderMedia,
                  ),
                ),
              ),
              if (errorState != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      errorState.message,
                      style:
                          GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              // --- Hide Bottom Bar in Edit Mode ---
              if (!widget.isEditing)
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: screenSize.height * 0.02,
                    horizontal: screenSize.width * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_countSelectedMedia()}/6 Selected",
                            style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                          Text(
                            "Minimum 3 required",
                            style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _handleDone,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _isForwardButtonEnabled
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: _isForwardButtonEnabled
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: _isForwardButtonEnabled
                                ? Colors.white
                                : Colors.grey[500],
                            size: 28,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              // --- End Hide Bottom Bar ---
              SizedBox(height: widget.isEditing ? 0 : screenSize.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  // --- Placeholder builder remains the same conceptually ---
  Widget _buildMediaPlaceholder(int index) {
    final item = _editableMedia[index];
    return GestureDetector(
      key: item?.key ?? ValueKey('empty_$index'),
      onTap: () => _pickMedia(index),
      child: DottedBorder(
        dashPattern: const [6, 3],
        color: index == 0
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF8B5CF6).withOpacity(0.6),
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.isNewFile
                      ? (item.type == MediaType.image
                          ? Image.file(item.file!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: Icon(Icons.videocam_outlined,
                                      color: Colors.grey, size: 40))))
                      : (item.type == MediaType.image
                          ? Image.network(item.url!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image))
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: Icon(Icons.videocam_outlined,
                                      color: Colors.grey, size: 40)))),
                ),
              if (item == null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        index == 0
                            ? Icons.add_photo_alternate_rounded
                            : Icons.add_rounded,
                        color: const Color(0xFF8B5CF6).withOpacity(0.6),
                        size: 36,
                      ),
                      if (index == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text("Main Photo",
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ),
                    ],
                  ),
                ),
              if (item?.type == MediaType.video)
                const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white70, size: 48),
                ),
              if (widget.isEditing && item != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _clearSlot(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum MediaType { image, video } // Keep enum

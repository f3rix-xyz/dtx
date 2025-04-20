// File: lib/views/media.dart
import 'dart:io';
import 'dart:typed_data'; // Keep if thumbnail generation is used (not shown, but possible)
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/media_upload_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/views/prompt.dart'; // Keep for onboarding flow
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p; // Use prefix for path
import 'package:mime/mime.dart'; // Use mime package

import '../models/error_model.dart';
import '../models/media_upload_model.dart'; // Import MediaUploadModel

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
  // Holds String URLs for existing media, MediaUploadModel for new/local files, or null for empty slots.
  List<dynamic> _displayItems = List.filled(6, null);
  bool _isInitialized = false; // Track initialization

  // Keep allowed types
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMedia());
  }

  // *** --- START FIX: Modified Initialization Logic --- ***
  void _initializeMedia() {
    if (_isInitialized && !widget.isEditing)
      return; // Prevent re-init on onboarding if already done
    // Allow re-initialization if entering edit mode again
    print(
        "[MediaPickerScreen] Initializing Media (isEditing: ${widget.isEditing})...");

    final mediaUploadNotifier = ref.read(mediaUploadProvider.notifier);
    final currentUser = ref.read(userProvider);

    // Clear the mediaUploadProvider state ONLY when entering the screen.
    // It tracks *unsaved* local file selections made during THIS session.
    mediaUploadNotifier.state = List.filled(6, null);
    print("[MediaPickerScreen] Cleared mediaUploadProvider state.");

    List<dynamic> tempDisplayItems =
        List.filled(6, null); // Use local temp list

    // Populate based on current user state (URLs or local paths from previous edits)
    final currentIdentifiers = currentUser.mediaUrls ?? [];
    print(
        "[MediaPickerScreen] Populating from userProvider identifiers: $currentIdentifiers");

    for (int i = 0; i < currentIdentifiers.length && i < 6; i++) {
      final identifier = currentIdentifiers[i];
      if (identifier.isNotEmpty) {
        // 1. Check if it's an HTTP URL
        if (identifier.startsWith('http')) {
          tempDisplayItems[i] = identifier; // Store the URL string
          print("  - Slot $i: Existing URL: $identifier");
        }
        // 2. Check if it's a potentially valid local file path
        else if (identifier.contains('/') || identifier.contains('\\')) {
          try {
            final file = File(identifier);
            // IMPORTANT: We cannot call file.exists() synchronously here.
            // Assume if it's a path stored previously, it *was* valid.
            // We'll create a MediaUploadModel optimistically. If the file is
            // deleted later, the UI build (_buildMediaPlaceholder) will handle the error.

            final fileName = p.basename(file.path);
            final mimeType = lookupMimeType(file.path) ??
                'application/octet-stream'; // Default MIME

            tempDisplayItems[i] = MediaUploadModel(
                file: file,
                fileName: fileName,
                fileType: mimeType,
                status: UploadStatus.idle // Local files are initially idle
                );
            print(
                "  - Slot $i: Local File Path (from previous edit): $identifier");
          } catch (e) {
            print(
                "  - Slot $i: Error processing potential path '$identifier': $e. Treating as empty.");
            tempDisplayItems[i] = null;
          }
        }
        // 3. Otherwise, treat as invalid/empty
        else {
          print(
              "  - Slot $i: Invalid identifier '$identifier'. Treating as empty.");
          tempDisplayItems[i] = null;
        }
      }
    }

    // Update local state for UI building
    setState(() {
      _displayItems = tempDisplayItems; // Use the populated temp list
      _isInitialized = true;
      _updateForwardButtonState(); // Update button based on initial state
    });
    print(
        "[MediaPickerScreen] Initialization complete. Display Items: ${_displayItems.map((item) {
      if (item is MediaUploadModel) return "File: ${item.fileName}";
      if (item is String)
        return "URL: ${item.substring(item.length - 10)}"; // Show end of URL
      return 'null';
    }).toList()}");
  }
  // *** --- END FIX --- ***

  @override
  void dispose() {
    super.dispose();
  }

  // *** --- START FIX: Modified _pickMedia --- ***
  Future<void> _pickMedia(int index) async {
    ref.read(errorProvider.notifier).clearError();
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media != null) {
      final mimeType = media.mimeType?.toLowerCase();
      final fileName = p.basename(media.path);
      final extension =
          p.extension(media.path).toLowerCase().replaceAll('.', '');
      final filePath = media.path.replaceFirst('file://', '');
      final file = File(filePath);

      // Validation...
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
        // Don't clear slot here, let validation prevent update below
        return;
      }
      if (isVideo && fileSize > 50 * 1024 * 1024) {
        ref.read(errorProvider.notifier).setError(
            AppError.validation("Video is too large. Maximum size is 50 MB."));
        return;
      }
      // --- End Basic Validation ---

      // --- First Item Image Validation (using temp state) ---
      final tempDisplayItems = List.from(_displayItems);
      final potentialNewModel = MediaUploadModel(
          file: file,
          fileName: fileName,
          fileType: mimeType ?? (isVideo ? 'video/mp4' : 'image/jpeg'));
      tempDisplayItems[index] =
          potentialNewModel; // Simulate adding the new file

      final firstItem = tempDisplayItems[0];
      bool firstIsImage = false;
      if (firstItem is MediaUploadModel) {
        firstIsImage = firstItem.fileType.startsWith('image/');
      } else if (firstItem is String) {
        final lowerUrl = firstItem.toLowerCase();
        firstIsImage = [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.tiff'
        ].any((ext) => lowerUrl.endsWith(ext));
      }

      if (index == 0 && !firstIsImage) {
        await _showErrorDialog(context, isMainImage: true);
        return; // Prevent update if first item isn't image
      }
      // --- End First Item Validation ---

      if (!isValidImage && !isValidVideo) {
        await _showErrorDialog(context);
        return;
      }
      // --- End Format Validation ---

      // If all validations pass, create the final model
      final newModel = MediaUploadModel(
          file: file,
          fileName: fileName,
          fileType: mimeType ??
              (isVideo ? 'video/mp4' : 'image/jpeg'), // Provide fallback MIME
          status: UploadStatus.idle // Initial status
          );

      // Update provider state (only holds NEW files selected in *this* session)
      // Need to copy current provider state and update the specific index
      final currentProviderState =
          List<MediaUploadModel?>.from(ref.read(mediaUploadProvider));
      currentProviderState[index] = newModel;
      ref.read(mediaUploadProvider.notifier).state = currentProviderState;
      print(
          "[MediaPickerScreen] Updated mediaUploadProvider at index $index with ${newModel.fileName}");

      // Update local display state for UI
      setState(() {
        _displayItems[index] = newModel; // Update the display list directly
        _updateForwardButtonState();
      });
      // Signal change if editing
      if (widget.isEditing) {
        ref.read(userProvider.notifier).setMediaChangedFlag(true);
      }
    }
  }
  // *** --- END FIX --- ***

  // *** --- START FIX: Modified _clearSlot --- ***
  void _clearSlot(int index) {
    // Count selected based on the local display list
    final currentCount = _displayItems.where((item) => item != null).length;

    // --- Minimum Items Validation ---
    // Check if clearing this slot would result in less than 3 items
    bool wouldBeLessThanMin =
        (_displayItems[index] != null && currentCount <= 3);
    if (wouldBeLessThanMin) {
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("Minimum of 3 media items required."));
      return;
    }
    // --- End Minimum Items Validation ---

    // --- First Item Image Validation ---
    // Simulate state after clearing to check if first item is still valid
    final tempDisplayItems = List.from(_displayItems);
    tempDisplayItems[index] = null; // Simulate removal

    final firstItemAfterClear = tempDisplayItems[0];
    bool firstIsImageAfterClear = false;
    if (firstItemAfterClear is MediaUploadModel) {
      firstIsImageAfterClear =
          firstItemAfterClear.fileType.startsWith('image/');
    } else if (firstItemAfterClear is String) {
      final lowerUrl = firstItemAfterClear.toLowerCase();
      firstIsImageAfterClear = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
        '.tiff'
      ].any((ext) => lowerUrl.endsWith(ext));
    }

    // If clearing the first item AND there are other items left,
    // but the new first item isn't an image, prevent clearing.
    if (index == 0 && currentCount > 1 && !firstIsImageAfterClear) {
      ref.read(errorProvider.notifier).setError(AppError.validation(
          "Cannot remove the main photo if the next item is not a photo. Reorder first."));
      return;
    }
    // --- End First Item Validation ---

    // --- If validations pass, proceed with clearing ---
    ref.read(errorProvider.notifier).clearError(); // Clear any previous error

    // Check if the item being cleared was a NEWLY added local file in this session
    final itemToClear = _displayItems[index];
    if (itemToClear is MediaUploadModel) {
      // If it was a local file selected in THIS session, remove it from the mediaUploadProvider
      final currentProviderState =
          List<MediaUploadModel?>.from(ref.read(mediaUploadProvider));
      if (index < currentProviderState.length) {
        // Safety check
        currentProviderState[index] = null; // Clear slot in provider state
        ref.read(mediaUploadProvider.notifier).state = currentProviderState;
        print(
            "[MediaPickerScreen] Cleared slot $index in mediaUploadProvider.");
      }
    } else {
      print(
          "[MediaPickerScreen] Cleared slot $index which contained an existing URL or was empty.");
    }

    // Update local state for UI
    setState(() {
      _displayItems[index] = null; // Clear the local display slot
      _updateForwardButtonState();
    });
    // Signal change if editing
    if (widget.isEditing) {
      ref.read(userProvider.notifier).setMediaChangedFlag(true);
    }
  }
  // *** --- END FIX --- ***

  Future<void> _showErrorDialog(BuildContext context,
      {bool isMainImage = false}) async {
    // (Keep as is)
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

  // *** --- START FIX: Modified _reorderMedia --- ***
  void _reorderMedia(int oldGridIndex, int newGridIndex) {
    ref.read(errorProvider.notifier).clearError(); // Clear previous errors

    // Create a mutable copy of the local display list
    List<dynamic> reorderedDisplayItems = List.from(_displayItems);
    final item = reorderedDisplayItems.removeAt(oldGridIndex);
    reorderedDisplayItems.insert(newGridIndex, item);

    // --- VALIDATION: Ensure first slot is an image AFTER reorder ---
    final firstItem = reorderedDisplayItems[0];
    bool firstIsImage = false;
    if (firstItem is MediaUploadModel) {
      firstIsImage = firstItem.fileType.startsWith('image/');
    } else if (firstItem is String) {
      final lowerUrl = firstItem.toLowerCase();
      firstIsImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff']
          .any((ext) => lowerUrl.endsWith(ext));
    }

    if (firstItem == null || !firstIsImage) {
      // Also check if first item is null
      ref
          .read(errorProvider.notifier)
          .setError(AppError.validation("The first item must be a photo."));
      // Do NOT update state if invalid
      return;
    }
    // --- End Validation ---

    // Update local state for UI
    setState(() {
      _displayItems = reorderedDisplayItems;
      _updateForwardButtonState();
    });

    // --- Update mediaUploadProvider state ---
    // Reconstruct the provider state to match the new order,
    // containing only the MediaUploadModels (representing NEW files).
    List<MediaUploadModel?> newProviderState = List.filled(6, null);
    for (int i = 0; i < reorderedDisplayItems.length; i++) {
      if (reorderedDisplayItems[i] is MediaUploadModel) {
        newProviderState[i] = reorderedDisplayItems[i] as MediaUploadModel;
      }
    }
    ref.read(mediaUploadProvider.notifier).state = newProviderState;
    print("[MediaPickerScreen] Reordered. Updated mediaUploadProvider state.");
    // --- End Provider State Update ---

    // Signal change if editing
    if (widget.isEditing) {
      ref.read(userProvider.notifier).setMediaChangedFlag(true);
    }
  }
  // *** --- END FIX --- ***

  // Count selected based on local display list
  int _countSelectedMedia() {
    return _displayItems.where((item) => item != null).length;
  }

  // Update button state based on local display list
  void _updateForwardButtonState() {
    // No need to call setState here as this is called within setState blocks elsewhere
    // Logic to determine button state is moved to the build method.
  }

  // *** --- START FIX: Modified _handleDone --- ***
  void _handleDone() {
    final currentCount = _countSelectedMedia(); // Use local count
    final errorNotifier = ref.read(errorProvider.notifier)..clearError();

    // Validate minimum items
    if (currentCount < 3) {
      errorNotifier
          .setError(AppError.validation("Minimum 3 media items required."));
      return;
    }

    // Validate first item is image (check local display list)
    final firstItem = _displayItems[0];
    bool firstIsImage = false;
    if (firstItem is MediaUploadModel) {
      firstIsImage = firstItem.fileType.startsWith('image/');
    } else if (firstItem is String) {
      final lowerUrl = firstItem.toLowerCase();
      firstIsImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff']
          .any((ext) => lowerUrl.endsWith(ext));
    }

    if (firstItem == null || !firstIsImage) {
      // Check for null as well
      errorNotifier
          .setError(AppError.validation("The first item must be a photo."));
      return;
    }

    // If editing, update user provider state with local file paths/URLs
    if (widget.isEditing) {
      List<String> identifiers = [];
      for (final item in _displayItems) {
        // Iterate through local display list
        if (item is MediaUploadModel) {
          identifiers.add(item.file.path); // Add local path
        } else if (item is String) {
          identifiers.add(item); // Add existing URL
        }
        // Null items are skipped, resulting in potentially fewer than 6 items in the final list
      }

      // Update user provider with the final list of identifiers
      ref.read(userProvider.notifier).updateMediaUrls(identifiers);
      // If any local file was picked/reordered/cleared, this flag should be true
      ref
          .read(userProvider.notifier)
          .setMediaChangedFlag(true); // Ensure flag is set if changes were made
      print(
          "[MediaPickerScreen Edit] Updated userProvider state with identifiers: $identifiers. Popping back.");
      Navigator.of(context).pop();
    } else {
      // --- ONBOARDING Flow ---
      // Provider state (mediaUploadProvider) already holds the MediaUploadModels.
      // No further action needed here before navigation.
      print(
          "[MediaPickerScreen Onboarding] Files ready in provider. Navigating to Prompts.");
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const ProfileAnswersScreen()));
      // --- End ONBOARDING Flow ---
    }
  }
  // *** --- END FIX --- ***

  @override
  Widget build(BuildContext context) {
    // Watch provider only for errors, maybe? Grid uses local state.
    // final providerState = ref.watch(mediaUploadProvider); // Less relevant now
    final errorState = ref.watch(errorProvider);
    final screenSize = MediaQuery.of(context).size;

    // Calculate enabled state within build using local list
    final int selectedCount = _countSelectedMedia();
    bool firstIsImage = true;
    final firstItem = _displayItems[0]; // Check local list
    if (firstItem is MediaUploadModel) {
      firstIsImage = firstItem.fileType.startsWith('image/');
    } else if (firstItem is String) {
      final lowerUrl = firstItem.toLowerCase();
      firstIsImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff']
          .any((ext) => lowerUrl.endsWith(ext));
    } else {
      firstIsImage = false; // Cannot proceed if first slot is null
    }

    final bool isForwardButtonEnabled = selectedCount >= 3 && firstIsImage;

    // Show loading if not initialized yet
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Lighter background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header (keep as is) ---
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
                        onPressed: isForwardButtonEnabled ? _handleDone : null,
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            color: isForwardButtonEnabled
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
                    childAspectRatio: 0.95, // Adjust aspect ratio if needed
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    // *** FIX: Use _displayItems.length ***
                    children: List.generate(_displayItems.length,
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
              // --- Bottom Bar (keep as is) ---
              if (!widget.isEditing)
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: screenSize.height * 0.02,
                    horizontal: screenSize.width * 0.04,
                  ),
                  margin:
                      const EdgeInsets.only(top: 10), // Add margin if needed
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
                            "${selectedCount}/6 Selected",
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
                        onTap: isForwardButtonEnabled
                            ? _handleDone
                            : null, // Use calculated state
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isForwardButtonEnabled
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: isForwardButtonEnabled
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
                            color: isForwardButtonEnabled
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
              SizedBox(
                  height: widget.isEditing
                      ? 16
                      : screenSize.height * 0.02), // Adjusted bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // *** --- START FIX: Modified _buildMediaPlaceholder --- ***
  Widget _buildMediaPlaceholder(int index) {
    final item = _displayItems[index]; // Read from local display list
    final key = ValueKey(item is String
        ? item
        : (item as MediaUploadModel?)?.file.path ?? 'empty_$index');

    bool isVideo = false;
    bool isImage = false;
    Widget imageWidget = Container(); // Default empty

    if (item is MediaUploadModel) {
      final file = item.file;
      final mimeType = item.fileType;
      isImage = mimeType.startsWith('image/');
      isVideo = mimeType.startsWith('video/');
      if (isImage) {
        imageWidget = Image.file(file, fit: BoxFit.cover,
            errorBuilder: (_, error, stack) {
          print("Error loading local file ${file.path}: $error");
          return const Icon(Icons.broken_image);
        });
      } else if (isVideo) {
        imageWidget = Container(
            color: Colors.grey[300],
            child: const Center(
                child: Icon(Icons.videocam_outlined,
                    color: Colors.grey, size: 40)));
      }
    } else if (item is String && item.startsWith('http')) {
      final lowerUrl = item.toLowerCase();
      isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff']
          .any((ext) => lowerUrl.endsWith(ext));
      isVideo = ['.mp4', '.mov', '.avi', '.mpeg', '.mpg', '.3gp', '.ts', '.mkv']
          .any((ext) => lowerUrl.endsWith(ext));
      if (isImage) {
        imageWidget = Image.network(item,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, prog) => prog == null
                ? child
                : Center(
                    child: CircularProgressIndicator(
                        value: prog.expectedTotalBytes != null
                            ? prog.cumulativeBytesLoaded /
                                prog.expectedTotalBytes!
                            : null,
                        color: Colors.grey[400])),
            errorBuilder: (ctx, err, st) {
              print("Error loading network image $item: $err");
              return Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: Colors.grey[400], size: 40));
            });
      } else if (isVideo) {
        imageWidget = Container(
            color: Colors.grey[300],
            child: const Center(
                child: Icon(Icons.videocam_outlined,
                    color: Colors.grey, size: 40)));
      }
    }

    return GestureDetector(
      key: key, // Use the generated key
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
              if (item != null) // Show image/video placeholder if item exists
                ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageWidget),

              if (item == null) // Show Add icon if slot is empty
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
              if (isVideo) // Show video overlay if it's a video
                const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white70, size: 48),
                ),
              // Show remove button if item exists (local or remote)
              if (item != null)
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
  // *** --- END FIX --- ***
}

enum MediaType { image, video }

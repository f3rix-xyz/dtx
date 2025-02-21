import 'dart:io';
import 'dart:typed_data';
import 'package:dtx/views/religion.dart';
import 'package:dtx/views/prompt.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart'; // Updated package
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:get_thumbnail_video/index.dart'; // NEW import

class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPickerScreen> {
  late List<MediaFile> _selectedMedia;
  late List<UniqueKey> _itemKeys;
  bool _isForwardButtonEnabled = false;
  final _thumbnailCache = <String, Uint8List>{};

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
    _selectedMedia = List.generate(
        6, (index) => MediaFile(file: null, type: MediaType.image));
    _itemKeys = List.generate(6, (index) => UniqueKey());
  }

  @override
  void dispose() {
    _thumbnailCache.clear();
    super.dispose();
  }

  Future<void> _pickMedia(int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media != null) {
      final mimeType = media.mimeType?.toLowerCase();
      final extension = media.path.split('.').last.toLowerCase();
      final filePath = media.path.replaceFirst('file://', '');

      final isValidImage = _allowedImageMime.contains(mimeType) ||
          _allowedImageExtensions.contains(extension);

      final isValidVideo = _allowedVideoMime.contains(mimeType) ||
          _allowedVideoExtensions.contains(extension);

      if (index == 0 && !isValidImage) {
        await _showErrorDialog(context, isMainImage: true);
        _clearInvalidInput(index);
        return;
      }

      if (!isValidImage && !isValidVideo) {
        await _showErrorDialog(context);
        _clearInvalidInput(index);
        return;
      }

      setState(() {
        _selectedMedia[index] = MediaFile(
          file: File(filePath),
          type: isValidVideo ? MediaType.video : MediaType.image,
        );
        _updateForwardButtonState();
      });
    }
  }

  Future<void> _showErrorDialog(BuildContext context,
      {bool isMainImage = false}) async {
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

  void _clearInvalidInput(int index) {
    setState(() {
      _selectedMedia[index] = MediaFile(file: null, type: MediaType.image);
      _updateForwardButtonState();
    });
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    if (oldIndex == 0 || newIndex == 0) return;

    setState(() {
      final MediaFile item = _selectedMedia.removeAt(oldIndex);
      final UniqueKey key = _itemKeys.removeAt(oldIndex);

      if (oldIndex < newIndex) newIndex -= 1;

      _selectedMedia.insert(newIndex, item);
      _itemKeys.insert(newIndex, key);
    });
  }

  void _updateForwardButtonState() {
    int selectedCount =
        _selectedMedia.where((media) => media.file != null).length;
    setState(() {
      _isForwardButtonEnabled = selectedCount >= 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Lighter background
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              // Enhanced header section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: const Color(0xFF8B5CF6),
                  size: 48,
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              // Enhanced title
              Text(
                "Create Your Gallery",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.08,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              // Enhanced subtitle
              Text(
                "Select at least 3 photos or videos",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.04,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              // Enhanced grid view
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
                    children: List.generate(
                        6, (index) => _buildMediaPlaceholder(index)),
                    onReorder: _reorderMedia,
                  ),
                ),
              ),
              // Enhanced bottom section
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
                          "${_selectedMedia.where((media) => media.file != null).length}/6 Selected",
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
                    // Enhanced forward button
                    GestureDetector(
                      onTap: () {
                        if (_isForwardButtonEnabled) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfileAnswersScreen(),
                            ),
                          );
                        }
                      },
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
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(int index) {
    final media = _selectedMedia[index];
    return GestureDetector(
      key: _itemKeys[index],
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
              if (media.file != null)
                media.type == MediaType.image
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          media.file!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : VideoThumbnailWidget(
                        file: media.file!,
                        cache: _thumbnailCache,
                      ),
              if (media.file == null)
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
                          child: Text(
                            "Main Photo",
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              if (media.type == MediaType.video && media.file != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              if (media.type == MediaType.video && media.file != null)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaFile {
  final File? file;
  final MediaType type;

  MediaFile({this.file, required this.type});
}

enum MediaType { image, video }

class VideoThumbnailWidget extends StatefulWidget {
  final File file;
  final Map<String, Uint8List> cache;

  const VideoThumbnailWidget({
    super.key,
    required this.file,
    required this.cache,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final filePath = widget.file.path;
    if (widget.cache.containsKey(filePath)) {
      setState(() {
        _thumbnail = widget.cache[filePath];
      });
      return;
    }

    final thumbnail = await VideoThumbnail.thumbnailData(
      video: filePath,
      quality: 100,
    );

    if (thumbnail != null) {
      widget.cache[filePath] = thumbnail;
      setState(() {
        _thumbnail = thumbnail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _thumbnail != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _thumbnail!,
              fit: BoxFit.cover,
            ),
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }
}

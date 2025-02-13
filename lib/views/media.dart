import 'dart:io';
import 'package:dtx/views/religion.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:dotted_border/dotted_border.dart';

class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPickerScreen> {
  late List<MediaFile> _selectedMedia;
  late List<UniqueKey> _itemKeys;
  bool _isForwardButtonEnabled = false;

  final Set<String> _allowedImageMime = {
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/jpg'
  };
  
  final Set<String> _allowedVideoMime = {
    'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/mpeg', 
    'video/3gpp', 'video/mp2t'
  };

  final Set<String> _allowedImageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'
  };

  final Set<String> _allowedVideoExtensions = {
    'mp4', 'mov', 'avi', 'mpeg', 'mpg', '3gp', 'ts', 'mkv'
  };

  @override
  void initState() {
    super.initState();
    _selectedMedia = List.generate(6, (index) => MediaFile(file: null, type: MediaType.image));
    _itemKeys = List.generate(6, (index) => UniqueKey());
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

  Future<void> _showErrorDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid File Type'),
        content: const Text('Allowed formats:\n'
            '• Images: JPG, JPEG, PNG, GIF, WEBP, BMP, TIFF\n'
            '• Videos: MP4, MOV, AVI, MPEG, 3GP, TS, MKV'),
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
    // Prevent reordering if either oldIndex or newIndex is 0
    if (oldIndex == 0 || newIndex == 0) {
      return; // Exit without making any changes
    }

    setState(() {
      final MediaFile item = _selectedMedia.removeAt(oldIndex);
      final UniqueKey key = _itemKeys.removeAt(oldIndex);
      
      // Adjust newIndex to account for removal
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      _selectedMedia.insert(newIndex, item);
      _itemKeys.insert(newIndex, key);
    });
  }

  void _updateForwardButtonState() {
    int selectedCount = _selectedMedia.where((media) => media.file != null).length;
    setState(() {
      _isForwardButtonEnabled = selectedCount >= 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.02),
              Icon(
                Icons.image,
                color: const Color(0xFF8B5CF6),
                size: 56,
              ),
              SizedBox(height: screenSize.height * 0.015),
              Text(
                "Pick your videos and photos",
                style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.09,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                  height: 1.1,
                ),
              ),
              SizedBox(height: screenSize.height * 0.05),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.01),
                  child: ReorderableGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: List.generate(6, (index) => _buildMediaPlaceholder(index)),
                    onReorder: _reorderMedia,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: screenSize.height * 0.02),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Minimum 3 required",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.035,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_isForwardButtonEnabled) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReligionScreen(),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: _isForwardButtonEnabled 
                              ? const Color(0xFF8B5CF6) 
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: _isForwardButtonEnabled 
                              ? Colors.white 
                              : Colors.grey.shade600,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            ? const Color(0xFF8B5CF6).withOpacity(0.8)
            : const Color(0xFF8B5CF6),
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: index == 0 
                ? Colors.white.withOpacity(0.95)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (media.file != null)
                media.type == MediaType.image
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          media.file!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : VideoThumbnail(file: media.file!),
              if (media.file == null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                      if (index == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Main image",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  media.file == null ? Icons.add_circle : Icons.edit,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              if (media.type == MediaType.video)
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoThumbnail extends StatefulWidget {
  final File file;

  const VideoThumbnail({super.key, required this.file});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!_isDisposed) {
          setState(() {});
        }
      });
    _controller.setLooping(true);
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller.dispose();
      _initializeController();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _controller.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8B5CF6),
              strokeWidth: 2,
            ),
          );
        }
      },
    );
  }
}

enum MediaType { image, video }

class MediaFile {
  final File? file;
  final MediaType type;

  MediaFile({required this.file, required this.type});
}


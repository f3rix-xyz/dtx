// File: lib/views/chat_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/matches_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/repositories/like_repository.dart';
import 'package:dtx/repositories/media_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/services/chat_service.dart';
import 'package:dtx/utils/app_enums.dart';
import 'package:dtx/utils/date_formatter.dart';
import 'package:dtx/widgets/message_bubble.dart';
import 'package:dtx/widgets/report_reason_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
// --- Phase 1 & 2 Imports ---
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
// --- End Imports ---

class ChatDetailScreen extends ConsumerStatefulWidget {
  final int matchUserId;
  final String matchName;
  final String? matchAvatarUrl;

  const ChatDetailScreen({
    super.key,
    required this.matchUserId,
    required this.matchName,
    this.matchAvatarUrl,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isUploadingMedia = false;
  bool _isInteracting = false;

  // --- Phase 1: Recording State ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;
  final int _maxRecordingDuration = 60; // Max 60 seconds
  // --- End Recording State ---

  // --- File Type Constants (Keep as is) ---
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024;
  static const int _maxAudioSizeBytes =
      10 * 1024 * 1024; // Adjusted for consistency
  static const int _maxFileSizeBytes = 25 * 1024 * 1024;
  static final Set<String> _allowedMimeTypes = {
    // Images
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    // Videos
    'video/mp4', 'video/quicktime', 'video/webm', 'video/x-msvideo',
    'video/mpeg',
    // Audio
    'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/aac', 'audio/opus',
    'audio/webm', 'audio/mp4', 'audio/x-m4a',
    'audio/m4a', // Ensure m4a is allowed
    // Documents
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
  };

  @override
  void initState() {
    super.initState();
    if (kDebugMode)
      print("[ChatDetailScreen Init: ${widget.matchUserId}] Initializing...");
    _inputFocusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
        if (kDebugMode)
          print(
              "[ChatDetailScreen Init: ${widget.matchUserId}] Connecting WebSocket...");
        chatService.connect();
      }
      // Fetch initial state which includes status
      ref
          .read(conversationProvider(widget.matchUserId).notifier)
          .fetchMessages();
    });
  }

  @override
  void dispose() {
    if (kDebugMode)
      print("[ChatDetailScreen Dispose: ${widget.matchUserId}] Disposing...");
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_handleFocusChange);
    _inputFocusNode.dispose();
    // --- Dispose Recorder and Timer ---
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    // --- End Dispose ---
    super.dispose();
  }

  void _handleFocusChange() {}

  // --- _readHeaderBytes (Keep as is) ---
  Future<Uint8List?> _readHeaderBytes(File file, [int length = 1024]) async {
    try {
      final stream = file.openRead(0, length);
      final completer = Completer<Uint8List>();
      final bytesBuilder = BytesBuilder();
      stream.listen(
        (chunk) => bytesBuilder.add(chunk),
        onDone: () => completer.complete(bytesBuilder.toBytes()),
        onError: (error) => completer.completeError(error),
        cancelOnError: true,
      );
      return await completer.future;
    } catch (e) {
      if (kDebugMode) print("Error reading header bytes: $e");
      return null;
    }
  }

  // --- MODIFIED: _sendMessage ---
  void _sendMessage() {
    // --- Add check: Don't send if recording ---
    if (_isRecording) return;
    // --- End check ---
    final text = _messageController.text.trim();
    if (text.isEmpty || _isUploadingMedia || _isInteracting) return;

    final chatService = ref.read(chatServiceProvider);
    final wsState = ref.read(webSocketStateProvider);
    final conversationState =
        ref.read(conversationProvider(widget.matchUserId));
    final replyingTo = conversationState.replyingToMessage;

    if (wsState == WebSocketConnectionState.connected) {
      if (kDebugMode)
        print(
            "[ChatDetailScreen _sendMessage] Sending text. Replying to: ${replyingTo?.messageID}");
      chatService.sendMessage(
        widget.matchUserId,
        text: text,
        replyToMessageId: replyingTo?.messageID,
      );

      _messageController.clear();
      ref.read(messageInputProvider.notifier).state = false;
    } else {
      _showErrorSnackbar("Cannot send message. Not connected.");
      chatService.connect();
    }
  }
  // --- END MODIFIED ---

  // --- _scrollToBottom, _showAttachmentOptions, _handleFileSelection, _handleMediaSelection (Keep as is) ---
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      if (kDebugMode)
        print(
            "[ChatDetailScreen Scroll: ${widget.matchUserId}] Animating scroll to top (0.0)");
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      if (kDebugMode)
        print(
            "[ChatDetailScreen Scroll: ${widget.matchUserId}] Cannot scroll, no clients.");
    }
  }

  void _showAttachmentOptions() {
    if (_isUploadingMedia || _isInteracting || _isRecording)
      return; // Added recording check
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: Color(0xFF8B5CF6)),
                title: Text('Take Photo/Video', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _handleMediaSelection(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF8B5CF6)),
                title:
                    Text('Choose from Gallery', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _handleMediaSelection(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded,
                    color: Color(0xFF8B5CF6)),
                title: Text('Choose File', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleFileSelection() async {
    if (_isUploadingMedia || _isInteracting || _isRecording)
      return; // Added recording check
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        final fileName = result.files.single.name;
        final fileSize = await file.length();
        final headerBytes = await _readHeaderBytes(file);
        String? mimeType = lookupMimeType(filePath, headerBytes: headerBytes) ??
            lookupMimeType(fileName) ??
            'application/octet-stream';
        bool isValid = false;
        String errorMsg = "Unsupported file type.";
        int maxSize = _maxFileSizeBytes;

        if (mimeType.startsWith('image/')) {
          maxSize = _maxImageSizeBytes;
          isValid = _allowedMimeTypes.contains(mimeType);
          errorMsg = "Unsupported image type.";
        } else if (mimeType.startsWith('video/')) {
          maxSize = _maxVideoSizeBytes;
          isValid = _allowedMimeTypes.contains(mimeType);
          errorMsg = "Unsupported video type.";
        } else if (mimeType.startsWith('audio/')) {
          maxSize = _maxAudioSizeBytes;
          isValid = _allowedMimeTypes.contains(mimeType);
          errorMsg = "Unsupported audio type.";
        } else if (_allowedMimeTypes.contains(mimeType)) {
          maxSize = _maxFileSizeBytes;
          isValid = true;
        }

        if (!isValid) {
          _showErrorSnackbar(errorMsg);
          return;
        }
        if (fileSize > maxSize) {
          _showErrorSnackbar(
              "File is too large. Max size: ${maxSize ~/ (1024 * 1024)} MB.");
          return;
        }
        _initiateMediaSend(file, fileName, mimeType);
      } else {
        if (kDebugMode) print("[ChatDetailScreen] File picking cancelled.");
      }
    } catch (e) {
      if (kDebugMode) print("[ChatDetailScreen] Error picking file: $e");
      _showErrorSnackbar("Error selecting file: ${e.toString()}");
    }
  }

  Future<void> _handleMediaSelection(ImageSource source) async {
    if (_isUploadingMedia || _isInteracting || _isRecording)
      return; // Added recording check
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickMedia();
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileName = p.basename(pickedFile.path);
        final fileSize = await file.length();
        final headerBytes = await _readHeaderBytes(file);
        final mimeType =
            lookupMimeType(pickedFile.path, headerBytes: headerBytes) ??
                'application/octet-stream';
        bool isImage = mimeType.startsWith('image/');
        bool isVideo = mimeType.startsWith('video/');
        int maxSize =
            isImage ? _maxImageSizeBytes : (isVideo ? _maxVideoSizeBytes : 0);

        if (!isImage && !isVideo) {
          _showErrorSnackbar("Unsupported file type selected.");
          return;
        }
        if (!_allowedMimeTypes.contains(mimeType)) {
          _showErrorSnackbar(
              "Unsupported ${isImage ? 'image' : 'video'} format.");
          return;
        }
        if (fileSize > maxSize) {
          _showErrorSnackbar(
              "${isImage ? 'Image' : 'Video'} is too large. Max size: ${maxSize ~/ (1024 * 1024)} MB.");
          return;
        }
        _initiateMediaSend(file, fileName, mimeType);
      } else {
        if (kDebugMode) print("[ChatDetailScreen] Media picking cancelled.");
      }
    } catch (e) {
      if (kDebugMode) print("[ChatDetailScreen] Error picking media: $e");
      _showErrorSnackbar("Error selecting media: ${e.toString()}");
    }
  }

  // --- MODIFIED: _initiateMediaSend ---
  Future<void> _initiateMediaSend(
      File file, String fileName, String mimeType) async {
    if (!mounted) return;
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final currentUserId = ref.read(currentUserIdProvider);
    final chatService = ref.read(chatServiceProvider);
    final conversationState =
        ref.read(conversationProvider(widget.matchUserId));
    final replyingTo = conversationState.replyingToMessage;

    if (currentUserId == null) {
      _showErrorSnackbar("Cannot send media: User not identified.");
      return;
    }
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = ChatMessage(
      tempId: tempId,
      messageID: 0,
      senderUserID: currentUserId,
      recipientUserID: widget.matchUserId,
      messageText: '',
      mediaUrl: null,
      mediaType: mimeType,
      sentAt: DateTime.now().toLocal(), // Use local time for optimistic UI
      isRead: false,
      status: ChatMessageStatus.pending,
      localFilePath: file.path,
      errorMessage: null,
      replyToMessageID: replyingTo?.messageID,
      repliedMessageSenderID: replyingTo?.repliedMessageSenderID,
      repliedMessageTextSnippet: replyingTo?.repliedMessageTextSnippet,
      repliedMessageMediaType: replyingTo?.repliedMessageMediaType,
    );
    if (kDebugMode)
      print(
          "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Adding optimistic media message TempID: $tempId. Replying to: ${replyingTo?.messageID}");

    // Add to pending messages and conversation state
    chatService.addPendingMessage(tempId, widget.matchUserId);
    conversationNotifier.addSentMessage(optimisticMessage);

    setState(() => _isUploadingMedia = true);

    // Start background upload/send
    _uploadAndSendMediaInBackground(
            file, fileName, mimeType, tempId, replyingTo?.messageID)
        .then((_) {
      if (mounted) {
        final stillProcessing = ref
            .read(conversationProvider(widget.matchUserId))
            .messages
            .any((m) =>
                m.senderUserID == currentUserId &&
                (m.status == ChatMessageStatus.uploading ||
                    m.status == ChatMessageStatus.pending));
        if (!stillProcessing) {
          if (kDebugMode)
            print(
                "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] All uploads/acks seem finished for current user. Re-enabling input.");
          setState(() => _isUploadingMedia = false);
        } else {
          if (kDebugMode)
            print(
                "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Background task for $tempId finished, but others might be pending/uploading. Input remains disabled.");
        }
      }
    });
  }
  // --- END MODIFIED ---

  // --- MODIFIED: _uploadAndSendMediaInBackground ---
  // Phase 3: Send WebSocket Message after successful upload
  Future<void> _uploadAndSendMediaInBackground(File file, String fileName,
      String mimeType, String tempId, int? replyToMessageId) async {
    if (!mounted) return;
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final chatService = ref.read(chatServiceProvider);
    final bool isImage = mimeType.startsWith('image/');
    final bool isAudio = mimeType.startsWith('audio/');

    // Update status to Uploading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (kDebugMode)
          print("[ChatBG Task $tempId] Updating status to Uploading");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.uploading);
      }
    });

    String? objectUrl;
    try {
      if (kDebugMode)
        print("[ChatBG Task $tempId] Getting chat presigned URL...");
      final urls = await mediaRepo.getChatMediaPresignedUrl(fileName, mimeType);
      final presignedUrl = urls['presigned_url'];
      objectUrl = urls['object_url'];
      if (presignedUrl == null || objectUrl == null) {
        throw ApiException("Failed to get upload URLs from server.");
      }

      if (kDebugMode) print("[ChatBG Task $tempId] Uploading to S3...");
      final uploadModel = MediaUploadModel(
          file: file,
          fileName: fileName,
          fileType: mimeType,
          presignedUrl: presignedUrl);
      bool uploadSuccess = await mediaRepo.retryUpload(uploadModel);

      if (!uploadSuccess) {
        throw ApiException("Failed to upload media to storage.");
      }

      // Pre-cache image (only if it's an image)
      if (isImage && objectUrl != null) {
        if (kDebugMode)
          print("[ChatBG Task $tempId] Pre-caching image: $objectUrl");
        try {
          await DefaultCacheManager().downloadFile(objectUrl);
          if (kDebugMode)
            print("[ChatBG Task $tempId] Image pre-caching completed");
        } catch (cacheErr) {
          if (kDebugMode)
            print(
                "[ChatBG Task $tempId] WARNING: Image pre-caching failed: $cacheErr");
        }
      }

      // --- START: Phase 3 Change ---
      if (kDebugMode)
        print(
            "[ChatBG Task $tempId] Upload successful. Sending WebSocket message. ReplyTo: $replyToMessageId, URL: $objectUrl, Type: $mimeType");
      chatService.sendMessage(
        widget.matchUserId,
        mediaUrl: objectUrl,
        mediaType: mimeType,
        replyToMessageId: replyToMessageId,
      );
      if (kDebugMode)
        print("[ChatBG Task $tempId] WebSocket message sent. Awaiting ack...");
      // --- END: Phase 3 Change ---
    } on ApiException catch (e) {
      if (kDebugMode) print("[ChatBG Task $tempId] API Error: ${e.message}");
      if (mounted) {
        if (kDebugMode)
          print("[ChatBG Task $tempId] Updating status to Failed (API Error)");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.failed,
            errorMessage: e.message, finalMediaUrl: objectUrl);
      }
    } catch (e, stacktrace) {
      if (kDebugMode) print("[ChatBG Task $tempId] General Error: $e");
      if (kDebugMode) print("[ChatBG Task $tempId] Stacktrace: $stacktrace");
      if (mounted) {
        if (kDebugMode)
          print(
              "[ChatBG Task $tempId] Updating status to Failed (General Error)");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.failed,
            errorMessage: "Upload/Send failed: ${e.toString()}",
            finalMediaUrl: objectUrl);
      }
    }
  }
  // --- END MODIFIED ---

  // --- _showSnackbar, _showErrorSnackbar, _showMoreOptions, _confirmAndUnmatch, _reportUser (Keep as is) ---
  void _showSnackbar(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: duration));
  }

  void _showErrorSnackbar(String message) {
    _showSnackbar(message, isError: true);
  }

  void _showMoreOptions() {
    if (_isInteracting || _isRecording) return; // Added recording check
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.block_flipped, color: Colors.redAccent),
                title: Text('Unmatch',
                    style: GoogleFonts.poppins(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndUnmatch();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text('Report',
                    style: GoogleFonts.poppins(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
                title: Text('Cancel', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndUnmatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Unmatch User?", style: GoogleFonts.poppins()),
        content: Text(
            "Are you sure you want to unmatch ${widget.matchName}? You won't be able to message them again.",
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Unmatch",
                  style: GoogleFonts.poppins(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    setState(() => _isInteracting = true);
    ref.read(errorProvider.notifier).clearError();
    try {
      final success = await ref
          .read(likeRepositoryProvider)
          .unmatchUser(targetUserId: widget.matchUserId);
      if (success && mounted) {
        _showSnackbar("Unmatched successfully.", isError: false);
        ref.invalidate(matchesProvider);
        Navigator.of(context).pop();
      } else if (!success && mounted) {
        _showErrorSnackbar("Failed to unmatch user.");
      }
    } on ApiException catch (e) {
      _showErrorSnackbar("Unmatch failed: ${e.message}");
    } catch (e) {
      _showErrorSnackbar("An unexpected error occurred during unmatch.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  Future<void> _reportUser() async {
    final selectedReason = await showReportReasonDialog(context);
    if (selectedReason == null) return;
    if (!mounted) return;
    setState(() => _isInteracting = true);
    ref.read(errorProvider.notifier).clearError();
    try {
      final success = await ref.read(likeRepositoryProvider).reportUser(
            targetUserId: widget.matchUserId,
            reason: selectedReason,
          );
      if (success && mounted) {
        _showSnackbar("Report submitted. Thank you.", isError: false);
        await _confirmAndUnmatch(); // Unmatch after reporting
      } else if (!success && mounted) {
        _showErrorSnackbar("Failed to submit report.");
      }
    } on ApiException catch (e) {
      _showErrorSnackbar("Report failed: ${e.message}");
    } catch (e) {
      _showErrorSnackbar("An unexpected error occurred during report.");
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  // --- CORRECTED: _buildReplyPreviewWidget (incorporating fix from previous turn) ---
  Widget _buildReplyPreviewWidget() {
    // Watch the provider to get the state, then access the property
    final conversationState =
        ref.watch(conversationProvider(widget.matchUserId));
    final replyingToMessage = conversationState.replyingToMessage;

    if (replyingToMessage == null) {
      if (kDebugMode)
        print(
            "[ChatDetailScreen _buildReplyPreviewWidget] No message being replied to.");
      return const SizedBox.shrink(); // Return empty space if not replying
    }

    if (kDebugMode)
      print(
          "[ChatDetailScreen _buildReplyPreviewWidget] Building preview for Message ID: ${replyingToMessage.messageID}");

    // Determine sender name ("You" or match name)
    final currentUserId = ref.read(currentUserIdProvider);
    final originalSenderName = replyingToMessage.senderUserID == currentUserId
        ? "You"
        : widget.matchName; // Use widget.matchName

    // Determine content preview
    // Use repliedMessageTextSnippet if available and not empty
    String contentPreview =
        (replyingToMessage.repliedMessageTextSnippet != null &&
                replyingToMessage.repliedMessageTextSnippet!.isNotEmpty)
            ? replyingToMessage.repliedMessageTextSnippet!
            : '';
    IconData? mediaIcon;

    // If text snippet is empty, determine preview from media type
    if (contentPreview.isEmpty) {
      final mediaType = replyingToMessage.repliedMessageMediaType;
      if (kDebugMode)
        print(
            "[ChatDetailScreen _buildReplyPreviewWidget] Original media type: $mediaType");
      if (mediaType?.startsWith('image/') ?? false) {
        contentPreview = "Photo";
        mediaIcon = Icons.photo_camera_back_outlined;
      } else if (mediaType?.startsWith('video/') ?? false) {
        contentPreview = "Video";
        mediaIcon = Icons.videocam_outlined;
      } else if (mediaType?.startsWith('audio/') ?? false) {
        contentPreview = "Audio";
        mediaIcon = Icons.headphones_outlined;
      } else if (mediaType != null) {
        contentPreview = "File"; // Generic file
        mediaIcon = Icons.attach_file_outlined;
      } else {
        contentPreview =
            "Original message"; // Fallback if both text and media type are missing
        if (kDebugMode)
          print(
              "[ChatDetailScreen _buildReplyPreviewWidget] Using fallback content preview.");
      }
    } else {
      if (kDebugMode)
        print(
            "[ChatDetailScreen _buildReplyPreviewWidget] Using text snippet: '$contentPreview'");
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Different background for preview bar
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Replying to $originalSenderName",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF6B46C1),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (mediaIcon != null)
                      Icon(mediaIcon, size: 14, color: Colors.black54),
                    if (mediaIcon != null) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contentPreview,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Colors.black54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Cancel Reply",
            onPressed: () {
              if (kDebugMode)
                print("[ChatDetailScreen CancelReplyButton] Cancelling reply.");
              ref
                  .read(conversationProvider(widget.matchUserId).notifier)
                  .cancelReply();
            },
          ),
        ],
      ),
    );
  }
  // --- END CORRECTED ---

  // --- Phase 1: Recording Methods ---
  Future<void> _startRecording() async {
    if (_isUploadingMedia || _isInteracting)
      return; // Don't allow during other ops
    if (_isRecording) return; // Prevent starting if already recording

    if (kDebugMode)
      print(
          "[ChatDetailScreen _startRecording] Attempting to start recording...");

    // 1. Request Permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (kDebugMode)
        print(
            "[ChatDetailScreen _startRecording] Microphone permission denied.");
      if (mounted) {
        _showErrorSnackbar(
            'Microphone permission is required to record audio.');
      }
      // Optionally open settings: await openAppSettings();
      return;
    }
    if (kDebugMode)
      print(
          "[ChatDetailScreen _startRecording] Microphone permission granted.");

    // 2. Get Temp Path
    try {
      final directory = await getTemporaryDirectory(); // Use temporary dir
      _recordingPath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a'; // Using m4a format
      if (kDebugMode)
        print(
            "[ChatDetailScreen _startRecording] Recording path set to: $_recordingPath");

      // 3. Start Recorder
      // Ensure recorder is not already recording
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      await _audioRecorder.start(
          const RecordConfig(
              encoder: AudioEncoder.aacLc), // Use a common encoder
          path: _recordingPath!);

      // 4. Update State & Start Timer
      _recordingDurationSeconds = 0;
      if (mounted) {
        setState(() {
          _isRecording = true;
        });
        // Start timer to update UI and stop recording after max duration
        _recordingTimer?.cancel(); // Cancel any previous timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isRecording || !mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _recordingDurationSeconds++;
          });
          if (_recordingDurationSeconds >= _maxRecordingDuration) {
            if (kDebugMode)
              print(
                  "[ChatDetailScreen _startRecording] Max recording time reached.");
            _stopRecordingAndSend(); // Auto-stop and send
          }
        });
        if (kDebugMode)
          print(
              "[ChatDetailScreen _startRecording] Recording started successfully.");
      }
    } catch (e) {
      if (kDebugMode)
        print('[ChatDetailScreen _startRecording] Recording error: $e');
      if (mounted) {
        _showErrorSnackbar('Recording failed: ${e.toString()}');
        setState(() {
          _isRecording = false; // Reset state on error
          _recordingPath = null;
          _recordingDurationSeconds = 0;
        });
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    if (kDebugMode)
      print("[ChatDetailScreen _stopRecordingAndSend] Stopping recording...");

    _recordingTimer?.cancel(); // Stop the timer
    try {
      final path = await _audioRecorder.stop();
      if (kDebugMode)
        print(
            '[ChatDetailScreen _stopRecordingAndSend] Recording stopped. Path from recorder: $path');
      // Use the internally stored path if recorder doesn't return one reliably
      final finalPath = path ?? _recordingPath;

      if (finalPath == null) {
        throw Exception("Recording path is null after stopping.");
      }

      final file = File(finalPath);
      if (!await file.exists() || await file.length() == 0) {
        if (kDebugMode)
          print(
              '[ChatDetailScreen _stopRecordingAndSend] Error: Recording file missing or empty at $finalPath');
        throw Exception("Recording file error.");
      }

      // Reset UI state *before* starting background task
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDurationSeconds = 0;
        });
      }

      // --- Phase 2: Initiate Optimistic UI & Upload ---
      final fileName = p.basename(finalPath);
      // Detect MIME type (fallback to m4a if needed)
      String? mimeType = lookupMimeType(finalPath) ?? 'audio/m4a';
      if (kDebugMode)
        print(
            "[ChatDetailScreen _stopRecordingAndSend] Detected MIME: $mimeType for $fileName");

      // Validate size
      final fileSize = await file.length();
      if (fileSize > _maxAudioSizeBytes) {
        throw Exception(
            "Audio file exceeds maximum size (${_maxAudioSizeBytes / 1024 / 1024} MB).");
      }
      if (!_allowedMimeTypes.contains(mimeType)) {
        throw Exception("Unsupported audio format: $mimeType");
      }

      _initiateMediaSend(file, fileName, mimeType); // Pass audio file details
      // --- End Phase 2 ---

      _recordingPath = null; // Clear path after initiating send
    } catch (e) {
      if (kDebugMode)
        print(
            '[ChatDetailScreen _stopRecordingAndSend] Error stopping/sending: $e');
      if (mounted) {
        _showErrorSnackbar('Error processing recording: ${e.toString()}');
        setState(() {
          // Reset state fully on error
          _isRecording = false;
          _recordingPath = null;
          _recordingDurationSeconds = 0;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    if (kDebugMode)
      print("[ChatDetailScreen _cancelRecording] Cancelling recording...");

    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop();
      if (kDebugMode)
        print("[ChatDetailScreen _cancelRecording] Recorder stopped.");
      // Delete the partial/cancelled recording file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode)
            print(
                "[ChatDetailScreen _cancelRecording] Deleted temporary file: $_recordingPath");
        }
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "[ChatDetailScreen _cancelRecording] Error stopping/deleting recording: $e");
      // Don't necessarily show error to user, just reset state
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
          _recordingDurationSeconds = 0;
        });
      }
    }
  }
  // --- End Recording Methods ---

  @override
  Widget build(BuildContext context) {
    if (kDebugMode)
      print(
          "[ChatDetailScreen Build: ${widget.matchUserId}] Rebuilding Widget... IsUploading: $_isUploadingMedia, IsInteracting: $_isInteracting, IsRecording: $_isRecording"); // Added recording state
    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId = ref.watch(currentUserIdProvider);

    if (kDebugMode)
      print(
          "[ChatDetailScreen Build: ${widget.matchUserId}] State status: otherUserIsOnline=${state.otherUserIsOnline}, otherUserLastOnline=${state.otherUserLastOnline}");

    // Listener for scroll (keep as is)
    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
      final prevLength = prev?.messages.length ?? 0;
      final nextLength = next.messages.length;
      final isNewMessageFromMe = nextLength > prevLength &&
          next.messages.isNotEmpty &&
          next.messages.first.senderUserID == currentUserId;
      final isMessageStatusUpdate = nextLength == prevLength &&
          prevLength > 0 &&
          next.messages.isNotEmpty &&
          next.messages.first.tempId != null &&
          prev?.messages.first.status != next.messages.first.status;

      if (kDebugMode)
        print(
            "[ChatDetailScreen Listener: ${widget.matchUserId}] State changed. PrevLen=$prevLength, NextLen=$nextLength. IsNewFromMe=$isNewMessageFromMe, IsStatusUpdate=$isMessageStatusUpdate");

      if (isNewMessageFromMe) {
        if (kDebugMode)
          print(
              "[ChatDetailScreen Listener: ${widget.matchUserId}] New PENDING message added by me. Scheduling scroll.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Add check if scrollController has clients before scrolling
          if (_scrollController.hasClients) {
            if (kDebugMode)
              print(
                  "[ChatDetailScreen Listener: ${widget.matchUserId}] Executing scroll after frame callback.");
            _scrollToBottom();
          } else {
            if (kDebugMode)
              print(
                  "[ChatDetailScreen Listener: ${widget.matchUserId}] ScrollController has no clients, skipping scroll.");
          }
        });
      } else if (isMessageStatusUpdate) {
        if (kDebugMode)
          print(
              "[ChatDetailScreen Listener: ${widget.matchUserId}] Message status updated. No scroll triggered.");
      } else if (nextLength > prevLength && !isNewMessageFromMe) {
        if (kDebugMode)
          print(
              "[ChatDetailScreen Listener: ${widget.matchUserId}] New message received from other user. No scroll triggered.");
      } else {
        if (kDebugMode)
          print(
              "[ChatDetailScreen Listener: ${widget.matchUserId}] No scroll triggered (Other state change).");
      }
    });

    // Status text logic (keep as is)
    String statusText;
    Color statusColor;
    if (state.isLoading && state.messages.isEmpty) {
      statusText = 'Loading...';
      statusColor = Colors.grey;
    } else if (state.otherUserIsOnline) {
      statusText = 'Online';
      statusColor = Colors.green;
    } else {
      statusText = formatLastSeen(state.otherUserLastOnline, short: true);
      statusColor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        // AppBar setup remains the same
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.grey[700]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          /* ... Title Row ... */
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.matchAvatarUrl != null
                  ? NetworkImage(widget.matchAvatarUrl!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: widget.matchAvatarUrl == null
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.matchName,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (statusText.isNotEmpty)
                    Text(
                      statusText,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          /* ... Actions ... */
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
            tooltip: "More Options",
            onPressed: _isInteracting || _isRecording
                ? null
                : _showMoreOptions, // Disable during recording
            disabledColor: Colors.grey[300],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildMessagesList(state, currentUserId),
            ),
          ),
          _buildReplyPreviewWidget(),
          if (_isInteracting) // Show generic loading if unmatching/reporting
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
            )
          // Show recording UI or input area
          else if (_isRecording)
            _buildRecordingInputArea()
          else
            _buildMessageInputArea(),
        ],
      ),
    );
  }

  // --- MODIFIED: _buildMessagesList ---
  Widget _buildMessagesList(ConversationState state, int? currentUserId) {
    if (kDebugMode)
      print(
          "[ChatDetailScreen _buildMessagesList: ${widget.matchUserId}] Building message list. Count: ${state.messages.length}");
    // --- Loading/Error/Empty checks remain the same ---
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }
    if (state.error != null && state.messages.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Error loading messages: ${state.error!.message}",
                  style: GoogleFonts.poppins(color: Colors.red),
                  textAlign: TextAlign.center)));
    }
    if (!state.isLoading && state.messages.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Start the conversation!",
                  style: GoogleFonts.poppins(
                      color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center)));
    }
    // --- End Checks ---

    return ListView.builder(
      addAutomaticKeepAlives: true,
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final bool isMe = currentUserId != null && message.isMe(currentUserId);
        bool showTail = true;
        if (index > 0) {
          final prevMessage = state.messages[index - 1];
          if (prevMessage.senderUserID == message.senderUserID) {
            final timeDiff = message.sentAt.difference(prevMessage.sentAt);
            if (timeDiff.inSeconds < 60) {
              showTail = false;
            }
          }
        }
        final keyId = message.tempId ?? message.messageID.toString();
        String originalSenderDisplayName = "Unknown"; // Default
        if (message.isReply && message.repliedMessageSenderID != null) {
          originalSenderDisplayName =
              message.repliedMessageSenderID == currentUserId
                  ? "You"
                  : widget.matchName; // Use the match name passed to the screen
        }

        // *** ADDED: Pass onReplyInitiated callback ***
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: MessageBubble(
              key: ValueKey(
                  "${keyId}_${message.status}_${message.mediaUrl ?? message.localFilePath}_${message.isReply}"), // Add isReply to key
              message: message,
              isMe: isMe,
              showTail: showTail,
              originalSenderDisplayName:
                  originalSenderDisplayName, // *** ADDED ***
              // Call startReplying when bubble signals reply initiation
              onReplyInitiated: (messageToReply) {
                if (kDebugMode)
                  print(
                      "[ChatDetailScreen onReplyInitiated] Triggered for message ID: ${messageToReply.messageID}");
                ref
                    .read(conversationProvider(widget.matchUserId).notifier)
                    .startReplying(messageToReply);
              },
            ));
        // *** END ADDED ***
      },
    );
  }
  // --- END MODIFIED ---

  // --- MODIFIED: _buildMessageInputArea ---
  Widget _buildMessageInputArea() {
    final canSendText = ref.watch(messageInputProvider);
    final allowInput = !_isUploadingMedia && !_isInteracting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded,
                  color: allowInput ? Colors.grey[600] : Colors.grey[300]),
              onPressed: allowInput ? _showAttachmentOptions : null,
              tooltip: "Attach Media",
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    focusNode: _inputFocusNode,
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: allowInput
                          ? "Type a message..."
                          : (_isUploadingMedia
                              ? "Uploading..."
                              : "Processing..."),
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onChanged: (text) {
                      ref.read(messageInputProvider.notifier).state =
                          text.trim().isNotEmpty;
                    },
                    onSubmitted: (_) =>
                        canSendText && allowInput ? _sendMessage() : null,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.poppins(
                        color: Colors.black87, fontSize: 15),
                    enabled: allowInput,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // --- Conditionally show Send or Mic button ---
            if (canSendText)
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: const Color(0xFF8B5CF6),
                onPressed: allowInput ? _sendMessage : null,
                tooltip: "Send Message",
                disabledColor: Colors.grey[400],
              )
            else
              IconButton(
                icon: const Icon(Icons.mic_none_rounded),
                color: allowInput ? const Color(0xFF8B5CF6) : Colors.grey[300],
                onPressed: allowInput ? _startRecording : null,
                tooltip: "Record Voice Note",
              ),
            // --- End Conditional Button ---
          ],
        ),
      ),
    );
  }
  // --- END MODIFIED ---

  // --- NEW: _buildRecordingInputArea ---
  Widget _buildRecordingInputArea() {
    final displayDuration = Duration(seconds: _recordingDurationSeconds);
    final minutes = displayDuration.inMinutes.remainder(60).toString();
    final seconds =
        displayDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timerText = "$minutes:$seconds / 0:${_maxRecordingDuration}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel Button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.grey[600]),
              onPressed: _cancelRecording,
              tooltip: "Cancel Recording",
            ),
            // Recording Indicator / Timer
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    timerText,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Stop/Send Button
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded,
                  size: 32), // Larger stop icon
              color: const Color(0xFF8B5CF6),
              onPressed: _stopRecordingAndSend,
              tooltip: "Stop and Send",
            ),
          ],
        ),
      ),
    );
  }
  // --- END NEW ---
}

// --- Keep messageInputProvider (No change needed) ---
final messageInputProvider = StateProvider<bool>((ref) => false);

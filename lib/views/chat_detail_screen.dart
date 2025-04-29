// File: lib/views/chat_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/media_upload_model.dart';
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
import 'package:dtx/utils/date_formatter.dart'; // <-- IMPORT ADDED
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

// ... (Keep existing ChatDetailScreen class signature and state variables) ...
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

  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const int _maxAudioSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB
  static final Set<String> _allowedMimeTypes = {
    // Images
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    // Videos
    'video/mp4',
    'video/quicktime', // .mov
    'video/webm',
    'video/x-msvideo', // .avi (might be large)
    'video/mpeg',
    // Audio
    'audio/mpeg', // .mp3
    'audio/ogg',
    'audio/wav',
    'audio/aac',
    'audio/opus',
    'audio/webm',
    'audio/mp4', // m4a
    'audio/x-m4a',
    // Documents
    'application/pdf',
    'application/msword', // .doc
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
    'application/vnd.ms-excel', // .xls
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
    'application/vnd.ms-powerpoint', // .ppt
    'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
    'text/plain', // .txt
  };
  // --- END ADDED BACK ---
  @override
  void initState() {
    super.initState();
    // ... (Keep existing initState logic) ...
    print("[ChatDetailScreen Init: ${widget.matchUserId}] Initializing...");
    _inputFocusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
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
    // ... (Keep existing dispose logic) ...
    print("[ChatDetailScreen Dispose: ${widget.matchUserId}] Disposing...");
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_handleFocusChange);
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    // Optional: Add logic if needed when focus changes
  }

  // --- Keep ALL existing helper methods (_readHeaderBytes, _sendMessage, _scrollToBottom, _showAttachmentOptions, etc.) ---
  // ...
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
      print("Error reading header bytes: $e");
      return null;
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isUploadingMedia || _isInteracting) return;

    final chatService = ref.read(chatServiceProvider);
    final wsState = ref.read(webSocketStateProvider);

    if (wsState == WebSocketConnectionState.connected) {
      chatService.sendMessage(widget.matchUserId, text: text);
      _messageController.clear();
      ref.read(messageInputProvider.notifier).state = false;
      // Don't refocus immediately, let keyboard manage itself
      // FocusScope.of(context).requestFocus(_inputFocusNode);
    } else {
      _showErrorSnackbar("Cannot send message. Not connected.");
      chatService.connect();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      print(
          "[ChatDetailScreen Scroll: ${widget.matchUserId}] Animating scroll to top (0.0)");
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      print(
          "[ChatDetailScreen Scroll: ${widget.matchUserId}] Cannot scroll, no clients.");
    }
  }

  void _showAttachmentOptions() {
    if (_isUploadingMedia || _isInteracting) return;
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
    if (_isUploadingMedia || _isInteracting) return;
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
        print("[ChatDetailScreen] File picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking file: $e");
      _showErrorSnackbar("Error selecting file: ${e.toString()}");
    }
  }

  Future<void> _handleMediaSelection(ImageSource source) async {
    if (_isUploadingMedia || _isInteracting) return;
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
        print("[ChatDetailScreen] Media picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking media: $e");
      _showErrorSnackbar("Error selecting media: ${e.toString()}");
    }
  }

  Future<void> _initiateMediaSend(
      File file, String fileName, String mimeType) async {
    if (!mounted) return;
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final currentUserId = ref.read(currentUserIdProvider);
    final chatService =
        ref.read(chatServiceProvider); // Get chat service instance

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
      sentAt: DateTime.now(),
      isRead: false,
      status: ChatMessageStatus.pending,
      localFilePath: file.path,
      errorMessage: null,
    );
    print(
        "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Adding optimistic media message TempID: $tempId");

    // *** Call public method ***
    chatService.addPendingMessage(tempId, widget.matchUserId);
    // *** END ***

    conversationNotifier.addSentMessage(optimisticMessage);
    setState(() => _isUploadingMedia = true);

    _uploadAndSendMediaInBackground(file, fileName, mimeType, tempId).then((_) {
      if (mounted) {
        final stillProcessing = ref
            .read(conversationProvider(widget.matchUserId))
            .messages
            .any((m) =>
                m.senderUserID == currentUserId &&
                (m.status == ChatMessageStatus.uploading ||
                    m.status == ChatMessageStatus.pending));
        if (!stillProcessing) {
          print(
              "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] All uploads/acks seem finished for current user. Re-enabling input.");
          setState(() => _isUploadingMedia = false);
        } else {
          print(
              "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Background task for $tempId finished, but others might be pending/uploading. Input remains disabled.");
        }
      }
    });
  }

  Future<void> _uploadAndSendMediaInBackground(
      File file, String fileName, String mimeType, String tempId) async {
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final chatService = ref.read(chatServiceProvider);
    final bool isImage = mimeType.startsWith('image/');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("[ChatBG Task $tempId] Updating status to Uploading");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.uploading);
      }
    });

    String? objectUrl;
    try {
      print("[ChatBG Task $tempId] Getting chat presigned URL...");
      final urls = await mediaRepo.getChatMediaPresignedUrl(fileName, mimeType);
      final presignedUrl = urls['presigned_url'];
      objectUrl = urls['object_url'];
      if (presignedUrl == null || objectUrl == null) {
        throw ApiException("Failed to get upload URLs from server.");
      }

      print("[ChatBG Task $tempId] Uploading to S3...");
      final uploadModel = MediaUploadModel(
          file: file,
          fileName: fileName,
          fileType: mimeType,
          presignedUrl: presignedUrl);
      bool uploadSuccess = await mediaRepo.retryUpload(uploadModel);

      if (!uploadSuccess) {
        throw ApiException("Failed to upload media to storage.");
      }

      if (isImage && objectUrl != null) {
        print("[ChatBG Task $tempId] Pre-caching image: $objectUrl");
        try {
          await DefaultCacheManager().downloadFile(objectUrl);
          print("[ChatBG Task $tempId] Image pre-caching completed");
        } catch (cacheErr) {
          print(
              "[ChatBG Task $tempId] WARNING: Image pre-caching failed: $cacheErr");
        }
      }

      print(
          "[ChatBG Task $tempId] Upload successful. Sending WebSocket message...");
      chatService.sendMessage(widget.matchUserId,
          mediaUrl: objectUrl, mediaType: mimeType);

      print("[ChatBG Task $tempId] WebSocket message sent. Awaiting ack...");
    } on ApiException catch (e) {
      print("[ChatBG Task $tempId] API Error: ${e.message}");
      if (mounted) {
        print("[ChatBG Task $tempId] Updating status to Failed (API Error)");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.failed,
            errorMessage: e.message, finalMediaUrl: objectUrl);
      }
    } catch (e, stacktrace) {
      print("[ChatBG Task $tempId] General Error: $e");
      print("[ChatBG Task $tempId] Stacktrace: $stacktrace");
      if (mounted) {
        print(
            "[ChatBG Task $tempId] Updating status to Failed (General Error)");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.failed,
            errorMessage: "Upload/Send failed: ${e.toString()}",
            finalMediaUrl: objectUrl);
      }
    }
  }

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
    if (_isInteracting) return;
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
        ref.invalidate(matchesProvider); // Refresh matches list
        Navigator.of(context).pop(); // Go back from chat screen
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
        await _confirmAndUnmatch();
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
  // --- END ---

  @override
  Widget build(BuildContext context) {
    print(
        "[ChatDetailScreen Build: ${widget.matchUserId}] Rebuilding Widget... IsUploading: $_isUploadingMedia, IsInteracting: $_isInteracting");
    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId = ref.watch(currentUserIdProvider);
    // final wsState = ref.watch(webSocketStateProvider); // No longer needed for status here

    // --- ADDED LOGGING for Status ---
    if (kDebugMode) {
      print(
          "[ChatDetailScreen Build: ${widget.matchUserId}] State status: otherUserIsOnline=${state.otherUserIsOnline}, otherUserLastOnline=${state.otherUserLastOnline}");
    }
    // --- END LOGGING ---

    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
      // ... (keep existing scroll listener logic) ...
      final prevLength = prev?.messages.length ?? 0;
      final nextLength = next.messages.length;
      final prevFirstTempId = prev?.messages.isNotEmpty ?? false
          ? prev!.messages.first.tempId
          : null;
      final nextFirstTempId =
          next.messages.isNotEmpty ? next.messages.first.tempId : null;
      final nextFirstStatus =
          next.messages.isNotEmpty ? next.messages.first.status : null;
      final Map<String, int> nextStatusCounts = {};
      for (var msg in next.messages) {
        nextStatusCounts[msg.status.toString()] =
            (nextStatusCounts[msg.status.toString()] ?? 0) + 1;
      }
      print(
          "[ChatDetailScreen Listener: ${widget.matchUserId}] State changed. PrevLen=$prevLength, NextLen=$nextLength. PrevFirstTempId=$prevFirstTempId, NextFirstTempId=$nextFirstTempId, NextFirstStatus=$nextFirstStatus. Next Status Counts: $nextStatusCounts");
      if (nextLength > prevLength &&
          next.messages.isNotEmpty &&
          next.messages.first.senderUserID == currentUserId &&
          next.messages.first.status == ChatMessageStatus.pending) {
        print(
            "[ChatDetailScreen Listener: ${widget.matchUserId}] New PENDING message added by me. Scheduling scroll.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print(
              "[ChatDetailScreen Listener: ${widget.matchUserId}] Executing scroll after frame callback.");
          _scrollToBottom();
        });
      } else if (nextLength == prevLength &&
          prevLength > 0 &&
          next.messages.isNotEmpty &&
          next.messages.first.tempId != null) {
        print(
            "[ChatDetailScreen Listener: ${widget.matchUserId}] Message status likely updated (Length same). TempID=${next.messages.first.tempId}, NewStatus=${next.messages.first.status}. No scroll triggered.");
      } else {
        print(
            "[ChatDetailScreen Listener: ${widget.matchUserId}] No scroll triggered (Condition not met or received message).");
      }
    });

    // --- STATUS TEXT LOGIC ---
    String statusText;
    Color statusColor;
    if (state.isLoading && state.messages.isEmpty) {
      statusText = 'Loading...'; // Initial loading state
      statusColor = Colors.grey;
    } else if (state.otherUserIsOnline) {
      statusText = 'Online';
      statusColor = Colors.green;
    } else {
      statusText = formatLastSeen(state.otherUserLastOnline, short: true);
      statusColor = Colors.grey;
    }
    // --- END STATUS TEXT LOGIC ---

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.grey[700]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // --- UPDATED TITLE ---
        title: Row(
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
                        fontSize: 16, // Slightly smaller name
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // --- Display Status Text ---
                  if (statusText.isNotEmpty) // Only show if status is available
                    Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 12, // Smaller font for status
                        fontWeight: FontWeight.w400,
                        color: statusColor, // Dynamic color
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        // --- END UPDATED TITLE ---
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
            tooltip: "More Options",
            onPressed: _isInteracting ? null : _showMoreOptions,
            disabledColor: Colors.grey[300],
          ),
          // --- REMOVED redundant WebSocket status dot ---
          // Padding(
          //   padding: const EdgeInsets.only(right: 16.0),
          //   child: Icon(
          //     Icons.circle,
          //     size: 10,
          //     color: wsState == WebSocketConnectionState.connected
          //         ? Colors.green
          //         : (wsState == WebSocketConnectionState.connecting
          //             ? Colors.orange
          //             : Colors.red),
          //   ),
          // ),
          // --- END REMOVED ---
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
          if (_isInteracting)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
            )
          else
            _buildMessageInputArea(),
        ],
      ),
    );
  }

  // --- Keep _buildMessagesList ---
  Widget _buildMessagesList(ConversationState state, int? currentUserId) {
    print(
        "[ChatDetailScreen _buildMessagesList: ${widget.matchUserId}] Building message list. Count: ${state.messages.length}");
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
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: MessageBubble(
                key: ValueKey(
                    "${keyId}_${message.status}_${message.mediaUrl ?? message.localFilePath}"),
                message: message,
                isMe: isMe,
                showTail: showTail));
      },
    );
  }

  // --- Keep _buildMessageInputArea ---
  Widget _buildMessageInputArea() {
    final canSendText = ref.watch(messageInputProvider);
    final bool allowInput = !_isUploadingMedia && !_isInteracting;

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
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF8B5CF6),
              onPressed: canSendText && allowInput ? _sendMessage : null,
              tooltip: "Send Message",
              disabledColor: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Keep messageInputProvider ---
final messageInputProvider = StateProvider<bool>((ref) => false);

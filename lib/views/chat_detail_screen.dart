// lib/views/chat_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart'; // Added
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/repositories/media_repository.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/services/chat_service.dart';
import 'package:dtx/widgets/message_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Added
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

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
  bool _isUploadingMedia = false; // Tracks if ANY upload is active

  // --- Constants ---
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024;
  static const int _maxAudioSizeBytes = 10 * 1024 * 1024;
  static const int _maxFileSizeBytes = 25 * 1024 * 1024;
  static final Set<String> _allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'video/x-msvideo',
    'video/mpeg',
    'audio/mpeg',
    'audio/ogg',
    'audio/wav',
    'audio/aac',
    'audio/opus',
    'audio/webm',
    'audio/mp4',
    'audio/x-m4a',
    'application/pdf',
    'application/msword',
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
    print("[ChatDetailScreen Init: ${widget.matchUserId}] Initializing...");
    _inputFocusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure WebSocket is connected
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
        print(
            "[ChatDetailScreen Init: ${widget.matchUserId}] Connecting WebSocket...");
        chatService.connect();
      }
      // Initial message fetch is handled by the provider itself now
    });
  }

  @override
  void dispose() {
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

  // Helper to read header bytes for MIME type detection
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

  // Send TEXT message
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isUploadingMedia)
      return; // Prevent send if empty or uploading

    final chatService = ref.read(chatServiceProvider);
    final wsState = ref.read(webSocketStateProvider);

    if (wsState == WebSocketConnectionState.connected) {
      chatService.sendMessage(widget.matchUserId, text: text);
      _messageController.clear();
      ref.read(messageInputProvider.notifier).state =
          false; // Update button state
      FocusScope.of(context).requestFocus(_inputFocusNode); // Keep focus
      // Scroll handled by listener
    } else {
      _showErrorSnackbar("Cannot send message. Not connected.");
      chatService.connect(); // Attempt to reconnect
    }
  }

  // Scroll to the newest message (top of the reversed list)
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

  // Show options for attaching media/files
  void _showAttachmentOptions() {
    if (_isUploadingMedia) return; // Don't show if already uploading
    FocusScope.of(context).unfocus(); // Hide keyboard
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

  // Handle selecting general files
  Future<void> _handleFileSelection() async {
    if (_isUploadingMedia) return;
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

        // Validation
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

        // Initiate the send process
        _initiateMediaSend(file, fileName, mimeType);
      } else {
        print("[ChatDetailScreen] File picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking file: $e");
      _showErrorSnackbar("Error selecting file: ${e.toString()}");
    }
  }

  // Handle selecting images/videos from camera or gallery
  Future<void> _handleMediaSelection(ImageSource source) async {
    if (_isUploadingMedia) return;
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

        // Validation
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

        // Initiate the send process
        _initiateMediaSend(file, fileName, mimeType);
      } else {
        print("[ChatDetailScreen] Media picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking media: $e");
      _showErrorSnackbar("Error selecting media: ${e.toString()}");
    }
  }

  // Adds optimistic message and triggers background upload
  Future<void> _initiateMediaSend(
      File file, String fileName, String mimeType) async {
    if (!mounted) return;
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final currentUserId = ref.read(currentUserIdProvider);

    if (currentUserId == null) {
      _showErrorSnackbar("Cannot send media: User not identified.");
      return;
    }

    // 1. Generate Temporary ID
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // 2. Create Optimistic Message
    final optimisticMessage = ChatMessage(
      tempId: tempId,
      messageID: 0, // Use 0 or negative for temporary
      senderUserID: currentUserId,
      recipientUserID: widget.matchUserId,
      messageText: '',
      mediaUrl: null, // No final URL yet
      mediaType: mimeType,
      sentAt: DateTime.now(), // Local time for display
      isRead: false,
      status: ChatMessageStatus.pending, // Initial status
      localFilePath: file.path, // Store local path
      errorMessage: null,
    );

    // 3. Add Optimistic Message to UI IMMEDIATELY
    print(
        "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Adding optimistic media message TempID: $tempId");
    conversationNotifier.addSentMessage(optimisticMessage);

    // 4. Trigger Background Upload/Send (DO NOT AWAIT here)
    // Set the global uploading flag
    setState(() => _isUploadingMedia = true);
    _uploadAndSendMediaInBackground(file, fileName, mimeType, tempId).then((_) {
      // This block executes after the background task finishes
      if (mounted) {
        // Check if *other* messages are still uploading before re-enabling globally
        final stillUploading = ref
            .read(conversationProvider(widget.matchUserId))
            .messages
            .any((m) =>
                m.status == ChatMessageStatus.uploading ||
                m.status == ChatMessageStatus.pending);
        if (!stillUploading) {
          print(
              "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Last upload finished. Re-enabling input.");
          setState(() => _isUploadingMedia = false);
        } else {
          print(
              "[ChatDetailScreen _initiateMediaSend: ${widget.matchUserId}] Upload for $tempId finished, but others are pending. Input remains disabled.");
        }
      }
    });

    // 5. Scroll is handled by the listener based on the message add
  }

  // Background task to upload, send WebSocket message, and update status
  Future<void> _uploadAndSendMediaInBackground(
      File file, String fileName, String mimeType, String tempId) async {
    // Use read outside async gap if possible
    final conversationNotifier =
        ref.read(conversationProvider(widget.matchUserId).notifier);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final chatService = ref.read(chatServiceProvider);
    final bool isImage = mimeType.startsWith('image/');

    // Update status to Uploading (using addPostFrameCallback for safety)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("[ChatBG Task $tempId] Updating status to Uploading");
        conversationNotifier.updateMessageStatus(
            tempId, ChatMessageStatus.uploading);
      }
    });

    String? objectUrl; // To store the final URL

    try {
      print("[ChatBG Task $tempId] Getting chat presigned URL...");
      final urls = await mediaRepo.getChatMediaPresignedUrl(fileName, mimeType);
      final presignedUrl = urls['presigned_url'];
      objectUrl = urls['object_url']; // Assign final URL

      if (presignedUrl == null || objectUrl == null) {
        throw ApiException("Failed to get upload URLs from server.");
      }

      print("[ChatBG Task $tempId] Uploading to S3...");
      final uploadModel = MediaUploadModel(
        file: file,
        fileName: fileName,
        fileType: mimeType,
        presignedUrl: presignedUrl,
      );
      bool uploadSuccess = await mediaRepo.retryUpload(uploadModel);

      if (!uploadSuccess) {
        throw ApiException("Failed to upload media to storage.");
      }

      // --- Pre-cache the image AFTER successful upload ---
      if (isImage && objectUrl != null) {
        // Check objectUrl is not null
        print("[ChatBG Task $tempId] Pre-caching image: $objectUrl");
        try {
          // Use the default cache manager or configure a specific one
          await DefaultCacheManager().downloadFile(objectUrl);
          print(
              "[ChatBG Task $tempId] Image pre-caching completed for $objectUrl");
        } catch (cacheErr) {
          print(
              "[ChatBG Task $tempId] WARNING: Image pre-caching failed: $cacheErr");
        }
      }
      // --- End Pre-cache ---

      print(
          "[ChatBG Task $tempId] Upload successful. Sending WebSocket message...");
      chatService.sendMessage(
        widget.matchUserId,
        mediaUrl: objectUrl,
        mediaType: mimeType,
      );

      // Update status to SENT only AFTER successful upload and WS send attempt
      if (mounted) {
        print(
            "[ChatBG Task $tempId] Updating status to Sent, Final URL: $objectUrl");
        conversationNotifier.updateMessageStatus(
          tempId,
          ChatMessageStatus.sent,
          finalMediaUrl: objectUrl, // Provide the final URL
        );
      }
      print("[ChatBG Task $tempId] Message marked as SENT locally.");
    } on ApiException catch (e) {
      print("[ChatBG Task $tempId] API Error: ${e.message}");
      if (mounted) {
        print("[ChatBG Task $tempId] Updating status to Failed (API Error)");
        conversationNotifier.updateMessageStatus(
          tempId,
          ChatMessageStatus.failed,
          errorMessage: e.message,
        );
      }
    } catch (e) {
      print("[ChatBG Task $tempId] General Error: $e");
      if (mounted) {
        print(
            "[ChatBG Task $tempId] Updating status to Failed (General Error)");
        conversationNotifier.updateMessageStatus(
          tempId,
          ChatMessageStatus.failed,
          errorMessage: "Upload/Send failed: ${e.toString()}",
        );
      }
    }
    // finally block removed - input re-enabling is handled in _initiateMediaSend.then()
  }

  // Snackbar helpers
  void _showSnackbar(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: duration,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    _showSnackbar(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    print(
        "[ChatDetailScreen Build: ${widget.matchUserId}] Rebuilding Widget... IsUploading: $_isUploadingMedia");

    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final wsState = ref.watch(webSocketStateProvider);

    // Refined Scroll Listener
    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
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

      // Scroll only when a NEW PENDING message is ADDED optimistically by the current user
      if (nextLength > prevLength &&
          next.messages.isNotEmpty &&
          next.messages.first.senderUserID == currentUserId &&
          next.messages.first.status == ChatMessageStatus.pending) {
        // More specific check
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
              child: Text(
                widget.matchName,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              Icons.circle,
              size: 10,
              color: wsState == WebSocketConnectionState.connected
                  ? Colors.green
                  : (wsState == WebSocketConnectionState.connecting
                      ? Colors.orange
                      : Colors.red),
            ),
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
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  // Builds the list of messages
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
          child: Text(
            "Error loading messages: ${state.error!.message}",
            style: GoogleFonts.poppins(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!state.isLoading && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Start the conversation!",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      addAutomaticKeepAlives: true, // Keep items alive when scrolled
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
            // Update Key to include more factors to ensure uniqueness and trigger rebuild only when necessary
            key: ValueKey(
                "${keyId}_${message.status}_${message.mediaUrl ?? message.localFilePath}"),
            message: message,
            isMe: isMe,
            showTail: showTail,
          ),
        );
      },
    );
  }

  // Builds the input area
  Widget _buildMessageInputArea() {
    final canSendText = ref.watch(messageInputProvider);
    // Use _isUploadingMedia to disable inputs
    final bool allowInput = !_isUploadingMedia;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              // Attachment button
              icon: Icon(Icons.add_circle_outline_rounded,
                  color: allowInput ? Colors.grey[600] : Colors.grey[300]),
              onPressed: allowInput
                  ? _showAttachmentOptions
                  : null, // Disable if uploading
              tooltip: "Attach Media",
            ),
            const SizedBox(width: 4.0),
            Expanded(
              // Text field
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    focusNode: _inputFocusNode,
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          allowInput ? "Type a message..." : "Uploading...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onChanged: (text) {
                      ref.read(messageInputProvider.notifier).state =
                          text.trim().isNotEmpty;
                    },
                    onSubmitted: (_) => canSendText && allowInput
                        ? _sendMessage()
                        : null, // Send only if allowed and has text
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.poppins(
                        color: Colors.black87, fontSize: 15),
                    enabled: allowInput, // Disable text field during upload
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              // Send button
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF8B5CF6),
              // Disable if no text OR if uploading media
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

// Provider to track if text input field has text
final messageInputProvider = StateProvider<bool>((ref) => false);

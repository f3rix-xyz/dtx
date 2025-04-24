// lib/views/chat_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // <-- Import Uint8List
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/models/media_upload_model.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/error_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/services/api_service.dart';
import 'package:dtx/services/chat_service.dart';
import 'package:dtx/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:dtx/repositories/media_repository.dart';

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

  // --- File size limits ---
  static const int _maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxVideoSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const int _maxAudioSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  // --- Allowed MIME types (adjust as needed) ---
  static final Set<String> _allowedMimeTypes = {
    // Images
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    // Videos
    'video/mp4', 'video/quicktime', 'video/webm', 'video/x-msvideo',
    'video/mpeg',
    // Audio
    'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/aac', 'audio/opus',
    'audio/webm', 'audio/mp4', 'audio/x-m4a',
    // Common Docs
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
    _inputFocusNode.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = ref.read(chatServiceProvider);
      if (ref.read(webSocketStateProvider) !=
          WebSocketConnectionState.connected) {
        print("[ChatDetailScreen] Connecting WebSocket...");
        chatService.connect();
      }
    });
  }

  void _handleFocusChange() {
    print(
        "[ChatDetailScreen] Input Field Focus Changed: ${_inputFocusNode.hasFocus}");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_handleFocusChange);
    _inputFocusNode.dispose();
    super.dispose();
  }

  // --- FIX: Helper function to read header bytes ---
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
      return null; // Return null on error
    }
  }
  // --- END FIX ---

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatService = ref.read(chatServiceProvider);
    final wsState = ref.read(webSocketStateProvider);

    if (wsState == WebSocketConnectionState.connected) {
      chatService.sendMessage(widget.matchUserId, text: text);
      _messageController.clear();
      ref.read(messageInputProvider.notifier).state = false;
      FocusScope.of(context).requestFocus(_inputFocusNode);
      Timer(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      print(
          "[ChatDetailScreen] Cannot send, WebSocket not connected. State: $wsState");
      _showErrorSnackbar("Cannot send message. Not connected.");
      chatService.connect();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentOptions() {
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
    if (_isUploadingMedia) return;

    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        // --- FIX: Use helper to read header bytes ---
        final headerBytes = await _readHeaderBytes(file);
        String? mimeType = lookupMimeType(filePath, headerBytes: headerBytes);
        mimeType ??= lookupMimeType(fileName) ?? 'application/octet-stream';
        // --- END FIX ---

        print(
            "[ChatDetailScreen] File selected: Name=$fileName, Path=$filePath, Size=$fileSize, MIME=$mimeType");

        // Validation (remains the same logic)
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

        _uploadAndSendMedia(file, fileName, mimeType);
      } else {
        print("[ChatDetailScreen] File picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking file: $e");
      _showErrorSnackbar("Error selecting file: ${e.toString()}");
    }
  }

  Future<void> _handleMediaSelection(ImageSource source) async {
    if (_isUploadingMedia) return;

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickMedia();

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileName = p.basename(pickedFile.path);
        final fileSize = await file.length();

        // --- FIX: Use helper to read header bytes ---
        final headerBytes = await _readHeaderBytes(file);
        final mimeType =
            lookupMimeType(pickedFile.path, headerBytes: headerBytes) ??
                'application/octet-stream';
        // --- END FIX ---

        print(
            "[ChatDetailScreen] Media selected: Name=$fileName, Path=${pickedFile.path}, Size=$fileSize, MIME=$mimeType");

        // Validation (remains the same logic)
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

        _uploadAndSendMedia(file, fileName, mimeType);
      } else {
        print("[ChatDetailScreen] Media picking cancelled.");
      }
    } catch (e) {
      print("[ChatDetailScreen] Error picking media: $e");
      _showErrorSnackbar("Error selecting media: ${e.toString()}");
    }
  }

  Future<void> _uploadAndSendMedia(
      File file, String fileName, String mimeType) async {
    if (!mounted) return;
    setState(() => _isUploadingMedia = true);
    _showSnackbar("Uploading ${p.basename(file.path)}...",
        duration: const Duration(minutes: 5)); // Show long duration snackbar

    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final chatService = ref.read(chatServiceProvider);

      // 1. Get Presigned URL
      print(
          "[ChatDetailScreen] Getting chat presigned URL for $fileName ($mimeType)");
      final urls = await mediaRepo.getChatMediaPresignedUrl(fileName, mimeType);
      final presignedUrl = urls['presigned_url'];
      final objectUrl = urls['object_url'];

      if (presignedUrl == null || objectUrl == null) {
        throw Exception("Failed to get upload URLs from server.");
      }

      // 2. Upload to S3
      print("[ChatDetailScreen] Uploading to S3: $fileName");
      final uploadModel = MediaUploadModel(
        file: file,
        fileName: fileName,
        fileType: mimeType,
        presignedUrl: presignedUrl,
      );
      bool uploadSuccess = await mediaRepo.retryUpload(uploadModel);

      if (!uploadSuccess) {
        throw Exception("Failed to upload media to storage.");
      }

      // 3. Send WebSocket Message
      print(
          "[ChatDetailScreen] Upload successful. Sending WebSocket message with objectUrl: $objectUrl");
      chatService.sendMessage(
        widget.matchUserId,
        mediaUrl: objectUrl, // Send the FINAL object URL
        mediaType: mimeType,
      );

      // 4. OPTIMISTIC UI UPDATE FOR SENDER (MEDIA)
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        final sentMediaMessage = ChatMessage(
          messageID:
              DateTime.now().millisecondsSinceEpoch, // Use timestamp as temp ID
          senderUserID: currentUserId,
          recipientUserID: widget.matchUserId,
          messageText: '', // Empty for media
          mediaUrl: objectUrl, // Use the final URL
          mediaType: mimeType,
          sentAt: DateTime.now(), // Use local time for immediate display
          isRead: false, // Mark as sent but not necessarily read
          readAt: null,
        );
        // Add to the local state immediately
        ref
            .read(conversationProvider(widget.matchUserId).notifier)
            .addSentMessage(sentMediaMessage);
        print("[ChatDetailScreen] Added sent MEDIA message optimistically.");

        // Scroll to bottom after adding optimistically
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      // --- END OPTIMISTIC UI UPDATE ---

      _showSnackbar("Media sent!", isError: false); // Show success
    } on ApiException catch (e) {
      print("[ChatDetailScreen] API Error during media send: ${e.message}");
      _showErrorSnackbar("Error sending media: ${e.message}");
    } catch (e) {
      print("[ChatDetailScreen] General Error during media send: $e");
      _showErrorSnackbar("Error sending media: ${e.toString()}");
    } finally {
      if (mounted) {
        // Hide indefinite snackbar if still showing
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _isUploadingMedia = false);
      }
    }
  }
// ... (Rest of the _ChatDetailScreenState class methods: _showSnackbar, _showErrorSnackbar, build, _buildMessagesList, _buildMessageInputArea etc.) ...

  void _showSnackbar(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
    final state = ref.watch(conversationProvider(widget.matchUserId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final wsState = ref.watch(webSocketStateProvider);

    ref.listen<ConversationState>(conversationProvider(widget.matchUserId),
        (prev, next) {
      bool messageAdded =
          (prev == null || next.messages.length > prev.messages.length);
      if (messageAdded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
          if (_isUploadingMedia)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: LinearProgressIndicator(
                color: Color(0xFF8B5CF6),
                backgroundColor: Color(0xFFEDE9FE),
              ),
            ),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ConversationState state, int? currentUserId) {
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: MessageBubble(
            message: message,
            isMe: isMe,
            showTail: showTail,
          ),
        );
      },
    );
  }

  Widget _buildMessageInputArea() {
    final canSend = ref.watch(messageInputProvider);

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
              icon: Icon(Icons.add_circle_outline_rounded,
                  color: Colors.grey[600]),
              onPressed: _isUploadingMedia ? null : _showAttachmentOptions,
              tooltip: "Attach Media",
              disabledColor: Colors.grey[300],
            ),
            const SizedBox(width: 4.0),
            Expanded(
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
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onChanged: (text) {
                      ref.read(messageInputProvider.notifier).state =
                          text.trim().isNotEmpty;
                    },
                    onTap: () {
                      print("[ChatDetailScreen] TextField tapped!");
                    },
                    onSubmitted: (_) =>
                        canSend && !_isUploadingMedia ? _sendMessage() : null,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.poppins(
                        color: Colors.black87, fontSize: 15),
                    enabled: !_isUploadingMedia,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF8B5CF6),
              onPressed: canSend && !_isUploadingMedia ? _sendMessage : null,
              tooltip: "Send Message",
              disabledColor: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

final messageInputProvider = StateProvider<bool>((ref) => false);

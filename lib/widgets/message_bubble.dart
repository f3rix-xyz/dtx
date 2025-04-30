// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/providers/service_provider.dart';
import 'package:dtx/services/chat_service.dart';
import 'package:dtx/widgets/reaction_emoji_picker.dart'; // Make sure this path is correct
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // Import for timestamp formatting

class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTail;
  final Function(ChatMessage message) onReplyInitiated;
  final String originalSenderDisplayName;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.showTail,
    required this.onReplyInitiated,
    required this.originalSenderDisplayName,
  }) : super(key: key);

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  OverlayEntry? _emojiPickerOverlay;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _removeEmojiPicker();
    super.dispose();
  }

  // --- Helpers ---
  String getFilenameFromUrl(String? url) {
    if (url == null || url.isEmpty) return "File";
    try {
      final uri = Uri.parse(url);
      String pathSegment = Uri.decodeComponent(uri.pathSegments.last);
      final parts = pathSegment.split('-');
      if (parts.length > 1 &&
          int.tryParse(parts[0]) != null &&
          parts[0].length > 10) {
        return parts.sublist(1).join('-');
      }
      return pathSegment;
    } catch (e) {
      try {
        return p.basename(url);
      } catch (e2) {
        return "File";
      }
    }
  }

  Future<void> _openMedia(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not launch $url')));
      if (kDebugMode) print("Could not launch $uri");
      return;
    }
    try {
      bool launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not launch $url')));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error launching file: $e')));
      if (kDebugMode) print("Error launching $uri: $e");
    }
  }

  Widget _buildMediaLoadingPlaceholder({required bool isMe}) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 40.0),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF8B5CF6)),
        ),
      );

  Widget _buildMediaErrorPlaceholder({required bool isMe}) => Container(
        color: Colors.grey[isMe ? 700 : 200]?.withOpacity(0.3),
        child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: isMe ? Colors.white60 : Colors.grey[500], size: 40)),
      );
  // --- End Helpers ---

  // --- _buildReplySnippet ---
  Widget _buildReplySnippet() {
    final repliedTo = widget.message;
    final textSnippet = repliedTo.repliedMessageTextSnippet;
    final mediaType = repliedTo.repliedMessageMediaType;
    final String originalSenderName = widget.originalSenderDisplayName;
    final Color snippetBgColor = widget.isMe
        ? const Color(0xFF7C3AED).withOpacity(0.8)
        : Colors.grey.shade200;
    final Color nameColor =
        widget.isMe ? Colors.white : const Color(0xFF7C3AED);
    final Color contentColor =
        widget.isMe ? Colors.white.withOpacity(0.9) : Colors.black54;
    final Color indicatorColor = nameColor;
    String contentPreview =
        (textSnippet != null && textSnippet.isNotEmpty) ? textSnippet : '';
    IconData? mediaIcon;
    if (contentPreview.isEmpty) {
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
        contentPreview = "File";
        mediaIcon = Icons.attach_file_outlined;
      } else {
        contentPreview = "Original message";
      }
    }
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 6),
      margin: const EdgeInsets.only(bottom: 4, left: 1, right: 1, top: 1),
      decoration: BoxDecoration(
        color: snippetBgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          left: BorderSide(color: indicatorColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            originalSenderName,
            style: GoogleFonts.poppins(
              color: nameColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mediaIcon != null)
                Icon(mediaIcon, size: 15, color: contentColor),
              if (mediaIcon != null && contentPreview.isNotEmpty)
                const SizedBox(width: 5),
              Flexible(
                child: Text(
                  contentPreview,
                  style: GoogleFonts.poppins(color: contentColor, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --- End _buildReplySnippet ---

  // --- Reaction Methods ---
  void _showEmojiPicker(BuildContext context, Offset globalPosition) {
    if (!mounted) return;
    if (kDebugMode)
      print(
          "[MessageBubble _showEmojiPicker] Attempting to show picker for message ID: ${widget.message.messageID}");
    _removeEmojiPicker();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final localBubblePosition = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    const pickerWidthEstimate = 260.0;
    const pickerHeightEstimate = 60.0;
    const double verticalGap = 8.0;
    final spaceAbove = localBubblePosition.dy - safeAreaTop;
    final bool showAbove =
        spaceAbove >= (pickerHeightEstimate + verticalGap + 10);
    double top = showAbove
        ? localBubblePosition.dy - pickerHeightEstimate - verticalGap
        : localBubblePosition.dy + size.height + verticalGap;
    top = top.clamp(safeAreaTop + 5,
        screenHeight - safeAreaBottom - pickerHeightEstimate - 5);
    double left =
        localBubblePosition.dx + (size.width / 2) - (pickerWidthEstimate / 2);
    left = left.clamp(10.0, screenWidth - pickerWidthEstimate - 10.0);

    if (kDebugMode) {
      print(
          "[MessageBubble _showEmojiPicker] Bubble Pos: $localBubblePosition, Size: $size");
      print(
          "[MessageBubble _showEmojiPicker] Calculated picker position: top=$top, left=$left (Show Above: $showAbove)");
    }

    _emojiPickerOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (kDebugMode)
                    print(
                        "[MessageBubble OverlayTap] Tap outside picker detected. Removing overlay.");
                  _removeEmojiPicker();
                },
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: top,
              left: left,
              child: ReactionEmojiPicker(
                // Assuming this is in widgets/reaction_emoji_picker.dart
                onEmojiSelected: (emoji) {
                  _handleReaction(emoji);
                  _removeEmojiPicker();
                },
              ),
            ),
          ],
        );
      },
    );

    try {
      Overlay.of(context).insert(_emojiPickerOverlay!);
      if (kDebugMode)
        print(
            "[MessageBubble _showEmojiPicker] Emoji picker overlay inserted successfully.");
    } catch (e) {
      if (kDebugMode)
        print(
            "[MessageBubble _showEmojiPicker] Error inserting overlay: $e. Overlay likely already exists or context invalid.");
      _emojiPickerOverlay = null;
    }
  }

  void _removeEmojiPicker() {
    if (_emojiPickerOverlay != null) {
      try {
        _emojiPickerOverlay!.remove();
        if (kDebugMode)
          print(
              "[MessageBubble _removeEmojiPicker] Emoji picker overlay removed.");
      } catch (e) {
        if (kDebugMode)
          print(
              "[MessageBubble _removeEmojiPicker] Error removing overlay (might have already been removed): $e");
      } finally {
        if (_emojiPickerOverlay != null) {
          _emojiPickerOverlay = null;
        }
      }
    }
  }

  void _handleReaction(String emoji) {
    if (widget.message.messageID <= 0) {
      if (kDebugMode)
        print(
            "[MessageBubble _handleReaction] Error: Cannot react to unsaved message ID: ${widget.message.messageID}.");
      return;
    }
    if (!mounted) return;

    if (kDebugMode)
      print(
          "[MessageBubble _handleReaction] Optimistically applying & sending reaction: MsgID=${widget.message.messageID}, Emoji=$emoji");

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      if (kDebugMode)
        print(
            "[MessageBubble _handleReaction] Error: Could not get current user ID for optimistic update.");
      return;
    }
    final otherUserId = widget.message.senderUserID == currentUserId
        ? widget.message.recipientUserID
        : widget.message.senderUserID;

    ref
        .read(conversationProvider(otherUserId).notifier)
        .optimisticallyApplyReaction(widget.message.messageID, emoji);
    if (kDebugMode)
      print(
          "[MessageBubble _handleReaction] Optimistic update called for ConversationNotifier($otherUserId).");

    ref.read(chatServiceProvider).sendReaction(widget.message.messageID, emoji);
    if (kDebugMode)
      print(
          "[MessageBubble _handleReaction] Reaction sent to backend via ChatService.");
  }

  Widget _buildReactionsDisplay() {
    final reactions = widget.message.reactionsSummary;
    final currentUserReaction = widget.message.currentUserReaction;
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();
    if (kDebugMode)
      print(
          "[MessageBubble _buildReactionsDisplay] Building reactions for message ${widget.message.messageID}. Summary: $reactions, CurrentUser: $currentUserReaction");
    final sortedEntries = reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Positioned(
      bottom: -8,
      left: widget.isMe ? null : 12,
      right: widget.isMe ? 12 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
            border: Border.all(color: Colors.grey.shade200, width: 0.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: sortedEntries.map((entry) {
            final emoji = entry.key;
            final count = entry.value;
            final bool isCurrentUserReaction = currentUserReaction == emoji;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: Container(
                padding: EdgeInsets.all(isCurrentUserReaction ? 2.5 : 1.0),
                decoration: isCurrentUserReaction
                    ? BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF8B5CF6), width: 1.0))
                    : null,
                child: Text(
                  '$emoji${count > 1 ? ' $count' : ''}',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  // --- End Reaction Methods ---

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep the mixin happy

    final message = widget.message;
    final isMe = widget.isMe;
    final showTail = widget.showTail;

    if (kDebugMode) {
      print(
          "[MessageBubble build] ID: ${message.messageID}, TempID: ${message.tempId}, isMe: $isMe, Status: ${message.status}, IsRead: ${message.isRead}");
    }

    final radius = Radius.circular(18.0);
    final borderRadius = BorderRadius.only(
      topLeft: message.isReply ? const Radius.circular(8) : radius,
      topRight: message.isReply ? const Radius.circular(8) : radius,
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );

    Widget messageContent;
    Widget? statusIcon;

    // --- Status Icon Logic (Keep Existing) ---
    if (isMe && message.status != ChatMessageStatus.sent) {
      switch (message.status) {
        case ChatMessageStatus.pending:
        case ChatMessageStatus.uploading:
          statusIcon =
              Icon(Icons.access_time_rounded, color: Colors.white70, size: 16);
          break;
        case ChatMessageStatus.failed:
          statusIcon = Tooltip(
            message: message.errorMessage ?? "Failed to send",
            child: Icon(Icons.error_outline_rounded,
                color: Colors.red.shade300, size: 18),
          );
          break;
        case ChatMessageStatus.sent:
          break; // Will be handled by read receipt logic below
      }
    }
    // --- End Status Icon Logic ---

    // --- Read Receipt Icon Logic (Phase 3) ---
    Widget? readReceiptIcon;
    if (isMe && message.status == ChatMessageStatus.sent) {
      readReceiptIcon = Icon(
        message.isRead ? Icons.done_all : Icons.done, // Double tick if read
        size: 16,
        color: message.isRead
            ? Colors.blueAccent
            : Colors.white70, // Different color for read
      );
      if (kDebugMode) {
        print(
            "[MessageBubble build] Read Receipt for Msg ID ${message.messageID}: isRead=${message.isRead}, Icon=${message.isRead ? 'done_all' : 'done'}");
      }
    }
    // --- End Read Receipt Icon Logic ---

    // --- Content Rendering Logic (Keep Existing) ---
    if (message.isMedia) {
      final mediaType = message.mediaType?.toLowerCase() ?? '';
      final String? displayPath =
          (message.localFilePath != null && message.localFilePath!.isNotEmpty)
              ? message.localFilePath
              : message.mediaUrl;
      final bool isUsingLocalFile =
          displayPath == message.localFilePath && message.localFilePath != null;
      final bool isMediaSent = message.status == ChatMessageStatus.sent;

      if (displayPath == null || displayPath.isEmpty) {
        messageContent = Text(
          "[Media Error]",
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
        );
      } else if (mediaType.startsWith('image/')) {
        // Image rendering
        Widget imageToShow;
        if (isUsingLocalFile) {
          imageToShow = Image.file(File(displayPath),
              key: ValueKey(displayPath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _buildMediaErrorPlaceholder(isMe: isMe));
        } else {
          imageToShow = CachedNetworkImage(
            key: ValueKey(displayPath),
            imageUrl: displayPath,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                _buildMediaLoadingPlaceholder(isMe: isMe),
            errorWidget: (context, url, error) =>
                _buildMediaErrorPlaceholder(isMe: isMe),
          );
        }
        messageContent = ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: imageToShow,
        );
      } else if (mediaType.startsWith('video/')) {
        // Video placeholder
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Container(
            /* ... video placeholder container ... */
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
                minHeight: 100),
            decoration: BoxDecoration(
                color: Colors.grey[isMe ? 700 : 300],
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              /* ... video details ... */
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_outlined,
                    size: 40, color: isMe ? Colors.white70 : Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  getFilenameFromUrl(displayPath),
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isMe ? Colors.white : Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isMediaSent ? "Tap to play video" : "Video",
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[500]),
                ),
              ],
            ),
          ),
        );
      } else if (mediaType.startsWith('audio/')) {
        // Audio placeholder/player
        final audioPlayerState = ref.watch(audioPlayerStateProvider);
        final currentPlayingUrl = ref.watch(currentAudioUrlProvider);
        final playerNotifier = ref.read(audioPlayerControllerProvider.notifier);
        final bool canPlay = isMediaSent && !isUsingLocalFile;
        final bool isThisLoading = canPlay &&
            currentPlayingUrl == displayPath &&
            audioPlayerState == AudioPlayerState.loading;
        final bool isThisPlaying = canPlay &&
            currentPlayingUrl == displayPath &&
            audioPlayerState == AudioPlayerState.playing;
        final bool isThisPaused = canPlay &&
            currentPlayingUrl == displayPath &&
            audioPlayerState == AudioPlayerState.paused;
        messageContent = Row(
            /* ... audio player row ... */
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: isThisLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isMe ? Colors.white : Color(0xFF8B5CF6)))
                    : Icon(isThisPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded),
                color: isMe
                    ? Colors.white
                    : (canPlay ? const Color(0xFF8B5CF6) : Colors.grey[400]),
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: canPlay ? (isThisPlaying ? 'Pause' : 'Play') : 'Audio',
                onPressed: isThisLoading || !canPlay
                    ? null
                    : () {
                        if (isThisPlaying)
                          playerNotifier.pause();
                        else if (isThisPaused)
                          playerNotifier.resume();
                        else
                          playerNotifier.play(displayPath!);
                      },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  getFilenameFromUrl(displayPath),
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isMe ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ]);
      } else {
        // Generic file placeholder
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Row(
              /* ... generic file row ... */
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    color: isMe ? Colors.white70 : Colors.grey[600], size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    getFilenameFromUrl(displayPath),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isMe ? Colors.white : Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ]),
        );
      }
    } else {
      // Text message content
      messageContent = Text(
        message.messageText,
        style: GoogleFonts.poppins(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.4, // Add line height for better readability
        ),
      );
    }
    // --- End Content Rendering ---

    // --- Main Bubble Structure ---
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: (message.reactionsSummary?.isNotEmpty ?? false)
                ? 18.0
                : 0.0), // Adjust bottom padding for reactions
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dismissible for Reply Swipe
            Dismissible(
              key: Key(message.messageID.toString() +
                  (message.tempId ?? '') +
                  '_dismissible'),
              direction: DismissDirection.startToEnd, // Swipe right to reply
              confirmDismiss: (direction) async {
                if (!mounted) return false;
                if (kDebugMode)
                  print(
                      "[MessageBubble] Swiped message ID: ${message.messageID}");
                widget.onReplyInitiated(message);
                return false; // Don't actually dismiss the widget
              },
              background: Container(
                /* ... Reply background ... */
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: borderRadius),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.reply, color: Colors.blue),
              ),
              child: GestureDetector(
                onLongPressStart: (LongPressStartDetails details) {
                  // Enable reactions only for received messages that are sent
                  if (!widget.isMe &&
                      message.status == ChatMessageStatus.sent &&
                      message.messageID > 0) {
                    if (kDebugMode)
                      print(
                          "[MessageBubble onLongPressStart] Long press detected on message ID: ${message.messageID}");
                    _showEmojiPicker(context, details.globalPosition);
                  } else {
                    if (kDebugMode)
                      print(
                          "[MessageBubble onLongPressStart] Ignoring long press. isMe=${widget.isMe}, status=${message.status}, id=${message.messageID}");
                  }
                },
                child: Container(
                  // Bubble Container
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  margin: EdgeInsets.only(
                    top: 4.0,
                    bottom: 4.0,
                    left: isMe ? 0 : (showTail ? 0 : 10.0),
                    right: isMe ? (showTail ? 0 : 10.0) : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF8B5CF6) : Colors.white,
                    borderRadius: borderRadius,
                    boxShadow: [
                      /* ... Shadow ... */
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show Reply Snippet if it's a reply
                        if (message.isReply) _buildReplySnippet(),
                        // Main Content Padding and Status/Time
                        Padding(
                          padding: message.isMedia &&
                                  (message.mediaType?.startsWith('image/') ??
                                      false)
                              ? EdgeInsets.zero // No padding for image media
                              : EdgeInsets.only(
                                  // Padding for text/other media
                                  left: 14.0,
                                  right: 14.0,
                                  top: message.isReply ? 6.0 : 10.0,
                                  bottom: 10.0 +
                                      (isMe
                                          ? 12.0
                                          : 0.0), // Add bottom padding only for 'Me' bubbles for status
                                ),
                          child: messageContent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- START: Timestamp and Status Icons Positioned ---
            Positioned(
              bottom: 4, // Adjust vertical position as needed
              right: isMe
                  ? (showTail ? 12 : 22)
                  : null, // Position based on tail & isMe
              left: !isMe ? (showTail ? 12 : 22) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timestamp
                  Text(
                    DateFormat.jm().format(message.sentAt), // Format time
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[500],
                    ),
                  ),
                  // Space before status icon (only for 'Me' messages)
                  if (isMe) const SizedBox(width: 4),
                  // Status Icon OR Read Receipt Icon (only for 'Me' messages)
                  if (isMe)
                    statusIcon ??
                        readReceiptIcon ??
                        const SizedBox
                            .shrink(), // Show status, then read, then nothing
                ],
              ),
            ),
            // --- END: Timestamp and Status Icons ---

            // Reactions Display (Keep as is)
            _buildReactionsDisplay(),
          ],
        ),
      ),
    );
  }
}

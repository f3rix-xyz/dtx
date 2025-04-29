// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/audio_player_provider.dart';
// *** ADDED: Import ConversationProvider for starting reply ***
import 'package:dtx/providers/conversation_provider.dart';
// *** ADDED: Import UserProvider to check if replied message sender is 'You' ***
import 'package:dtx/providers/user_provider.dart';
// *** END ADDED ***
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTail;
  // *** ADDED: Callback for initiating reply ***
  final Function(ChatMessage message) onReplyInitiated;
  // *** END ADDED ***

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.showTail,
    required this.onReplyInitiated, // *** ADDED ***
  }) : super(key: key);

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // --- Helpers (Keep as previously defined) ---
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
      print("Could not launch $uri");
      return;
    }
    try {
      bool launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching file: $e')),
        );
      }
      print("Error launching $uri: $e");
    }
  }

  Widget _buildMediaLoadingPlaceholder({required bool isMe}) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 40.0),
        child:
            CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
      ),
    );
  }

  Widget _buildMediaErrorPlaceholder({required bool isMe}) {
    return Container(
      color: Colors.grey[isMe ? 700 : 200]?.withOpacity(0.3),
      child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: isMe ? Colors.white60 : Colors.grey[500], size: 40)),
    );
  }
  // --- End Helpers ---

  // *** ADDED: Helper to build reply snippet UI ***
  Widget _buildReplySnippet() {
    final repliedTo = widget.message; // Actually, message *is* the reply
    final originalSenderId = repliedTo.repliedMessageSenderID;
    final textSnippet = repliedTo.repliedMessageTextSnippet;
    final mediaType = repliedTo.repliedMessageMediaType;
    final currentUserId = ref.read(currentUserIdProvider); // Check current user

    if (originalSenderId == null)
      return const SizedBox.shrink(); // Safety check

    final originalSenderName =
        originalSenderId == currentUserId ? "You" : "Them"; // Basic name logic
    final Color snippetColor = widget.isMe ? Colors.white70 : Colors.black54;
    final Color nameColor =
        widget.isMe ? Colors.white : const Color(0xFF7C3AED); // Highlight name

    String contentPreview = textSnippet ?? '';
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
        contentPreview = "File"; // Generic file
        mediaIcon = Icons.attach_file_outlined;
      } else {
        contentPreview = "Original message"; // Fallback
      }
    }

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 4),
      margin: const EdgeInsets.only(bottom: 4), // Space below snippet
      decoration: BoxDecoration(
        color: (widget.isMe ? Colors.white : Colors.black).withOpacity(0.1),
        // Slightly transparent background
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12), // Slightly less rounded than bubble
          topRight: Radius.circular(12),
        ),
        // Add a subtle left border for visual connection
        border: Border(
          left: BorderSide(
            color: nameColor.withOpacity(0.7),
            width: 3,
          ),
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
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min, // Row takes minimum space
            children: [
              if (mediaIcon != null)
                Icon(mediaIcon, size: 14, color: snippetColor),
              if (mediaIcon != null && contentPreview.isNotEmpty)
                const SizedBox(width: 4),
              Flexible(
                // Allow text to wrap if needed
                child: Text(
                  contentPreview,
                  style: GoogleFonts.poppins(
                    color: snippetColor,
                    fontSize: 13,
                  ),
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
  // *** END ADDED ***

  @override
  Widget build(BuildContext context) {
    super.build(context); // Needed for AutomaticKeepAliveClientMixin

    final message = widget.message;
    final isMe = widget.isMe;
    final showTail = widget.showTail;
    // final keyId = message.tempId ?? message.messageID.toString(); // Key not needed directly here anymore

    final radius = Radius.circular(18.0);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );

    Widget messageContent;
    Widget? statusIcon;

    // Status Icon Logic (no change)
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
          break;
      }
    }

    // Content Rendering Logic (no change needed inside this block)
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
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Container(
            /* ... video placeholder ... */
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
                minHeight: 100),
            decoration: BoxDecoration(
                color: Colors.grey[isMe ? 700 : 300],
                borderRadius: BorderRadius.circular(8)),
            child: Column(
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
            /* ... audio content ... */
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
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Row(
              /* ... generic file content ... */
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
      messageContent = Text(
        message.messageText,
        style: GoogleFonts.poppins(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }

    // --- Build Final Bubble ---
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      // *** MODIFIED: Wrap bubble content in Dismissible for swipe gesture ***
      child: Dismissible(
        key: Key(message.messageID.toString()), // Unique key for dismissible
        direction: DismissDirection.startToEnd, // Swipe right to reply
        confirmDismiss: (direction) async {
          print("[MessageBubble] Swiped message ID: ${message.messageID}");
          widget.onReplyInitiated(message); // Trigger the callback
          return false; // Do not actually dismiss the widget
        },
        background: Container(
          // Visual feedback during swipe (optional)
          color: Colors.blue.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: const Icon(Icons.reply, color: Colors.blue),
        ),
        child: Container(
          // The original message bubble container
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
              // Use Column to stack reply snippet and content
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Align content left/right
              children: [
                // *** ADDED: Conditionally display reply snippet ***
                if (message.isReply) _buildReplySnippet(),
                // *** END ADDED ***

                // Original content padding and stack
                Stack(
                  children: [
                    Padding(
                      padding: message.isMedia &&
                              (message.mediaType?.startsWith('image/') ?? false)
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(
                              horizontal: 14.0, vertical: 10.0),
                      child: messageContent,
                    ),
                    if (statusIcon != null)
                      Positioned(
                        bottom: 4,
                        right: isMe ? 4 : null,
                        left: isMe ? null : 4,
                        child: statusIcon,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // *** END MODIFIED ***
    );
  }
}

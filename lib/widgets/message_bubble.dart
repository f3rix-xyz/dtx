// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:dtx/providers/conversation_provider.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:flutter/foundation.dart';
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
  final Function(ChatMessage message) onReplyInitiated;
  // *** ADDED: Parameter for original sender's display name ***
  final String originalSenderDisplayName;
  // *** END ADDED ***

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.showTail,
    required this.onReplyInitiated,
    required this.originalSenderDisplayName, // *** ADDED ***
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

  // --- *** MODIFIED: _buildReplySnippet *** ---
  Widget _buildReplySnippet() {
    final repliedTo = widget.message;
    final textSnippet = repliedTo.repliedMessageTextSnippet;
    final mediaType = repliedTo.repliedMessageMediaType;

    // Use the display name passed from the parent
    final String originalSenderName = widget.originalSenderDisplayName;

    // Define colors based on who sent the *current* message (the reply)
    final Color snippetBgColor = widget.isMe
        ? const Color(0xFF7C3AED)
            .withOpacity(0.8) // Slightly darker purple for own reply snippet
        : Colors.grey.shade200; // Light grey for other's reply snippet
    final Color nameColor = widget.isMe
        ? Colors.white // White name on purple
        : const Color(0xFF7C3AED); // Purple name on grey
    final Color contentColor = widget.isMe
        ? Colors.white.withOpacity(0.9) // Slightly lighter content on purple
        : Colors.black54; // Darker grey content on grey
    final Color indicatorColor = nameColor; // Match indicator to name color

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
      padding: const EdgeInsets.only(
          left: 8, right: 8, top: 6, bottom: 6), // Adjusted padding
      margin: const EdgeInsets.only(
          bottom: 4,
          left: 1,
          right: 1,
          top: 1), // Add slight margin inside bubble
      decoration: BoxDecoration(
        color: snippetBgColor, // Use dynamic background
        // Apply rounding *only* to top corners if it's the first element
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14), // Slightly less rounded
          topRight: Radius.circular(14),
        ),
        // Apply the left border indicator
        border: Border(
          left: BorderSide(
            color: indicatorColor, // Use dynamic indicator color
            width: 4, // Slightly thicker indicator
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            originalSenderName, // Use the passed display name
            style: GoogleFonts.poppins(
              color: nameColor, // Use dynamic name color
              fontWeight: FontWeight.w600,
              fontSize: 13, // Slightly larger name
            ),
          ),
          const SizedBox(height: 3), // Adjust spacing
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mediaIcon != null)
                Icon(mediaIcon,
                    size: 15, color: contentColor), // Slightly larger icon
              if (mediaIcon != null && contentPreview.isNotEmpty)
                const SizedBox(width: 5),
              Flexible(
                child: Text(
                  contentPreview,
                  style: GoogleFonts.poppins(
                    color: contentColor, // Use dynamic content color
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
  // --- *** END MODIFIED *** ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final message = widget.message;
    final isMe = widget.isMe;
    final showTail = widget.showTail;

    // --- Log message data (keep) ---
    if (kDebugMode) {
      print("--- Building MessageBubble ---");
      print("  Msg ID: ${message.messageID}");
      print("  Temp ID: ${message.tempId}");
      print("  Is Me: $isMe");
      print("  Show Tail: $showTail");
      print("  Is Media: ${message.isMedia}");
      print("  Text: '${message.messageText}'");
      print("  Media URL: ${message.mediaUrl}");
      print("  Media Type: ${message.mediaType}");
      print("  Status: ${message.status}");
      print("  Is Reply: ${message.isReply}");
      print("  Reply To ID: ${message.replyToMessageID}");
      print("  Replied Sender ID: ${message.repliedMessageSenderID}");
      print("  Replied Snippet: '${message.repliedMessageTextSnippet}'");
      print("  Replied Media Type: ${message.repliedMessageMediaType}");
      print("-----------------------------");
    }
    // --- End Log ---

    final radius = Radius.circular(18.0);
    // *** MODIFIED: Adjust borderRadius based on whether it's a reply ***
    final borderRadius = BorderRadius.only(
      topLeft: message.isReply
          ? const Radius.circular(8)
          : radius, // Less rounded if reply
      topRight: message.isReply
          ? const Radius.circular(8)
          : radius, // Less rounded if reply
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );
    // *** END MODIFIED ***

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
      // ... (existing media rendering logic - no changes here) ...
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
            /* ... video placeholder ... */ padding: const EdgeInsets.all(10),
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
            /* ... audio content ... */ mainAxisSize: MainAxisSize.min,
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
              /* ... generic file content ... */ mainAxisSize: MainAxisSize.min,
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

    // --- Build Final Bubble Structure ---
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: Key(message.messageID.toString()),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          if (kDebugMode)
            print("[MessageBubble] Swiped message ID: ${message.messageID}");
          widget.onReplyInitiated(message);
          return false; // Do not actually dismiss
        },
        background: Container(
          // Simple background, ensures the bubble decoration shows correctly
          decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: borderRadius // Match bubble radius
              ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: const Icon(Icons.reply, color: Colors.blue),
        ),
        child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // *** Conditionally display reply snippet ***
                if (message.isReply) _buildReplySnippet(),

                // Original content and status icon
                Stack(
                  children: [
                    Padding(
                      // *** MODIFIED: Add extra padding if it's a reply for visual separation ***
                      padding: message.isMedia &&
                              (message.mediaType?.startsWith('image/') ?? false)
                          ? EdgeInsets.zero // No padding for images
                          : EdgeInsets.only(
                              // Add vertical padding conditionally
                              left: 14.0,
                              right: 14.0,
                              top: message.isReply
                                  ? 6.0
                                  : 10.0, // Less top padding if reply
                              bottom: 10.0,
                            ),
                      // *** END MODIFIED ***
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
    );
  }
}

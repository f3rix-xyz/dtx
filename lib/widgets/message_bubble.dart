// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

// Convert to ConsumerStatefulWidget and add AutomaticKeepAliveClientMixin
class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTail;

  const MessageBubble({
    Key? key, // Use Key? key
    required this.message,
    required this.isMe,
    required this.showTail,
  }) : super(key: key); // Pass key to super

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  // Add mixin

  // --- Override wantKeepAlive ---
  @override
  bool get wantKeepAlive => true; // Keep the state alive

  // --- Move helpers inside State class ---
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
    return Container(
      color: Colors.grey[isMe ? 700 : 300]?.withOpacity(0.5),
      child: Center(
          child: CircularProgressIndicator(
              color: isMe ? Colors.white70 : Colors.grey[500])),
    );
  }

  Widget _buildMediaErrorPlaceholder({required bool isMe}) {
    return Container(
      color: Colors.red[isMe ? 900 : 100]?.withOpacity(0.5),
      child: Center(
          child: Icon(Icons.error_outline,
              color: isMe ? Colors.red.shade200 : Colors.red.shade400,
              size: 40)),
    );
  }
  // --- End Helpers ---

  @override
  Widget build(BuildContext context) {
    // --- IMPORTANT: Call super.build(context) ---
    super.build(context);

    // Access widget properties using widget.*
    final message = widget.message;
    final isMe = widget.isMe;
    final showTail = widget.showTail;

    final keyId = message.tempId ?? message.messageID.toString();
    print(
        "[MessageBubble Build: ${keyId}] Rebuilding. Status: ${message.status}, isMedia: ${message.isMedia}, LocalPath: ${message.localFilePath != null}, MediaUrl: ${message.mediaUrl != null}");

    final radius = Radius.circular(18.0);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );
    Widget messageContent;
    Widget? statusIcon;

    // --- Status Icon Logic ---
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

    // --- Content Rendering Logic ---
    if (message.isMedia) {
      final mediaType = message.mediaType?.toLowerCase() ?? '';
      // Still prioritize local path if it exists
      final String? displayPath =
          (message.localFilePath != null && message.localFilePath!.isNotEmpty)
              ? message.localFilePath
              : message.mediaUrl;
      final bool isUsingLocalFile =
          displayPath == message.localFilePath && message.localFilePath != null;
      final bool isMediaSent = message.status == ChatMessageStatus.sent;

      print(
          "[MessageBubble Build $keyId] Content Logic. isUsingLocalFile: $isUsingLocalFile, displayPath: $displayPath, isMediaSent: $isMediaSent");

      if (displayPath == null || displayPath.isEmpty) {
        messageContent = Text(
          "[Media Error]",
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
        );
      }
      // --- IMAGE ---
      else if (mediaType.startsWith('image/')) {
        print(
            "[MessageBubble Build $keyId] Rendering Image. Source: ${isUsingLocalFile ? 'File' : 'Network'}");
        Widget imageToShow;
        if (isUsingLocalFile) {
          imageToShow = Image.file(File(displayPath),
              key: ValueKey(displayPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildMediaErrorPlaceholder(isMe: isMe));
        } else {
          // Use CachedNetworkImage for network URLs
          imageToShow = CachedNetworkImage(
            key: ValueKey(displayPath),
            imageUrl: displayPath,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                _buildMediaLoadingPlaceholder(isMe: isMe),
            errorWidget: (context, url, error) =>
                _buildMediaErrorPlaceholder(isMe: isMe),
          );
        }
        messageContent = ClipRRect(
          borderRadius: BorderRadius.circular(8.0), // Round corners for image
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: imageToShow,
          ),
        );
      }
      // --- VIDEO ---
      else if (mediaType.startsWith('video/')) {
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Container(
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
      }
      // --- AUDIO ---
      else if (mediaType.startsWith('audio/')) {
        final audioPlayerState = ref.watch(
            audioPlayerStateProvider); // Use ref from ConsumerStatefulWidget
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

        messageContent = Row(mainAxisSize: MainAxisSize.min, children: [
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
                  fontSize: 13, color: isMe ? Colors.white : Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ]);
      }
      // --- GENERIC FILE ---
      else {
        messageContent = InkWell(
          onTap: isMediaSent && !isUsingLocalFile
              ? () => _openMedia(context, displayPath)
              : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file_outlined,
                color: isMe ? Colors.white70 : Colors.grey[600], size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                getFilenameFromUrl(displayPath),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: isMe ? Colors.white : Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ]),
        );
      }
    } else {
      // --- TEXT MESSAGE ---
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
          // Clip bubble content if it's an image
          borderRadius: message.isMedia &&
                  (message.mediaType?.startsWith('image/') ?? false)
              ? BorderRadius.circular(8.0)
              : BorderRadius.zero,
          child: Stack(
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
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: statusIcon,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} // End _MessageBubbleState

// lib/widgets/message_bubble.dar// lib/widgets/message_bubble.dart
import 'dart:io';
import 'package:dtx/models/chat_message.dart';
import 'package:dtx/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
// import 'package:open_file_plus/open_file_plus.dart'; // <-- REMOVE this import
import 'package:path/path.dart' as p;
// import 'package:video_player/video_player.dart'; // Keep commented if not implemented
import 'package:url_launcher/url_launcher.dart'; // <-- ADD this import

class MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTail;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showTail,
  });

  // Helper to get a displayable filename (remains the same)
  String getFilenameFromUrl(String? url) {
    if (url == null || url.isEmpty) return "File";
    try {
      final uri = Uri.parse(url);
      String pathSegment = Uri.decodeComponent(uri.pathSegments.last);
      final parts = pathSegment.split('-');
      if (parts.length > 1 && int.tryParse(parts[0]) != null) {
        return parts.sublist(1).join('-');
      }
      return pathSegment;
    } catch (e) {
      return "File";
    }
  }

  // --- UPDATED: Helper to launch URLs or open files using url_launcher ---
  Future<void> _openMedia(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    // For file URIs, ensure it's properly formatted
    // Note: Launching local file URIs directly might have limitations
    // depending on the platform version and file location due to security restrictions.
    // If 'url' is a local path, convert it: final Uri uri = Uri.file(url);

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
      // Attempt to launch using external application mode
      bool launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
        print("Could not launch $uri even after canLaunchUrl was true?");
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
  // --- END UPDATED HELPER ---

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = Radius.circular(18.0);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );

    Widget messageContent;
    if (message.isMedia) {
      final mediaType = message.mediaType?.toLowerCase() ?? '';
      final mediaUrl = message.mediaUrl!;

      if (mediaType.startsWith('image/')) {
        // --- Image rendering (no change needed here) ---
        messageContent = ClipRRect(
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: Center(
                          child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: Colors.grey[400]))),
              errorBuilder: (ctx, err, st) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.grey[400], size: 40))),
            ),
          ),
        );
      } else if (mediaType.startsWith('video/')) {
        // --- Video placeholder (using _openMedia) ---
        messageContent = InkWell(
          onTap: () => _openMedia(context, mediaUrl), // Use the updated helper
          child: Container(
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
              minHeight: 100,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.deepPurple.shade100 : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_outlined,
                    size: 40,
                    color: isMe ? Colors.deepPurple : Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  getFilenameFromUrl(mediaUrl),
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color:
                          isMe ? Colors.deepPurple.shade900 : Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Tap to play video",
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color:
                          isMe ? Colors.deepPurple.shade700 : Colors.grey[500]),
                ),
              ],
            ),
          ),
        );
      } else if (mediaType.startsWith('audio/')) {
        // --- Audio Player (no change needed here) ---
        final audioPlayerState = ref.watch(audioPlayerStateProvider);
        final currentPlayingUrl = ref.watch(currentAudioUrlProvider);
        final playerNotifier = ref.read(audioPlayerControllerProvider.notifier);
        final isThisLoading = currentPlayingUrl == mediaUrl &&
            audioPlayerState == AudioPlayerState.loading;
        final isThisPlaying = currentPlayingUrl == mediaUrl &&
            audioPlayerState == AudioPlayerState.playing;
        final isThisPaused = currentPlayingUrl == mediaUrl &&
            audioPlayerState == AudioPlayerState.paused;

        messageContent = Row(
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
              color: isMe ? Colors.white : const Color(0xFF8B5CF6),
              iconSize: 36,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isThisLoading
                  ? null
                  : () {
                      if (isThisPlaying)
                        playerNotifier.pause();
                      else if (isThisPaused)
                        playerNotifier.resume();
                      else
                        playerNotifier.play(mediaUrl);
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                getFilenameFromUrl(mediaUrl),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: isMe ? Colors.white : Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        );
      } else {
        // --- Generic File (using _openMedia) ---
        messageContent = InkWell(
          onTap: () => _openMedia(context, mediaUrl), // Use the updated helper
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  color: isMe ? Colors.white70 : Colors.grey[600], size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  getFilenameFromUrl(mediaUrl),
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isMe ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // --- Text message (no change needed here) ---
      messageContent = Text(
        message.messageText,
        style: GoogleFonts.poppins(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }

    // --- Bubble Container (no change needed here) ---
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
        padding: message.isMedia &&
                !(message.mediaType?.startsWith('audio/') ??
                    false) // Less padding for non-audio media
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
        child: messageContent,
      ),
    );
  }
}

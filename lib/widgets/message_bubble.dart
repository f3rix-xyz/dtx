// lib/widgets/message_bubble.dart
import 'package:dtx/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showTail; // Add this parameter

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showTail, // Require showTail
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(18.0);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      // Apply tail based on isMe and showTail
      bottomLeft: isMe || !showTail ? radius : Radius.zero,
      bottomRight: !isMe || !showTail ? radius : Radius.zero,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, // Max width
        ),
        margin: EdgeInsets.only(
          top: 4.0,
          bottom: 4.0,
          left: isMe ? 0 : 10.0, // Margin for alignment
          right: isMe ? 10.0 : 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
            color: isMe ? const Color(0xFF8B5CF6) : Colors.white,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: Offset(0, 1),
              )
            ]),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for column height
          children: [
            Text(
              message.messageText,
              style: GoogleFonts.poppins(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            // Optional: Add timestamp inside the bubble
            /*
             Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                   message.formattedTimestamp,
                   style: GoogleFonts.poppins(
                      color: isMe ? Colors.white70 : Colors.grey[500],
                      fontSize: 10,
                   ),
                ),
             ),
             */
          ],
        ),
      ),
    );
  }
}

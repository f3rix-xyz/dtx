import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:dtx/models/user_model.dart';
import 'package:dtx/providers/user_provider.dart';
import 'package:dtx/utils/app_enums.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final textTheme = Theme.of(context).textTheme;
    final age = user.dateOfBirth != null
        ? DateTime.now().difference(user.dateOfBirth!).inDays ~/ 365
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name} ${user.lastName ?? ""}'.trim(),
            style: textTheme.headlineSmall),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.edit))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Media Gallery Section
          _buildMediaSection(user.mediaUrls),
          const SizedBox(height: 24),

          // Basic Info Row
          Row(
            children: [
              if (age != null) _buildInfoChip('$age years'),
              if (user.gender != null) _buildInfoChip(user.gender!.label),
              if (user.hometown != null) _buildInfoChip('📍 ${user.hometown}'),
            ]
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: e,
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Dating Intention
          if (user.datingIntention != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Looking for: ${user.datingIntention!.label}',
                style: textTheme.bodyLarge,
              ),
            ),

          // Prompts Section
          if (user.prompts.isNotEmpty) _buildPromptsSection(user.prompts),
          const SizedBox(height: 24),

          // Audio Prompt
          if (user.audioPrompt != null) _buildAudioSection(user.audioPrompt!),
          const SizedBox(height: 24),

          // Detailed Info Grid
          _buildDetailsGrid(user),
        ],
      ),
    );
  }

  Widget _buildMediaSection(List<String>? mediaUrls) {
    final images = mediaUrls?.take(6).toList() ?? [];
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.isNotEmpty ? images.length : 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          return images.isNotEmpty
              ? _buildMediaItem(images[index])
              : _buildEmptyMedia();
        },
      ),
    );
  }

  Widget _buildMediaItem(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url, width: 160, height: 200, fit: BoxFit.cover),
    );
  }

  Widget _buildEmptyMedia() {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.camera_alt, size: 40),
    );
  }

  Widget _buildPromptsSection(List<Prompt> prompts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prompts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...prompts.take(3).map((p) => _buildPromptCard(p)).toList(),
      ],
    );
  }

  Widget _buildPromptCard(Prompt prompt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt.question,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(prompt.answer),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSection(AudioPromptModel audio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Voice Prompt',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.mic, color: Colors.blue),
            title: Text(audio.prompt.label),
            subtitle: const Text('Tap to play'),
            trailing: IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {/* Audio playback logic */}),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsGrid(UserModel user) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      children: [
        if (user.height != null) _buildDetailItem('Height', user.height!),
        if (user.religiousBeliefs != null)
          _buildDetailItem('Religion', user.religiousBeliefs!.label),
        if (user.jobTitle != null) _buildDetailItem('Job', user.jobTitle!),
        if (user.education != null)
          _buildDetailItem('Education', user.education!),
        if (user.drinkingHabit != null)
          _buildDetailItem('Drinking', user.drinkingHabit!.label),
        if (user.smokingHabit != null)
          _buildDetailItem('Smoking', user.smokingHabit!.label),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Chip(
      backgroundColor: Colors.grey.shade200,
      label: Text(text),
    );
  }
}

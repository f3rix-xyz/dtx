
// providers/audio_player_provider.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioPlayerState {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

final audioPlayerStateProvider = StateProvider<AudioPlayerState>((ref) => AudioPlayerState.idle);
final currentAudioUrlProvider = StateProvider<String?>((ref) => null);

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  
  player.onPlayerComplete.listen((_) {
    ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.completed;
  });
  
  player.onPlayerStateChanged.listen((state) {
    if (state == PlayerState.playing) {
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.playing;
    } else if (state == PlayerState.paused) {
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.paused;
    } else if (state == PlayerState.stopped) {
      ref.read(audioPlayerStateProvider.notifier).state = AudioPlayerState.idle;
    }
  });
  
  // Handle cleanup when the provider is disposed
  ref.onDispose(() {
    player.dispose();
  });
  
  return player;
});

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final Ref ref;
  final AudioPlayer _player;
  
  AudioPlayerNotifier(this.ref)
      : _player = ref.read(audioPlayerProvider),
        super(AudioPlayerState.idle);
  
  Future<void> play(String url) async {
    try {
      // If another audio is playing, stop it
      if (state == AudioPlayerState.playing) {
        await _player.stop();
      }
      
      state = AudioPlayerState.loading;
      ref.read(currentAudioUrlProvider.notifier).state = url;
      
      await _player.play(UrlSource(url));
      // State will be updated via listener in audioPlayerProvider
    } catch (e) {
      print("Error playing audio: $e");
      state = AudioPlayerState.error;
    }
  }
  
  Future<void> pause() async {
    if (state == AudioPlayerState.playing) {
      await _player.pause();
      // State will be updated via listener
    }
  }
  
  Future<void> resume() async {
    if (state == AudioPlayerState.paused) {
      await _player.resume();
      // State will be updated via listener
    }
  }
  
  Future<void> stop() async {
    await _player.stop();
    ref.read(currentAudioUrlProvider.notifier).state = null;
    // State will be updated via listener
  }
}

final audioPlayerControllerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  return AudioPlayerNotifier(ref);
});

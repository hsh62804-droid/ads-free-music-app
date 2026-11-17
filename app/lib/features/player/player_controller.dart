import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import '../../core/constants/api_constants.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import 'audio_handler.dart';
import 'player_state.dart';

final audioHandlerProvider = Provider<AppAudioHandler>((ref) {
  throw UnimplementedError('Initialize audioHandler in main');
});

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository();
});

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final repo = ref.watch(musicRepositoryProvider);
  return PlayerController(handler, repo);
});

class PlayerController extends StateNotifier<PlayerState> {
  final AppAudioHandler _audioHandler;
  final MusicRepository _musicRepo;

  PlayerController(this._audioHandler, this._musicRepo)
      : super(const PlayerState()) {
    _bindHandlerEvents();
  }

  void _bindHandlerEvents() {
    _audioHandler.onNextRequested = next;
    _audioHandler.onPreviousRequested = previous;
    _audioHandler.onPlaybackCompleted = _onTrackCompleted;

    // Listen to player position
    _audioHandler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    // Listen to track duration
    _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    // Listen to playing / buffering states
    _audioHandler.player.playerStateStream.listen((ps) {
      final isPlaying = ps.playing;
      final isBuffering = ps.processingState == ProcessingState.buffering ||
          ps.processingState == ProcessingState.loading;
      state = state.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
    });
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    final activeQueue = queue ?? [song];
    final index = activeQueue.indexWhere((s) => s.id == song.id);

    state = state.copyWith(
      currentSong: song,
      queue: activeQueue,
      currentIndex: index >= 0 ? index : 0,
      position: Duration.zero,
      duration: Duration(seconds: song.durationSeconds),
      isBuffering: true,
    );

    // Stream URL routed through backend redirect/proxy endpoint with Range & CORS support
    final streamUrl = kIsWeb
        ? '${ApiConstants.baseUrl}/songs/${song.id}/stream?proxy=true'
        : '${ApiConstants.baseUrl}/songs/${song.id}/stream';
    await _audioHandler.playSong(song, streamUrl);

    // Preload next track in queue with just_audio for instant playback on skip
    _preloadNextSong(activeQueue, index >= 0 ? index : 0);

    // Record initial playback event
    _musicRepo.recordHistory(
      songId: song.id,
      playedDurationSeconds: 0,
      completed: false,
    );
  }

  /// Resolve current preview track to full version (e.g. YouTube or local) and play it
  Future<void> playFullVersion() async {
    final current = state.currentSong;
    if (current == null) return;
    state = state.copyWith(isBuffering: true);
    final fullSong = await _musicRepo.getFullVersion(current.id);
    if (fullSong != null && fullSong.id != current.id) {
      await playSong(fullSong, queue: state.queue);
    } else {
      state = state.copyWith(isBuffering: false);
    }
  }

  void _preloadNextSong(List<SongModel> queue, int currentIndex) {
    if (queue.isEmpty) return;
    final nextIndex = currentIndex + 1;
    if (nextIndex < queue.length) {
      final nextSong = queue[nextIndex];
      final nextStreamUrl = kIsWeb
          ? '${ApiConstants.baseUrl}/songs/${nextSong.id}/stream?proxy=true'
          : '${ApiConstants.baseUrl}/songs/${nextSong.id}/stream';
      _audioHandler.preloadNextSong(nextStreamUrl);
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> rewind10() async {
    final newPos = state.position - const Duration(seconds: 10);
    await seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> forward10() async {
    final newPos = state.position + const Duration(seconds: 10);
    await seek(newPos > state.duration ? state.duration : newPos);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;

    if (state.repeatMode == RepeatMode.one && state.currentSong != null) {
      await seek(Duration.zero);
      await _audioHandler.play();
      return;
    }

    int nextIndex;
    if (state.isShuffle) {
      nextIndex = Random().nextInt(state.queue.length);
    } else {
      nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.queue.length) {
        if (state.repeatMode == RepeatMode.all) {
          nextIndex = 0;
        } else {
          return; // End of queue
        }
      }
    }

    final nextSong = state.queue[nextIndex];
    await playSong(nextSong, queue: state.queue);
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    // If more than 3 seconds in, restart the song
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = state.currentIndex - 1;
    if (prevIndex >= 0) {
      final prevSong = state.queue[prevIndex];
      await playSong(prevSong, queue: state.queue);
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  Future<void> toggleLikeCurrentSong() async {
    final song = state.currentSong;
    if (song == null) return;

    final newStatus = await _musicRepo.toggleLike(song.id, song.isLiked);
    final updated = song.copyWith(isLiked: newStatus);

    state = state.copyWith(currentSong: updated);
  }

  void _onTrackCompleted() {
    // Log completed playback to history
    if (state.currentSong != null) {
      _musicRepo.recordHistory(
        songId: state.currentSong!.id,
        playedDurationSeconds: state.position.inSeconds,
        completed: true,
      );
    }
    next();
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/song_model.dart';

/// Background audio handler bridging just_audio and audio_service for notification controls.
class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _preloadPlayer = AudioPlayer();

  // Callbacks for queue management
  void Function()? onNextRequested;
  void Function()? onPreviousRequested;
  void Function()? onPlaybackCompleted;

  AppAudioHandler() {
    _initAudioStreams();
  }

  AudioPlayer get player => _player;

  /// Preload the upcoming track in the background so it plays instantaneously when skipped to
  Future<void> preloadNextSong(String streamUrl) async {
    try {
      await _preloadPlayer.setUrl(streamUrl, preload: true);
    } catch (_) {
      // Gracefully ignore preload network timeouts or partial stream errors
    }
  }

  void _initAudioStreams() {
    // Propagate player state (playing, buffering, completed) to OS media session
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );

      // Handle track completion
      if (_player.processingState == ProcessingState.completed) {
        onPlaybackCompleted?.call();
      }
    });
  }

  /// Load and play a song
  Future<void> playSong(SongModel song, String streamUrl) async {
    // Update system notification metadata
    mediaItem.add(
      MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album ?? 'Audius / Jamendo',
        duration: Duration(seconds: song.durationSeconds),
        artUri: song.artworkUrl != null ? Uri.tryParse(song.artworkUrl!) : null,
      ),
    );

    try {
      await _player.stop();
      await _player.setUrl(streamUrl);
      await _player.play();
    } catch (e) {
      // Audio source error handling
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async => onNextRequested?.call();

  @override
  Future<void> skipToPrevious() async => onPreviousRequested?.call();
}

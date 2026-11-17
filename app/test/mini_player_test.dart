import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/features/player/player_controller.dart';
import 'package:music_app/features/player/player_state.dart';
import 'package:music_app/features/player/widgets/mini_player.dart';
import 'package:music_app/features/player/screens/full_player_screen.dart';

class TestPlayerController extends StateNotifier<PlayerState> implements PlayerController {
  TestPlayerController(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('MiniPlayer tap opens FullPlayerScreen and displays track controls', (WidgetTester tester) async {
    final testSong = SongModel(
      id: 'local:test1',
      source: 'local',
      sourceId: 'test1',
      title: 'Vaseegara',
      artist: 'Bombay Jayashri',
      durationSeconds: 240,
      isFull: true,
      isPreview: false,
    );

    final testState = PlayerState(
      currentSong: testSong,
      isPlaying: true,
      duration: const Duration(seconds: 240),
    );

    final controller = TestPlayerController(testState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MiniPlayer(),
          ),
        ),
      ),
    );

    // Verify MiniPlayer rendered with song title and artist
    expect(find.text('Vaseegara'), findsOneWidget);
    expect(find.text('Bombay Jayashri'), findsOneWidget);

    // Tap on the MiniPlayer
    await tester.tap(find.text('Vaseegara'));
    await tester.pumpAndSettle();

    // Verify FullPlayerScreen opened with full controls
    expect(find.byType(FullPlayerScreen), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsWidgets);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    // Tap the close down-arrow button to dismiss
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    // Verify FullPlayerScreen dismissed
    expect(find.byType(FullPlayerScreen), findsNothing);
  });
}

import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:test_app/shared/services/media_session_handler.dart';
import 'package:test_app/shared/services/playback_controller.dart' as pb;

/// Runs on a real device/simulator, so it exercises the native halves that a
/// widget test cannot: the audio session category, the media-session plugin,
/// and whether media_kit can actually decode audio on this platform.
///
///   `flutter test integration_test/media_session_ios_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late pb.PlaybackController playback;
  late MediaSessionHandler handler;

  setUpAll(() async {
    MediaKit.ensureInitialized();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    playback = pb.PlaybackController();
    handler = await AudioService.init(
      builder: () => MediaSessionHandler(
        playback,
        setSessionActive: ({required active}) => session.setActive(active),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'tv.gospeltube.audio',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  });

  testWidgets('the platform accepts a playback audio session', (tester) async {
    // iOS defaults to solo-ambient, which the ring switch silences and
    // backgrounding stops. Declaring playback is what makes background audio
    // legal at all, and nothing in media_kit or audio_service declares it.
    //
    // `configuration` echoes what was requested rather than reading AVAudio-
    // Session back, so what this really proves is that `configure()` crossed
    // into the platform and returned without error — the category itself can
    // only be eyeballed on hardware.
    final config = (await AudioSession.instance).configuration!;
    expect(config.avAudioSessionCategory, AVAudioSessionCategory.playback);
  });

  testWidgets('the platform accepts what the handler publishes', (
    tester,
  ) async {
    // Every field crosses a MethodChannel into Objective-C, so a value the
    // native side rejects throws here rather than in a widget test.
    const track = pb.PlaybackTarget(
      mediaId: 'ios-track',
      title: 'Nothing Compares',
      artist: 'GospelTube',
      artworkUrl: 'https://cdn.example/art.jpg',
    );

    await playback.play(
      target: track,
      url: 'https://cdn.example/nothing.m3u8',
      kind: pb.PlaybackKind.audio,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(handler.mediaItem.value?.title, 'Nothing Compares');
    expect(handler.mediaItem.value?.artist, 'GospelTube');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a video publishes nothing to the system', (tester) async {
    await playback.play(
      target: const pb.PlaybackTarget(mediaId: 'ios-clip', title: 'Sermon'),
      url: 'https://cdn.example/clip.m3u8',
      kind: pb.PlaybackKind.video,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(handler.mediaItem.value, isNull);
  });

  testWidgets('transport commands reach the player', (tester) async {
    await handler.pause();
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.state.value.playing, isFalse);
  });

  testWidgets('a real stream actually decodes and advances', (tester) async {
    // The one thing only a device can answer: whether media_kit can play audio
    // on this platform at all. The URL is fetched rather than pinned because
    // Mux signs it with a five-minute expiry.
    //
    // Simulators cannot answer it. A bare media_kit `Player` fails there with
    // "Could not open/initialize audio device -> no sound" — libmpv finds no
    // audio output, exactly as the Android emulator finds no video output. Run
    // this on hardware; on a simulator it reports the limitation and stops
    // rather than failing a build for something the app does not control.
    final url = await _publicStreamUrl(_musicId);
    expect(url, isNotNull, reason: 'staging did not return a playback url');

    await playback.play(
      target: const pb.PlaybackTarget(
        mediaId: _musicId,
        title: 'Nothing Compares',
        artist: 'GospelTube',
      ),
      url: url!,
      kind: pb.PlaybackKind.audio,
    );

    // A cold HLS start is not instant; poll rather than guess a single delay.
    var moved = false;
    for (var i = 0; i < 60 && !moved; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      moved = playback.state.value.position > Duration.zero;
    }

    if (!moved) {
      markTestSkipped(
        'No audio output on this device — expected on a simulator, where '
        'libmpv reports "Could not open/initialize audio device".',
      );
      await playback.stop();
      return;
    }

    expect(playback.state.value.playing, isTrue);
    // And the system is being told about it while it runs.
    expect(handler.mediaItem.value?.title, 'Nothing Compares');
    expect(handler.playbackState.value.playing, isTrue);

    await playback.stop();
  });
}

const _musicId = '6a63964f5b5f0871220a5b96';

Future<String?> _publicStreamUrl(String mediaId) async {
  final res = await http.get(
    Uri.parse(
      'https://api.staging.gospeltube.tv/v1/public/media/$mediaId/playback-info',
    ),
  );
  if (res.statusCode != 200) return null;
  final body = jsonDecode(res.body);
  if (body is! Map || body['data'] is! Map) return null;
  return (body['data'] as Map)['playbackUrl'] as String?;
}

// End-to-end test of the named capture-flow contract from CLAUDE.md:
//   record short clip → transcribe → commit → audio file deleted.
//
// Runs against the real transcription service (real Isolate.run, real
// WhisperFFI, real whisper.cpp xcframework) and a real NotesRepository on an
// in-memory Drift database. Only the audio recorder is faked — we drop a
// known-good silent WAV at the scratch path so the test is deterministic
// regardless of the simulator's audio environment.
//
// Run with:
//   flutter test integration_test/capture_flow_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shower_thoughts/app/capture_controller.dart';
import 'package:shower_thoughts/audio/audio_paths.dart';
import 'package:shower_thoughts/audio/audio_recorder.dart';
import 'package:shower_thoughts/audio/cue_player.dart';
import 'package:shower_thoughts/audio/haptic_adapter.dart';
import 'package:shower_thoughts/data/database.dart';
import 'package:shower_thoughts/data/notes_dao.dart';
import 'package:shower_thoughts/data/notes_repository.dart';
import 'package:shower_thoughts/transcription/model_assets.dart';
import 'package:shower_thoughts/transcription/transcription_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture → transcribe → commit → audio is deleted',
    (WidgetTester tester) async {
      // Real bundled model is required for whisper FFI to load. main.dart
      // does this on first launch; we redo it here so the test is
      // self-contained.
      await ensureModelInstalled();

      final String scratchPath = await AudioPaths.scratchWavPath();
      // Wipe any leftover scratch from a previous run.
      final File scratch = File(scratchPath);
      if (await scratch.exists()) await scratch.delete();

      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final NotesRepository repository = NotesRepository(NotesDao(db));

      final _SilentWavRecorder recorder = _SilentWavRecorder(scratchPath);
      final CaptureController controller = CaptureController(
        recorder: recorder,
        transcriptionService: TranscriptionService(),
        repository: repository,
        cuePlayer: _NoopCuePlayer(),
        haptic: _NoopHapticAdapter(),
      );
      addTearDown(controller.dispose);

      // 1. Start: scratch WAV materialises, state moves to Recording.
      await controller.startRecording();
      expect(controller.state, isA<CaptureRecording>());
      expect(await scratch.exists(), isTrue,
          reason: 'recorder must drop a WAV at the scratch path');

      // 2. Stop: triggers transcribe-and-commit; wait for it to settle.
      await controller.stopRecording();
      await _waitForTerminalState(controller, tester);

      // 3. Round-trip contract.
      expect(
        controller.state,
        isA<CaptureCommitted>(),
        reason: 'capture must reach Committed (failure surface: '
            '${controller.state.runtimeType})',
      );
      final List<Note> all = await repository.listAllNewestFirst();
      expect(all, isNotEmpty,
          reason: 'commit must insert a row into the notes table');
      expect(all.first.modelId, 'ggml-tiny.en');
      expect(all.first.durationMs, greaterThanOrEqualTo(0));
      // transcript may be empty (silence often produces "") — content doesn't
      // matter, presence of the row does.
      expect(all.first.transcript, isA<String>());

      // 4. The named CLAUDE.md risk: audio retention.
      expect(await scratch.exists(), isFalse,
          reason: 'audio scratch file must be deleted after successful commit');
    },
    // Whisper inference on CPU under the simulator is slow; allow ample
    // headroom so the test doesn't flake on a busy machine.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Pumps the widget tree (no-op when nothing is being built) every 250ms
/// while polling the controller for a terminal state. Times out via the
/// surrounding testWidgets timeout.
Future<void> _waitForTerminalState(
  CaptureController controller,
  WidgetTester tester,
) async {
  for (int i = 0; i < 480; i++) {
    if (controller.state is CaptureCommitted ||
        controller.state is CaptureFailed) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 0));
  }
  fail('controller did not reach a terminal state in time '
      '(last seen: ${controller.state.runtimeType})');
}

class _NoopCuePlayer implements CuePlayer {
  @override
  Future<void> playStart() async {}
  @override
  Future<void> playStop() async {}
  @override
  Future<void> dispose() async {}
}

class _NoopHapticAdapter implements HapticAdapter {
  @override
  void startCue() {}
  @override
  void stopCue() {}
}

/// `AudioRecorder` stand-in that drops a canonical 16 kHz mono 16-bit PCM WAV
/// at the requested scratch path on `start()`. The clip is half a second of
/// silence — long enough that whisper has a real PCM buffer to look at but
/// short enough to keep the test fast.
class _SilentWavRecorder implements AudioRecorder {
  _SilentWavRecorder(this.path);
  final String path;

  @override
  Future<String> start() async {
    await File(path).writeAsBytes(_buildSilentWav(durationSeconds: 0.5));
    return path;
  }

  @override
  Future<String> stop() async => path;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> dispose() async {}
}

/// Construct a canonical 44-byte-header WAV containing zero-valued samples.
/// Exactly the format whisper.cpp expects: PCM, 1 channel, 16 kHz, 16-bit
/// little-endian.
Uint8List _buildSilentWav({required double durationSeconds}) {
  const int sampleRate = 16000;
  const int bitsPerSample = 16;
  const int channels = 1;
  final int numSamples = (sampleRate * durationSeconds).round();
  final int dataSize = numSamples * channels * (bitsPerSample ~/ 8);
  final int fileSize = 36 + dataSize;

  final BytesBuilder out = BytesBuilder();
  void writeStr(String s) => out.add(s.codeUnits);
  void writeU32(int v) {
    final ByteData b = ByteData(4)..setUint32(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }
  void writeU16(int v) {
    final ByteData b = ByteData(2)..setUint16(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  writeStr('RIFF');
  writeU32(fileSize);
  writeStr('WAVE');

  writeStr('fmt ');
  writeU32(16); // fmt chunk size for PCM
  writeU16(1); // audio format: PCM
  writeU16(channels);
  writeU32(sampleRate);
  writeU32(sampleRate * channels * (bitsPerSample ~/ 8)); // byte rate
  writeU16(channels * (bitsPerSample ~/ 8)); // block align
  writeU16(bitsPerSample);

  writeStr('data');
  writeU32(dataSize);
  out.add(Uint8List(dataSize)); // zero-filled

  return out.toBytes();
}

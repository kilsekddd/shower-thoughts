// Tests for the transcription layer.
//
// We have two layers to cover:
//   1. `WhisperFFI.transcribe` — pure FFI roundtrip against a short fixture WAV.
//   2. `TranscriptionService.transcribe` — same roundtrip, plus a check that
//      the call really runs on a background isolate (the UI thread keeps
//      ticking during inference).
//
// Both depend on the native whisper library being loadable from `flutter test`.
// On a developer's macOS host that requires:
//   - the spike dylib at `.spikes/libspike_whisper.dylib`
//   - the model file at `assets/models/ggml-tiny.en.bin`
//   - the JFK fixture WAV at `test/fixtures/jfk.wav`
//
// All three are gated explicitly below — if any is missing the test prints a
// clear `SKIPPING: ...` line and exits, rather than silently passing. On CI /
// iOS device runs the same `WhisperFFI.fromProcess()` path is used by
// `TranscriptionService`, and the gating still applies cleanly.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/transcription/transcription_service.dart';
import 'package:shower_thoughts/transcription/whisper_ffi.dart';

void main() {
  // Resolve fixture paths relative to the package root. `flutter test`
  // chdirs into the package, so these are stable.
  final repoRoot = Directory.current.path;
  final spikeDylib = '$repoRoot/.spikes/libspike_whisper.dylib';
  final modelPath = '$repoRoot/assets/models/ggml-tiny.en.bin';
  final fixtureWav = '$repoRoot/test/fixtures/jfk.wav';

  final hasDylib = File(spikeDylib).existsSync();
  final hasModel = File(modelPath).existsSync();
  final hasFixture = File(fixtureWav).existsSync();

  // Run-host gate: we only attempt the native call on macOS where the spike
  // dylib was built. On Linux/Windows CI hosts we skip cleanly.
  final canRunNative = Platform.isMacOS && hasDylib && hasModel && hasFixture;
  final gateMessage = canRunNative
      ? null
      : 'native whisper not available '
            '(macOS=${Platform.isMacOS}, dylib=$hasDylib, model=$hasModel, fixture=$hasFixture)';

  group('WhisperFFI', () {
    test('transcribes the JFK fixture to non-empty text', () {
      if (!canRunNative) {
        // Use `markTestSkipped` so the runner reports a skip, not a pass.
        markTestSkipped('SKIPPING WhisperFFI roundtrip: $gateMessage');
        return;
      }
      final ffi = WhisperFFI.tryOpenDylib(spikeDylib);
      expect(ffi, isNotNull, reason: 'dylib exists but failed to open');
      final text = ffi!.transcribe(fixtureWav, modelPath);
      expect(text.trim(), isNotEmpty);
      // The JFK clip says "And so my fellow Americans..." — assert at least
      // one recognisable word survives so a regression in the FFI buffer
      // handling is loud.
      expect(text.toLowerCase(), contains('americans'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('TranscriptionService', () {
    test('runs whisper on a background isolate without blocking', () async {
      if (!canRunNative) {
        markTestSkipped('SKIPPING isolate test: $gateMessage');
        return;
      }

      // Inject a model-path resolver that points at the test asset rather
      // than the documents dir (which path_provider can't satisfy in a
      // host test without a plugin mock).
      final service = TranscriptionService(
        modelPathResolver: () async => modelPath,
        whisperFactory: () {
          final ffi = WhisperFFI.tryOpenDylib(spikeDylib);
          if (ffi == null) {
            throw StateError('test fixture dylib missing inside isolate');
          }
          return ffi;
        },
      );

      // Tick a periodic timer while inference runs; if the service blocked
      // the test isolate, the timer would not fire.
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        ticks++;
      });

      try {
        final text = await service.transcribe(fixtureWav);
        expect(text.trim(), isNotEmpty);
        expect(
          ticks,
          greaterThan(0),
          reason:
              'main isolate timer never fired during transcription — '
              'inference is not actually running on a background isolate',
        );
      } finally {
        timer.cancel();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

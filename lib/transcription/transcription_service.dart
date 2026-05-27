// Orchestrates a single push-to-talk round-trip's transcription step:
// "give me a WAV path, return the transcript text".
//
// Whisper inference is CPU-bound and takes seconds; per CLAUDE.md it must
// never block the UI isolate. This service runs `WhisperFFI.transcribe` inside
// `Isolate.run`, so the calling isolate just awaits a Future.

import 'dart:async';
import 'dart:isolate';

import 'model_assets.dart';
import 'whisper_ffi.dart';

/// How a [TranscriptionService] resolves the path to the whisper model.
typedef ModelPathResolver = Future<String> Function();

/// How a [TranscriptionService] obtains a [WhisperFFI] instance inside the
/// background isolate. Exposed so tests can substitute a dylib-backed instance
/// without needing the iOS host process symbol.
typedef WhisperFactory = WhisperFFI Function();

WhisperFFI _defaultWhisperFactory() => WhisperFFI.fromProcess();

/// High-level transcription entry point used by `CaptureController`.
class TranscriptionService {
  TranscriptionService({
    ModelPathResolver? modelPathResolver,
    WhisperFactory? whisperFactory,
  }) : _modelPathResolver = modelPathResolver ?? ensureModelInstalled,
       _whisperFactory = whisperFactory ?? _defaultWhisperFactory;

  final ModelPathResolver _modelPathResolver;
  final WhisperFactory _whisperFactory;

  /// Transcribe the WAV file at [audioPath] on a background isolate and
  /// return the resulting text. Resolves the model path lazily so callers
  /// never have to thread it through manually.
  ///
  /// Throws [WhisperException] (re-raised across the isolate boundary) if the
  /// native side reports an error.
  Future<String> transcribe(String audioPath) async {
    final modelPath = await _modelPathResolver();
    final factory = _whisperFactory;
    // `Isolate.run` runs the callback on a fresh isolate and tears it down on
    // completion. The callback must be a top-level or static closure — but
    // capturing top-level/static function references (like `factory` above)
    // is fine because they are sendable.
    return Isolate.run<String>(() {
      final ffi = factory();
      return ffi.transcribe(audioPath, modelPath);
    });
  }
}

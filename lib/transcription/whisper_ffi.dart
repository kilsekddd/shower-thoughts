// Thin Dart-FFI wrapper around the C-ABI exposed by ios/whisper/wrapper.cpp.
//
// On iOS the wrapper compiles into the Runner binary via the
// ShowerThoughtsWhisper pod, so the symbol `spike_transcribe_wav` is looked up
// against the running process (`DynamicLibrary.process()`).
//
// During host-machine `flutter test` runs the symbol is not present, so we
// also support `DynamicLibrary.open(path)` for a hand-built dylib (the
// `.spikes/libspike_whisper.dylib` artifact is the canonical fixture for that).
//
// This file mirrors the pattern proven in `.spikes/spike.dart`: allocate the
// output buffer, call into the native lib, read the bytes out, free everything.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'whisper_bindings.dart';

/// Default size of the transcript output buffer (in bytes). At ~150 wpm
/// English, 64 KiB is roughly 80 minutes of dense speech — well above the
/// 10-minute recording cap enforced by `CaptureController`. The wrapper
/// returns -8 if the transcript would not fit; `transcribe` retries once
/// with [_kRetryOutputBufferSize] in that case as a defense-in-depth measure.
const int _kDefaultOutputBufferSize = 64 * 1024;

/// One-shot grown buffer used after the wrapper signals -8. Large enough that
/// a second overflow indicates a real problem (e.g. cap bypassed) worth
/// surfacing as an error rather than retrying again.
const int _kRetryOutputBufferSize = 256 * 1024;

/// Negative return code from the native wrapper meaning "transcript did not
/// fit in out_buf". See ios/whisper/wrapper.h.
const int _kRcTranscriptOverflow = -8;

/// Thin synchronous FFI surface around whisper.cpp. Do NOT call `transcribe`
/// from the UI isolate directly — go through `TranscriptionService` so the
/// call runs on a background isolate.
class WhisperFFI {
  WhisperFFI._(this._bindings);

  final WhisperBindings _bindings;

  /// Look the symbol up in the host process. This is the production path on
  /// iOS, where `wrapper.cpp` is statically linked into Runner.
  factory WhisperFFI.fromProcess() {
    return WhisperFFI._(WhisperBindings(DynamicLibrary.process()));
  }

  /// Open a standalone dylib (the spike build, or a future host-test fixture).
  /// Returns `null` if the file does not exist, so callers can decide whether
  /// to fall back, skip a test, or throw.
  static WhisperFFI? tryOpenDylib(String dylibPath) {
    if (!File(dylibPath).existsSync()) return null;
    return WhisperFFI._(WhisperBindings(DynamicLibrary.open(dylibPath)));
  }

  /// Synchronously transcribe a 16 kHz mono 16-bit PCM WAV file. Blocks the
  /// calling isolate for the duration of inference, so always call this from
  /// inside `Isolate.run`.
  ///
  /// Throws [WhisperException] on any non-zero return code from the wrapper.
  /// If the wrapper signals overflow (-8), retries once at
  /// [_kRetryOutputBufferSize] before giving up.
  String transcribe(
    String audioPath,
    String modelPath, {
    int bufferSize = _kDefaultOutputBufferSize,
  }) {
    final result = _transcribeOnce(audioPath, modelPath, bufferSize);
    if (result.rc == _kRcTranscriptOverflow &&
        bufferSize < _kRetryOutputBufferSize) {
      return _transcribeOrThrow(
        audioPath,
        modelPath,
        _kRetryOutputBufferSize,
      );
    }
    if (result.rc < 0) {
      throw WhisperException(result.rc, result.text);
    }
    return result.text;
  }

  String _transcribeOrThrow(String audioPath, String modelPath, int bufferSize) {
    final result = _transcribeOnce(audioPath, modelPath, bufferSize);
    if (result.rc < 0) {
      throw WhisperException(result.rc, result.text);
    }
    return result.text;
  }

  _TranscribeResult _transcribeOnce(
    String audioPath,
    String modelPath,
    int bufferSize,
  ) {
    final modelPtr = modelPath.toNativeUtf8();
    final audioPtr = audioPath.toNativeUtf8();
    final outBuf = calloc<Uint8>(bufferSize);
    try {
      final rc = _bindings.spike_transcribe_wav(
        modelPtr.cast<Char>(),
        audioPtr.cast<Char>(),
        outBuf.cast<Char>(),
        bufferSize,
      );
      // On rc == -4 / -8 the wrapper writes a human-readable reason / partial
      // transcript into out_buf; for other negative codes the buffer is
      // undefined, but reading it is safe because calloc zero-initialised it.
      final text = outBuf.cast<Utf8>().toDartString();
      return _TranscribeResult(rc, text);
    } finally {
      calloc.free(modelPtr);
      calloc.free(audioPtr);
      calloc.free(outBuf);
    }
  }
}

class _TranscribeResult {
  _TranscribeResult(this.rc, this.text);
  final int rc;
  final String text;
}

/// Thrown when `spike_transcribe_wav` returns a negative error code.
class WhisperException implements Exception {
  WhisperException(this.code, this.partialBuffer);

  /// Negative return code from the native wrapper. See `ios/whisper/wrapper.h`
  /// for the meaning of each code.
  final int code;

  /// Whatever the wrapper wrote into the output buffer before failing. May be
  /// the empty string for codes that don't populate the buffer.
  final String partialBuffer;

  @override
  String toString() =>
      'WhisperException(code=$code, partial="$partialBuffer")';
}

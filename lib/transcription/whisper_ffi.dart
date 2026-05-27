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

/// Default size of the transcript output buffer (in bytes). Whisper segments
/// for a single push-to-talk clip will never come close to this; the spike
/// used 8 KiB and we keep the same headroom.
const int _kDefaultOutputBufferSize = 16 * 1024;

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
  String transcribe(
    String audioPath,
    String modelPath, {
    int bufferSize = _kDefaultOutputBufferSize,
  }) {
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
      if (rc < 0) {
        // On rc == -4 the wrapper writes a human-readable reason into out_buf;
        // for other negative codes the buffer is undefined, but reading it is
        // safe because calloc zero-initialised it.
        final partial = outBuf.cast<Utf8>().toDartString();
        throw WhisperException(rc, partial);
      }
      return outBuf.cast<Utf8>().toDartString();
    } finally {
      calloc.free(modelPtr);
      calloc.free(audioPtr);
      calloc.free(outBuf);
    }
  }
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

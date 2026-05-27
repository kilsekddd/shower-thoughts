import 'dart:io';

import 'package:record/record.dart' as record_pkg;

import 'audio_paths.dart';

/// Captures 16 kHz mono 16-bit PCM WAV — the exact format whisper.cpp expects.
class AudioRecorder {
  AudioRecorder() : _impl = record_pkg.AudioRecorder();

  final record_pkg.AudioRecorder _impl;

  Future<String> start() async {
    if (!await _impl.hasPermission()) {
      throw const MicrophonePermissionDeniedException();
    }
    final String path = await AudioPaths.scratchWavPath();
    await _impl.start(
      const record_pkg.RecordConfig(
        encoder: record_pkg.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  Future<String> stop() async {
    final String? returned = await _impl.stop();
    final String path = returned ?? await AudioPaths.scratchWavPath();
    if (!File(path).existsSync()) {
      throw StateError('recorder stopped but no file at $path');
    }
    return path;
  }

  Future<bool> isRecording() => _impl.isRecording();

  Future<void> dispose() => _impl.dispose();
}

class MicrophonePermissionDeniedException implements Exception {
  const MicrophonePermissionDeniedException();
  @override
  String toString() => 'MicrophonePermissionDeniedException';
}

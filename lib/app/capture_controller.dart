// ignore_for_file: prefer_initializing_formals
//
// Constructor takes named public-shaped params (`recorder:`, `repository:`,
// etc.) and assigns to underscored private fields. The lint's suggested
// `this._recorder` form would force callers to write `_recorder:` at every
// call site, which leaks the implementation detail. Public arg, private field
// is the cleaner shape for this controller.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_recorder.dart';
import '../data/database.dart';
import '../data/notes_repository.dart';
import '../transcription/model_assets.dart';
import '../transcription/transcription_service.dart';

/// Push-to-talk round-trip state machine: idle → recording → transcribing →
/// committed | failed. `failed` carries the still-on-disk audio path so the
/// user can retry without re-recording.
sealed class CaptureState {
  const CaptureState();
}

final class CaptureIdle extends CaptureState {
  const CaptureIdle();
}

final class CaptureRecording extends CaptureState {
  const CaptureRecording({required this.startedAt});
  final DateTime startedAt;
}

final class CaptureTranscribing extends CaptureState {
  const CaptureTranscribing({
    required this.audioPath,
    required this.durationMs,
  });
  final String audioPath;
  final int durationMs;
}

final class CaptureCommitted extends CaptureState {
  const CaptureCommitted({required this.noteId});
  final int noteId;
}

final class CaptureFailed extends CaptureState {
  const CaptureFailed({
    required this.error,
    this.audioPath,
    this.durationMs,
  });
  final Object error;

  /// Non-null when the recording succeeded but a later step (transcription or
  /// commit) failed. The audio is still on disk and a retry is meaningful.
  final String? audioPath;
  final int? durationMs;

  bool get canRetry => audioPath != null && durationMs != null;
}

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController({
    required AudioRecorder recorder,
    required TranscriptionService transcriptionService,
    required NotesRepository repository,
    String modelId = defaultModelId,
    DateTime Function() now = DateTime.now,
  })  : _recorder = recorder,
        _transcription = transcriptionService,
        _repository = repository,
        _modelId = modelId,
        _now = now,
        super(const CaptureIdle());

  final AudioRecorder _recorder;
  final TranscriptionService _transcription;
  final NotesRepository _repository;
  final String _modelId;
  final DateTime Function() _now;

  /// Set by `stopRecording` if it fires before `startRecording` has resolved
  /// — typically when iOS pops the mic permission modal during the gesture
  /// and Flutter fires `onTapCancel` before the user has actually released.
  /// `startRecording` checks this after its await and bails out instead of
  /// stranding the user in a `CaptureRecording` state they can't exit.
  bool _abortInFlightStart = false;

  Future<void> startRecording() async {
    if (state is! CaptureIdle && state is! CaptureCommitted && state is! CaptureFailed) {
      return;
    }
    _abortInFlightStart = false;
    try {
      await _recorder.start();
    } catch (e) {
      state = CaptureFailed(error: e);
      return;
    }
    if (_abortInFlightStart) {
      // User released (or the gesture was cancelled) before start resolved.
      try {
        await _recorder.stop();
      } catch (_) {
        // Best-effort: swallow stop errors here — we never entered a state
        // the user could observe, so there's nothing useful to report.
      }
      state = const CaptureIdle();
      return;
    }
    state = CaptureRecording(startedAt: _now());
  }

  Future<void> stopRecording() async {
    final current = state;
    if (current is! CaptureRecording) {
      // A stop arrived before start resolved — flag it for startRecording's
      // post-await check rather than dropping it on the floor.
      _abortInFlightStart = true;
      return;
    }
    final String audioPath;
    try {
      audioPath = await _recorder.stop();
    } catch (e) {
      state = CaptureFailed(error: e);
      return;
    }
    final int durationMs =
        _now().difference(current.startedAt).inMilliseconds.clamp(0, 1 << 31);
    state = CaptureTranscribing(audioPath: audioPath, durationMs: durationMs);
    await _runTranscribeAndCommit(audioPath: audioPath, durationMs: durationMs);
  }

  /// Re-run transcription against the audio left on disk by a previous
  /// failure. Per CLAUDE.md the audio is kept on failure precisely so the
  /// user can retry without re-recording.
  Future<void> retry() async {
    final current = state;
    if (current is! CaptureFailed || !current.canRetry) return;
    final String audioPath = current.audioPath!;
    final int durationMs = current.durationMs!;
    state = CaptureTranscribing(audioPath: audioPath, durationMs: durationMs);
    await _runTranscribeAndCommit(audioPath: audioPath, durationMs: durationMs);
  }

  /// Drop a terminal state (committed or failed) back to idle so the UI
  /// returns to a recordable state. No I/O.
  void dismiss() {
    if (state is CaptureCommitted || state is CaptureFailed) {
      state = const CaptureIdle();
    }
  }

  Future<void> _runTranscribeAndCommit({
    required String audioPath,
    required int durationMs,
  }) async {
    final String transcript;
    try {
      transcript = await _transcription.transcribe(audioPath);
    } catch (e) {
      // Keep the audio: a retry is meaningful.
      state = CaptureFailed(
        error: e,
        audioPath: audioPath,
        durationMs: durationMs,
      );
      return;
    }
    try {
      final int noteId = await _repository.commitTranscript(
        NoteDraft(
          createdAt: _now(),
          durationMs: durationMs,
          transcript: _collapseWhitespace(transcript),
          modelId: _modelId,
        ),
        audioPath,
      );
      state = CaptureCommitted(noteId: noteId);
    } catch (e) {
      // commitTranscript deletes the audio in `finally` regardless of insert
      // success/failure, so retry is no longer meaningful here.
      state = CaptureFailed(error: e);
    }
  }

  String _collapseWhitespace(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');
}

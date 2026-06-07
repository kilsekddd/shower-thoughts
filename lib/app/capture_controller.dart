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
import '../audio/cue_player.dart';
import '../audio/haptic_adapter.dart';
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
    this.autoStoppedByCap = false,
  });
  final String audioPath;
  final int durationMs;

  /// True when the recording stopped because the max-duration cap fired, not
  /// because the user released the button.
  final bool autoStoppedByCap;
}

final class CaptureCommitted extends CaptureState {
  const CaptureCommitted({
    required this.noteId,
    this.autoStoppedByCap = false,
  });
  final int noteId;

  /// True when the underlying recording was stopped by the cap. UI uses this
  /// to tell the user their button-hold was cut short.
  final bool autoStoppedByCap;
}

final class CaptureFailed extends CaptureState {
  const CaptureFailed({
    required this.error,
    this.audioPath,
    this.durationMs,
    this.autoStoppedByCap = false,
  });
  final Object error;

  /// Non-null when the recording succeeded but a later step (transcription or
  /// commit) failed. The audio is still on disk and a retry is meaningful.
  final String? audioPath;
  final int? durationMs;

  /// Carried through so a cap-triggered recording that fails transcription
  /// still tells the user "your hold was cut short" on a successful retry.
  final bool autoStoppedByCap;

  bool get canRetry => audioPath != null && durationMs != null;
}

/// Hard cap on a single push-to-talk recording. Long enough that a normal
/// user-paced thought never hits it, short enough to keep the WAV (and the
/// in-memory PCM whisper.cpp loads for inference) bounded if the button gets
/// stuck or the user walks away mid-press. See M14 in TASKS.md.
const Duration kDefaultMaxRecordingDuration = Duration(minutes: 10);

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController({
    required AudioRecorder recorder,
    required TranscriptionService transcriptionService,
    required NotesRepository repository,
    required CuePlayer cuePlayer,
    required HapticAdapter haptic,
    String modelId = defaultModelId,
    DateTime Function() now = DateTime.now,
    Duration maxDuration = kDefaultMaxRecordingDuration,
  })  : _recorder = recorder,
        _transcription = transcriptionService,
        _repository = repository,
        _cuePlayer = cuePlayer,
        _haptic = haptic,
        _modelId = modelId,
        _now = now,
        _maxDuration = maxDuration,
        super(const CaptureIdle());

  final AudioRecorder _recorder;
  final TranscriptionService _transcription;
  final NotesRepository _repository;
  final CuePlayer _cuePlayer;
  final HapticAdapter _haptic;
  final String _modelId;
  final DateTime Function() _now;
  final Duration _maxDuration;

  /// Set by `stopRecording` if it fires before `startRecording` has resolved
  /// — typically when iOS pops the mic permission modal during the gesture
  /// and Flutter fires `onTapCancel` before the user has actually released.
  /// `startRecording` checks this after its await and bails out instead of
  /// stranding the user in a `CaptureRecording` state they can't exit.
  bool _abortInFlightStart = false;

  /// Fires `_maxDuration` after the recording transitions to
  /// `CaptureRecording`. Cancelled on stop / abort / dispose.
  Timer? _capTimer;

  /// Set true when `_capTimer` was the thing that stopped the recording, so
  /// downstream states can tell the user their hold was cut short. Reset at
  /// the start of every new recording.
  bool _stoppedByCap = false;

  Future<void> startRecording() async {
    if (state is! CaptureIdle && state is! CaptureCommitted && state is! CaptureFailed) {
      return;
    }
    _abortInFlightStart = false;
    _stoppedByCap = false;
    _haptic.startCue();
    unawaited(_cuePlayer.playStart());
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
    _capTimer = Timer(_maxDuration, _onCapReached);
  }

  void _onCapReached() {
    // Re-check state at fire time: if the user already released, the timer
    // was cancelled but a queued tick could still run. Either way, only act
    // when we're still in CaptureRecording.
    if (state is! CaptureRecording) return;
    _stoppedByCap = true;
    // Fire-and-forget: the state-machine progression below is what listeners
    // observe; nobody waits on this future.
    unawaited(stopRecording());
  }

  Future<void> stopRecording() async {
    _capTimer?.cancel();
    _capTimer = null;
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
    _haptic.stopCue();
    unawaited(_cuePlayer.playStop());
    final int durationMs =
        _now().difference(current.startedAt).inMilliseconds.clamp(0, 1 << 31);
    final bool autoStopped = _stoppedByCap;
    state = CaptureTranscribing(
      audioPath: audioPath,
      durationMs: durationMs,
      autoStoppedByCap: autoStopped,
    );
    await _runTranscribeAndCommit(
      audioPath: audioPath,
      durationMs: durationMs,
      autoStoppedByCap: autoStopped,
    );
  }

  /// Re-run transcription against the audio left on disk by a previous
  /// failure. Per CLAUDE.md the audio is kept on failure precisely so the
  /// user can retry without re-recording.
  Future<void> retry() async {
    final current = state;
    if (current is! CaptureFailed || !current.canRetry) return;
    final String audioPath = current.audioPath!;
    final int durationMs = current.durationMs!;
    final bool autoStopped = current.autoStoppedByCap;
    state = CaptureTranscribing(
      audioPath: audioPath,
      durationMs: durationMs,
      autoStoppedByCap: autoStopped,
    );
    await _runTranscribeAndCommit(
      audioPath: audioPath,
      durationMs: durationMs,
      autoStoppedByCap: autoStopped,
    );
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
    bool autoStoppedByCap = false,
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
        autoStoppedByCap: autoStoppedByCap,
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
      state = CaptureCommitted(
        noteId: noteId,
        autoStoppedByCap: autoStoppedByCap,
      );
    } catch (e) {
      // commitTranscript deletes the audio in `finally` regardless of insert
      // success/failure, so retry is no longer meaningful here.
      state = CaptureFailed(error: e);
    }
  }

  String _collapseWhitespace(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void dispose() {
    _capTimer?.cancel();
    _capTimer = null;
    super.dispose();
  }
}

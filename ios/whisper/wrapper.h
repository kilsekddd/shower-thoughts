// C-ABI wrapper header consumed by both the iOS build (compiled alongside
// wrapper.cpp) and by ffigen (to generate lib/transcription/whisper_bindings.dart).
//
// Keep this surface stable: any signature change requires re-running ffigen.
#ifndef SHOWER_THOUGHTS_WHISPER_WRAPPER_H
#define SHOWER_THOUGHTS_WHISPER_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

// Transcribe a 16kHz mono 16-bit PCM WAV file using a whisper.cpp ggml model.
//
// model_path : absolute filesystem path to a ggml-*.bin model file
// wav_path   : absolute filesystem path to the input WAV file
// out_buf    : caller-owned buffer that receives the null-terminated transcript
// buf_size   : size of out_buf in bytes
//
// Returns the number of bytes written to out_buf (excluding the null terminator)
// on success, or a negative error code on failure:
//   -1  could not open wav file
//   -2  short read on wav header
//   -3  not a RIFF/WAVE file
//   -4  wav not 16kHz mono 16-bit PCM (out_buf receives a human-readable reason)
//   -5  whisper_init_from_file_with_params failed
//   -6  whisper_full failed
//   -7  malformed WAV chunks (no fmt or data chunk)
//   -8  transcript would not fit in out_buf (partial written for diagnostics —
//       callers should retry with a larger buffer)
int spike_transcribe_wav(const char* model_path,
                         const char* wav_path,
                         char* out_buf,
                         int buf_size);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // SHOWER_THOUGHTS_WHISPER_WRAPPER_H

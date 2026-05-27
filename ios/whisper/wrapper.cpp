// C-ABI wrapper around whisper.cpp for Dart FFI.
// Single entry point: transcribe a 16kHz mono PCM WAV file into a char buffer.
//
// This is the production version of the spike at /.spikes/wrapper.cpp.
// It is compiled into the Runner app via the ShowerThoughtsWhisper podspec
// and linked against the whisper.xcframework next to it.
#include <whisper/whisper.h>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <vector>
#include <string>

extern "C" {

// Returns number of bytes written to out_buf (excluding null terminator), or a negative error code:
//   -1  could not open wav file
//   -2  short read on wav header
//   -3  not a RIFF/WAVE file
//   -4  wav not 16kHz mono 16-bit PCM
//   -5  whisper_init_from_file_with_params failed
//   -6  whisper_full failed
int spike_transcribe_wav(const char* model_path, const char* wav_path, char* out_buf, int buf_size) {
    // --- WAV load: assume canonical 16kHz mono 16-bit PCM, 44-byte header.
    FILE* f = std::fopen(wav_path, "rb");
    if (!f) return -1;
    uint8_t hdr[44];
    if (std::fread(hdr, 1, 44, f) != 44) { std::fclose(f); return -2; }
    if (std::memcmp(hdr, "RIFF", 4) != 0 || std::memcmp(hdr + 8, "WAVE", 4) != 0) {
        std::fclose(f); return -3;
    }
    uint16_t channels = *(uint16_t*)(hdr + 22);
    uint32_t sample_rate = *(uint32_t*)(hdr + 24);
    uint16_t bits = *(uint16_t*)(hdr + 34);
    if (channels != 1 || sample_rate != 16000 || bits != 16) {
        std::fclose(f);
        std::snprintf(out_buf, buf_size, "wav format mismatch: ch=%u sr=%u bits=%u (need 1/16000/16)", channels, sample_rate, bits);
        return -4;
    }
    std::vector<int16_t> pcm16;
    int16_t sample;
    while (std::fread(&sample, 2, 1, f) == 1) pcm16.push_back(sample);
    std::fclose(f);

    std::vector<float> pcm32(pcm16.size());
    for (size_t i = 0; i < pcm16.size(); i++) pcm32[i] = pcm16[i] / 32768.0f;

    // --- whisper init
    whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;
    whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (!ctx) return -5;

    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_special = false;
    wparams.print_realtime = false;
    wparams.print_timestamps = false;
    wparams.translate = false;
    wparams.language = "en";
    wparams.n_threads = 4;

    if (whisper_full(ctx, wparams, pcm32.data(), (int)pcm32.size()) != 0) {
        whisper_free(ctx);
        return -6;
    }

    std::string transcript;
    int n = whisper_full_n_segments(ctx);
    for (int i = 0; i < n; i++) {
        const char* seg = whisper_full_get_segment_text(ctx, i);
        transcript += seg;
    }
    whisper_free(ctx);

    int len = (int)transcript.size();
    if (len >= buf_size) len = buf_size - 1;
    std::memcpy(out_buf, transcript.data(), len);
    out_buf[len] = '\0';
    return len;
}

} // extern "C"

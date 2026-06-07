// C-ABI wrapper around whisper.cpp for Dart FFI.
// Single entry point: transcribe a 16kHz mono PCM WAV file into a char buffer.
//
// This is the production version of the spike at /.spikes/wrapper.cpp. Unlike
// the spike (which only had to load whisper.cpp's canonical sample WAVs), this
// version walks WAV chunks by tag — Apple's Core Audio writer inserts JUNK /
// FLLR padding chunks before `fmt ` to 4096-byte-align the audio data, so a
// hardcoded 44-byte header read would see zeros where channels/sr/bits live.
#include <whisper/whisper.h>
#include <TargetConditionals.h>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <vector>
#include <string>

namespace {

// One subchunk header inside a WAVE RIFF: 4-byte ASCII tag + 4-byte little-
// endian payload size. Payload follows immediately; chunks are padded to
// even byte boundaries (an odd payload size means one trailing pad byte).
struct ChunkHeader {
    char tag[4];
    uint32_t size;
};

// Walks the WAV file from the current position, finding the `fmt ` and `data`
// chunks regardless of where they fall in the chunk sequence. Returns true on
// success; populates `channels`, `sample_rate`, `bits_per_sample`, and the
// raw PCM byte range. `pcm_offset` is the absolute file offset of the data
// payload (caller must fseek back).
bool parse_wav_chunks(
    FILE* f,
    uint16_t& channels,
    uint32_t& sample_rate,
    uint16_t& bits_per_sample,
    long& pcm_offset,
    uint32_t& pcm_size
) {
    bool found_fmt = false;
    bool found_data = false;
    ChunkHeader hdr;
    while (std::fread(&hdr, sizeof(hdr), 1, f) == 1) {
        if (std::memcmp(hdr.tag, "fmt ", 4) == 0) {
            // Standard PCM fmt subchunk is 16 bytes; some writers use 18 or
            // 40. Read the first 16 and skip the rest.
            uint8_t fmt[16];
            if (std::fread(fmt, 1, 16, f) != 16) return false;
            channels        = *(uint16_t*)(fmt + 2);
            sample_rate     = *(uint32_t*)(fmt + 4);
            bits_per_sample = *(uint16_t*)(fmt + 14);
            if (hdr.size > 16) {
                if (std::fseek(f, hdr.size - 16, SEEK_CUR) != 0) return false;
            }
            if (hdr.size & 1) std::fseek(f, 1, SEEK_CUR);
            found_fmt = true;
        } else if (std::memcmp(hdr.tag, "data", 4) == 0) {
            pcm_offset = std::ftell(f);
            pcm_size = hdr.size;
            // Don't read the payload here — caller seeks back to pcm_offset.
            if (std::fseek(f, hdr.size, SEEK_CUR) != 0) return false;
            if (hdr.size & 1) std::fseek(f, 1, SEEK_CUR);
            found_data = true;
        } else {
            // JUNK, FLLR, LIST, etc. — skip the payload.
            if (std::fseek(f, hdr.size, SEEK_CUR) != 0) return false;
            if (hdr.size & 1) std::fseek(f, 1, SEEK_CUR);
        }
        if (found_fmt && found_data) return true;
    }
    return found_fmt && found_data;
}

} // namespace

extern "C" {

// Returns number of bytes written to out_buf (excluding null terminator), or a
// negative error code:
//   -1  could not open wav file
//   -2  short read on RIFF/WAVE preamble
//   -3  not a RIFF/WAVE file
//   -4  wav not 16kHz mono 16-bit PCM
//   -5  whisper_init_from_file_with_params failed
//   -6  whisper_full failed
//   -7  malformed WAV chunks (no fmt or data chunk)
//   -8  transcript would not fit in out_buf (partial written for diagnostics)
int spike_transcribe_wav(const char* model_path, const char* wav_path, char* out_buf, int buf_size) {
    FILE* f = std::fopen(wav_path, "rb");
    if (!f) return -1;

    // RIFF preamble: "RIFF" <riff_size:4> "WAVE"
    uint8_t preamble[12];
    if (std::fread(preamble, 1, 12, f) != 12) { std::fclose(f); return -2; }
    if (std::memcmp(preamble, "RIFF", 4) != 0 ||
        std::memcmp(preamble + 8, "WAVE", 4) != 0) {
        std::fclose(f); return -3;
    }

    uint16_t channels = 0;
    uint32_t sample_rate = 0;
    uint16_t bits = 0;
    long pcm_offset = 0;
    uint32_t pcm_size = 0;
    if (!parse_wav_chunks(f, channels, sample_rate, bits, pcm_offset, pcm_size)) {
        std::fclose(f);
        std::snprintf(out_buf, buf_size, "malformed wav: missing fmt or data chunk");
        return -7;
    }

    if (channels != 1 || sample_rate != 16000 || bits != 16) {
        std::fclose(f);
        std::snprintf(out_buf, buf_size,
                      "wav format mismatch: ch=%u sr=%u bits=%u (need 1/16000/16)",
                      channels, sample_rate, bits);
        return -4;
    }

    // Read PCM payload.
    if (std::fseek(f, pcm_offset, SEEK_SET) != 0) { std::fclose(f); return -7; }
    const size_t n_samples = pcm_size / 2;
    std::vector<int16_t> pcm16(n_samples);
    if (std::fread(pcm16.data(), 2, n_samples, f) != n_samples) {
        std::fclose(f); return -2;
    }
    std::fclose(f);

    std::vector<float> pcm32(n_samples);
    for (size_t i = 0; i < n_samples; i++) pcm32[i] = pcm16[i] / 32768.0f;

    whisper_context_params cparams = whisper_context_default_params();
    // The iOS Simulator's MTLSimDevice can't allocate the model's tensor
    // buffer via XPC shared memory (_xpc_api_misuse / _xpc_shmem_create), so
    // GPU init crashes. Real device Metal works fine. Fall back to CPU under
    // the simulator only.
#if TARGET_OS_SIMULATOR
    cparams.use_gpu = false;
#else
    cparams.use_gpu = true;
#endif
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

    const int full_len = (int)transcript.size();
    if (full_len >= buf_size) {
        // Write as much as fits so callers can show context in diagnostics,
        // but signal -8 so they don't mistake the truncated text for a complete
        // transcript. Caller is expected to retry with a larger buffer.
        const int partial_len = buf_size - 1;
        std::memcpy(out_buf, transcript.data(), partial_len);
        out_buf[partial_len] = '\0';
        return -8;
    }
    std::memcpy(out_buf, transcript.data(), full_len);
    out_buf[full_len] = '\0';
    return full_len;
}

} // extern "C"

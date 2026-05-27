# `ios/whisper/`

Native side of the whisper.cpp integration. Three things live here:

1. **`whisper.xcframework/`** — prebuilt whisper.cpp framework with `ios-arm64`
   (device) and `ios-arm64_x86_64-simulator` slices. Sourced from the
   official whisper.cpp GitHub release. The full release zip also contains
   `macos-*`, `tvos-*`, and `xros-*` slices; those are stripped here to keep
   the Runner bundle small.
2. **`wrapper.cpp` / `wrapper.h`** — a single C-ABI function,
   `spike_transcribe_wav`, that takes a 16 kHz mono 16-bit PCM WAV file path
   and a ggml model path and returns the transcript as a null-terminated
   string. This is the only symbol Dart FFI looks up.
3. **`ShowerThoughtsWhisper.podspec`** — local CocoaPods spec that compiles
   `wrapper.cpp` into the Runner app and vendors `whisper.xcframework`. The
   project `Podfile` references it via `pod 'ShowerThoughtsWhisper', :path => './whisper'`.

## How the symbol gets into the iOS build

```
ios/whisper/wrapper.cpp  ──(podspec compiles)──┐
                                                ├──► Runner.app
ios/whisper/whisper.xcframework ──(vendored)───┘    contains spike_transcribe_wav
                                                    + libwhisper + libggml
```

At runtime, `lib/transcription/whisper_ffi.dart` calls
`DynamicLibrary.process()` and `lookup<'spike_transcribe_wav'>` finds the
symbol in the running binary. There is no extra dylib to ship.

## Refreshing the xcframework

If you need to pull a newer release, the canonical fetch URL pattern is in
the user-memory file `reference_whisper_artifacts.md`. Quick recipe:

```bash
# From the repo root
WHISPER_VERSION=v1.8.4
curl -L -o /tmp/whisper-xcframework.zip \
  "https://github.com/ggml-org/whisper.cpp/releases/download/$WHISPER_VERSION/whisper-$WHISPER_VERSION-xcframework.zip"
unzip -q /tmp/whisper-xcframework.zip -d /tmp/whisper-extracted

# Replace, then strip non-iOS slices and dSYMs to keep repo size small.
rm -rf ios/whisper/whisper.xcframework
mkdir -p ios/whisper/whisper.xcframework/ios-arm64 \
         ios/whisper/whisper.xcframework/ios-arm64_x86_64-simulator
cp -R /tmp/whisper-extracted/build-apple/whisper.xcframework/ios-arm64/whisper.framework \
      ios/whisper/whisper.xcframework/ios-arm64/whisper.framework
cp -R /tmp/whisper-extracted/build-apple/whisper.xcframework/ios-arm64_x86_64-simulator/whisper.framework \
      ios/whisper/whisper.xcframework/ios-arm64_x86_64-simulator/whisper.framework
# Then hand-edit ios/whisper/whisper.xcframework/Info.plist to list only the
# two iOS slices (drop macos/tvos/xros entries).

cd ios && pod install && cd ..
```

If the wrapper API changes, also regenerate the Dart bindings:

```bash
dart run ffigen --config ffigen.yaml
```

## Building from source instead

The xcframework approach is preferred (faster, less to go wrong in CI). If
for some reason you need to build from source — for an arch the prebuilt
release doesn't cover, or to enable a non-default backend — the spike
artifacts under `.spikes/whisper.cpp/` are a working CMake checkout. See
`reference_whisper_artifacts.md` for the cmake invocation.

## Model file

The ggml model that feeds `spike_transcribe_wav` is *not* shipped here. It's
a Flutter asset at `assets/models/ggml-tiny.en.bin` (~77 MB) and is copied
to `<documents>/ggml-tiny.en.bin` on first launch by
`lib/transcription/model_assets.dart`. The model file is `.gitignore`'d
because it's too big for vanilla git; fetch it once with:

```bash
curl -L -o assets/models/ggml-tiny.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin
```

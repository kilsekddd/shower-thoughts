import 'package:flutter/foundation.dart';

/// Registers attributions for native artifacts that aren't pub packages and
/// therefore aren't picked up by Flutter's default `showLicensePage()` scan
/// of `.pub-cache`. Today that's the prebuilt whisper.cpp xcframework
/// vendored under `ios/whisper/` and the `ggml-tiny.en.bin` model shipped
/// as a Flutter asset.
///
/// Call once at app startup (see `main.dart`); idempotent re-registration
/// is harmless but pointless.
void registerNativeArtifactLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['whisper.cpp', 'ggml'],
      _whisperCppLicense,
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['ggml-tiny.en (whisper model)'],
      _modelAttribution,
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['SQLite'],
      _sqliteBlessing,
    );
  });
}

const String _whisperCppLicense = '''
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const String _modelAttribution = '''
The bundled `ggml-tiny.en.bin` speech-recognition model is published by the
ggml authors at https://huggingface.co/ggerganov/whisper.cpp under the MIT
License. It is derived from OpenAI's Whisper architecture and pretrained
weights, also released under the MIT License (Copyright (c) 2022 OpenAI).

MIT License terms apply as reproduced in the whisper.cpp entry above.
''';

const String _sqliteBlessing = '''
SQLite is in the Public Domain. The SQLite authors disclaim copyright to
the source code and place the work in the public domain.

The SQLite blessing:
    May you do good and not evil.
    May you find forgiveness for yourself and forgive others.
    May you share freely, never taking more than you give.
''';

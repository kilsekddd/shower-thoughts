// Dart FFI spike: load libspike_whisper.dylib, transcribe samples/jfk.wav.
// Mirrors the binding pattern Flutter would use via dart:ffi.
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _TranscribeC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _TranscribeDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);

void main(List<String> args) {
  final lib = DynamicLibrary.open('libspike_whisper.dylib');
  final transcribe = lib.lookupFunction<_TranscribeC, _TranscribeDart>('spike_transcribe_wav');

  final modelPath = 'whisper.cpp/models/ggml-tiny.en.bin'.toNativeUtf8();
  final wavPath   = 'whisper.cpp/samples/jfk.wav'.toNativeUtf8();
  const bufSize = 8192;
  final outBuf  = calloc<Uint8>(bufSize).cast<Utf8>();

  final stopwatch = Stopwatch()..start();
  final rc = transcribe(modelPath, wavPath, outBuf, bufSize);
  stopwatch.stop();

  if (rc < 0) {
    stderr.writeln('FFI call failed, rc=$rc, partial buf="${outBuf.toDartString()}"');
    exit(1);
  }

  final text = outBuf.toDartString();
  print('--- Dart-FFI -> whisper.cpp roundtrip ---');
  print('rc=$rc (bytes written)');
  print('latency=${stopwatch.elapsedMilliseconds}ms (includes model load)');
  print('transcript: $text');

  calloc.free(modelPath);
  calloc.free(wavPath);
  calloc.free(outBuf.cast());
}

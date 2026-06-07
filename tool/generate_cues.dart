import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 22050;
const int _bitsPerSample = 16;
const int _channels = 1;
const int _durationMs = 150;
const int _fadeMs = 10;

void main() {
  _writeWav(
    path: 'assets/sounds/start.wav',
    startHz: 600,
    endHz: 900,
  );
  _writeWav(
    path: 'assets/sounds/stop.wav',
    startHz: 900,
    endHz: 600,
  );
  stdout.writeln('Wrote assets/sounds/start.wav and assets/sounds/stop.wav');
}

void _writeWav({
  required String path,
  required double startHz,
  required double endHz,
}) {
  const int totalSamples = (_sampleRate * _durationMs) ~/ 1000;
  const int fadeSamples = (_sampleRate * _fadeMs) ~/ 1000;
  final Int16List samples = Int16List(totalSamples);

  double phase = 0;
  const double dt = 1.0 / _sampleRate;
  for (int i = 0; i < totalSamples; i++) {
    final double t = i / (totalSamples - 1);
    final double freq = startHz + (endHz - startHz) * t;
    phase += 2 * math.pi * freq * dt;

    double envelope = 1.0;
    if (i < fadeSamples) {
      envelope = i / fadeSamples;
    } else if (i >= totalSamples - fadeSamples) {
      envelope = (totalSamples - 1 - i) / fadeSamples;
    }

    final double sample = math.sin(phase) * envelope * 0.6;
    samples[i] = (sample * 32767).round().clamp(-32768, 32767);
  }

  final int dataSize = samples.length * 2;
  final int riffSize = 36 + dataSize;
  final BytesBuilder bb = BytesBuilder();

  bb.add(_ascii('RIFF'));
  bb.add(_u32(riffSize));
  bb.add(_ascii('WAVE'));

  bb.add(_ascii('fmt '));
  bb.add(_u32(16));
  bb.add(_u16(1));
  bb.add(_u16(_channels));
  bb.add(_u32(_sampleRate));
  bb.add(_u32(_sampleRate * _channels * _bitsPerSample ~/ 8));
  bb.add(_u16(_channels * _bitsPerSample ~/ 8));
  bb.add(_u16(_bitsPerSample));

  bb.add(_ascii('data'));
  bb.add(_u32(dataSize));

  final ByteData pcm = ByteData(dataSize);
  for (int i = 0; i < samples.length; i++) {
    pcm.setInt16(i * 2, samples[i], Endian.little);
  }
  bb.add(pcm.buffer.asUint8List());

  final File f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bb.toBytes());
}

List<int> _ascii(String s) => s.codeUnits;

List<int> _u16(int v) {
  final ByteData b = ByteData(2);
  b.setUint16(0, v, Endian.little);
  return b.buffer.asUint8List();
}

List<int> _u32(int v) {
  final ByteData b = ByteData(4);
  b.setUint32(0, v, Endian.little);
  return b.buffer.asUint8List();
}

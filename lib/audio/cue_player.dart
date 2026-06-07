import 'package:audioplayers/audioplayers.dart';

typedef AudioPlayerFactory = AudioPlayer Function();

class CuePlayer {
  CuePlayer({AudioPlayerFactory? playerFactory})
      : _startPlayer = (playerFactory ?? AudioPlayer.new)(),
        _stopPlayer = (playerFactory ?? AudioPlayer.new)();

  final AudioPlayer _startPlayer;
  final AudioPlayer _stopPlayer;

  Future<void> playStart() async {
    await _startPlayer.stop();
    await _startPlayer.play(AssetSource('sounds/start.wav'));
  }

  Future<void> playStop() async {
    await _stopPlayer.stop();
    await _stopPlayer.play(AssetSource('sounds/stop.wav'));
  }

  Future<void> dispose() async {
    await _startPlayer.release();
    await _stopPlayer.release();
    await _startPlayer.dispose();
    await _stopPlayer.dispose();
  }
}

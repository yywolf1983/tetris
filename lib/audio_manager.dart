import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool isMusicEnabled = true;
  bool isSfxEnabled = true;

  Future<void> init() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.5);
    await _sfxPlayer.setVolume(0.7);
  }

  Future<void> playBgm() async {
    if (!isMusicEnabled) return;
    try {
      await _bgmPlayer.play(AssetSource('audio/tetris_bgm.wav'));
    } catch (e) {
      // BGM file not found, try to use a built-in tone
    }
  }

  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  Future<void> pauseBgm() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBgm() async {
    if (isMusicEnabled) {
      await _bgmPlayer.resume();
    }
  }

  Future<void> playClearLine() async {
    if (!isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/clear_line.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playGameOver() async {
    if (!isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/game_over.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playMove() async {
    if (!isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/move.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playRotate() async {
    if (!isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/rotate.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  void toggleMusic() {
    isMusicEnabled = !isMusicEnabled;
    if (isMusicEnabled) {
      resumeBgm();
    } else {
      pauseBgm();
    }
  }

  void toggleSfx() {
    isSfxEnabled = !isSfxEnabled;
  }

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}

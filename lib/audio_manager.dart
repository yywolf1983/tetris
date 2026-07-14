import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal() {
    init();
  }

  final AudioPlayer _bgmPlayer = AudioPlayer();
  // 使用多个音效播放器，避免音效冲突
  final List<AudioPlayer> _sfxPlayers = [];
  int _currentSfxIndex = 0;
  static const int _maxSfxPlayers = 4;
  
  bool isMusicEnabled = true;
  bool isSfxEnabled = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 配置全局音频上下文，确保 BGM 与音效可以同时播放而不互相打断
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
    } catch (e) {
      // ignore
    }

    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.5);

    // 创建多个音效播放器
    for (int i = 0; i < _maxSfxPlayers; i++) {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      _sfxPlayers.add(player);
    }
  }

  AudioPlayer _getNextSfxPlayer() {
    final player = _sfxPlayers[_currentSfxIndex];
    _currentSfxIndex = (_currentSfxIndex + 1) % _sfxPlayers.length;
    return player;
  }

  Future<void> playBgm() async {
    if (!isMusicEnabled) return;
    try {
      if (_bgmPlayer.state == PlayerState.playing) return;
      await _bgmPlayer.play(AssetSource('audio/tetris_bgm.wav'));
    } catch (e) {
      // BGM file not found
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      // ignore
    }
  }

  Future<void> pauseBgm() async {
    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> resumeBgm() async {
    if (!isMusicEnabled) return;
    try {
      if (_bgmPlayer.state == PlayerState.paused) {
        await _bgmPlayer.resume();
      } else {
        await playBgm();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> playClearLineWithCount(int lineCount) async {
    if (!isSfxEnabled) return;
    try {
      final player = _getNextSfxPlayer();
      if (lineCount >= 4) {
        await player.play(AssetSource('audio/clear_line_multi.wav'));
      } else if (lineCount >= 2) {
        await player.play(AssetSource('audio/clear_line_multi.wav'));
      } else {
        await player.play(AssetSource('audio/clear_line_single.wav'));
      }
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playGameOver() async {
    if (!isSfxEnabled) return;
    try {
      final player = _getNextSfxPlayer();
      await player.play(AssetSource('audio/game_over.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playMove() async {
    if (!isSfxEnabled) return;
    try {
      final player = _getNextSfxPlayer();
      await player.play(AssetSource('audio/move.wav'));
    } catch (e) {
      // SFX file not found
    }
  }

  Future<void> playRotate() async {
    if (!isSfxEnabled) return;
    try {
      final player = _getNextSfxPlayer();
      await player.play(AssetSource('audio/rotate.wav'));
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
    for (final player in _sfxPlayers) {
      await player.dispose();
    }
    _sfxPlayers.clear();
  }
}
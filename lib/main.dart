import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_manager.dart';
import 'tetromino.dart';

void main() {
  runApp(const TetrisApp());
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tetris',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TetrisGame(),
    );
  }
}

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  _TetrisGameState createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int rows = 20;
  static const int cols = 10;
  static const String highScoreKey = 'tetris_high_score';
  static const String musicEnabledKey = 'tetris_music_enabled';
  static const String sfxEnabledKey = 'tetris_sfx_enabled';
  static const String gameStateKey = 'tetris_game_state';
  late List<List<int>> board;
  late Tetromino currentPiece;
  late Tetromino nextPiece;
  late int score;
  int totalLines = 0;
  late int highScore;
  bool gameOver = false;
  bool gameStarted = false;
  bool gamePaused = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  List<int> _clearingLines = [];
  bool _isClearing = false;
  late Timer _fastDropTimer;
  late Timer _leftMoveTimer;
  late Timer _rightMoveTimer;
  late Timer _gameLoopTimer;
  late double gameSpeed;
  late int speedLevel;
  late AudioManager _audioManager;
  late bool _isMusicEnabled;
  late bool _isSfxEnabled;
  late double controlButtonSize;
  String? _activeControl;

  @override
  void initState() {
    super.initState();
    board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    currentPiece = Tetromino.random();
    nextPiece = Tetromino.random();
    score = 0;
    highScore = 0;
    gameSpeed = 500.0;
    speedLevel = 0;
    _isMusicEnabled = true;
    _isSfxEnabled = true;
    _audioManager = AudioManager();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _clearingLines.clear();
        });
      }
    });
    
    // 闪光动画 - 渐变淡出效果
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _fastDropTimer = Timer(Duration.zero, () {});
    _leftMoveTimer = Timer(Duration.zero, () {});
    _rightMoveTimer = Timer(Duration.zero, () {});
    _gameLoopTimer = Timer(Duration.zero, () {});
    
    _loadHighScore();
    _loadAudioSettings();
    _loadGameState();

    // 监听前后台切换
    WidgetsBinding.instance.addObserver(this);

    // 添加键盘事件监听
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  Future<void> _loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMusicEnabled = prefs.getBool(musicEnabledKey) ?? true;
      _isSfxEnabled = prefs.getBool(sfxEnabledKey) ?? true;
      _audioManager.isMusicEnabled = _isMusicEnabled;
      _audioManager.isSfxEnabled = _isSfxEnabled;
    });
  }

  Future<void> _saveAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(musicEnabledKey, _isMusicEnabled);
    await prefs.setBool(sfxEnabledKey, _isSfxEnabled);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt(highScoreKey) ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(highScoreKey, highScore);
  }

  Map<String, dynamic> _pieceToMap(Tetromino p) => {
    'x': p.x,
    'y': p.y,
    'color': p.color,
    'shape': p.shape.map((r) => r.join(',')).toList(),
  };

  Tetromino _pieceFromMap(Map<String, dynamic> m) {
    final shape = (m['shape'] as List)
        .map((r) => (r as String).split(',').map((e) => int.parse(e)).toList())
        .toList();
    return Tetromino(m['x'] as int, m['y'] as int, shape, m['color'] as int);
  }

  Future<void> _saveGameState() async {
    if (!gameStarted || gameOver) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = <String, dynamic>{
        'score': score,
        'totalLines': totalLines,
        'speedLevel': speedLevel,
        'gameSpeed': gameSpeed,
        'board': board.expand((r) => r).toList(),
        'current': _pieceToMap(currentPiece),
        'next': _pieceToMap(nextPiece),
      };
      await prefs.setString(gameStateKey, jsonEncode(state));
    } catch (e) {
      // 忽略序列化异常
    }
  }

  Future<void> _loadGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(gameStateKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final boardFlat = (m['board'] as List).cast<int>();
      final restoredBoard = List.generate(
        rows,
        (i) => boardFlat.sublist(i * cols, (i + 1) * cols),
      );
      setState(() {
        board = restoredBoard;
        score = m['score'] as int;
        totalLines = (m['totalLines'] as int?) ?? 0;
        speedLevel = m['speedLevel'] as int;
        gameSpeed = m['gameSpeed'] as double;
        currentPiece = _pieceFromMap(m['current'] as Map<String, dynamic>);
        nextPiece = _pieceFromMap(m['next'] as Map<String, dynamic>);
        gameStarted = true;
        gameOver = false;
        // 恢复后保持暂停状态，由玩家手动继续
        gamePaused = true;
      });
    } catch (e) {
      // 状态损坏则忽略
    }
  }

  Future<void> _clearGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(gameStateKey);
    } catch (e) {
      // 忽略
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!gameStarted || gameOver) return;
    
    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyA:
          moveLeft();
          break;
        case LogicalKeyboardKey.keyD:
          moveRight();
          break;
        case LogicalKeyboardKey.keyS:
          moveDown();
          break;
        case LogicalKeyboardKey.keyW:
          rotate();
          break;
        case LogicalKeyboardKey.keyP:
          togglePause();
          break;
        case LogicalKeyboardKey.space:
          hardDrop();
          break;
      }
    }
  }

  void startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(Duration(milliseconds: gameSpeed.toInt()), (timer) {
      if (!gameOver && !gamePaused) {
        moveDown();
      } else if (gameOver) {
        timer.cancel();
      }
    });
  }

  void startGame() {
    setState(() {
      gameStarted = true;
      board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
      currentPiece = Tetromino.random();
      nextPiece = Tetromino.random();
      score = 0;
      totalLines = 0;
      gameSpeed = 500.0;
      speedLevel = 0;
      gameOver = false;
    });
    _audioManager.playBgm();
    startGameLoop();
  }

  void togglePause() {
    if (!gameStarted || gameOver) return;
    
    setState(() {
      gamePaused = !gamePaused;
    });
    
    if (gamePaused) {
      _gameLoopTimer.cancel();
      _audioManager.pauseBgm();
      _saveGameState();
    } else {
      startGameLoop();
      _audioManager.resumeBgm();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切换到后台时自动暂停并保存当前游戏状态
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (gameStarted && !gameOver && !gamePaused) {
        togglePause();
      } else {
        _saveGameState();
      }
    }
  }

  void hardDrop() {
    if (_isClearing) return;
    if (gameOver || !gameStarted || gamePaused) return;
    
    // 快速下落到底部
    while (!checkCollision(currentPiece.x, currentPiece.y + 1, currentPiece.shape)) {
      currentPiece.y++;
    }
    
    // 锁定方块并处理消行
    lockPiece();
    clearLines();
    currentPiece = nextPiece;
    nextPiece = Tetromino.random();
    
    // 检查游戏是否结束
    if (checkCollision(currentPiece.x, currentPiece.y, currentPiece.shape)) {
      setState(() {
        gameOver = true;
      });
      _audioManager.playGameOver();
      _audioManager.stopBgm();
      if (score > highScore) {
        highScore = score;
        _saveHighScore();
      }
    }
    
    setState(() {});
  }

  int getGhostY() {
    if (gameOver || !gameStarted) return currentPiece.y;
    
    int ghostY = currentPiece.y;
    while (!checkCollision(currentPiece.x, ghostY + 1, currentPiece.shape)) {
      ghostY++;
    }
    return ghostY;
  }

  void moveLeft() {
    if (!gameOver && gameStarted && !checkCollision(currentPiece.x - 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x--;
      });
      _audioManager.playMove();
    }
  }

  void moveRight() {
    if (!gameOver && gameStarted && !checkCollision(currentPiece.x + 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x++;
      });
      _audioManager.playMove();
    }
  }

  void moveDown() {
    if (_isClearing) return;
    if (!gameOver && gameStarted && !checkCollision(currentPiece.x, currentPiece.y + 1, currentPiece.shape)) {
      setState(() {
        currentPiece.y++;
      });
    } else if (gameStarted) {
      lockPiece();
      clearLines();
      currentPiece = nextPiece;
      nextPiece = Tetromino.random();
      if (checkCollision(currentPiece.x, currentPiece.y, currentPiece.shape)) {
        setState(() {
          gameOver = true;
        });
        _audioManager.playGameOver();
        _audioManager.stopBgm();
        _clearGameState();
        if (score > highScore) {
          highScore = score;
          _saveHighScore();
        }
      }
    }
  }

  void rotate() {
    if (!gameOver && gameStarted) {
      List<List<int>> rotatedShape = currentPiece.rotate();
      if (!checkCollision(currentPiece.x, currentPiece.y, rotatedShape)) {
        setState(() {
          currentPiece.shape = rotatedShape;
        });
        _audioManager.playRotate();
      }
    }
  }

  void _startFastDrop() {
    // 开始快速下落，每100毫秒移动一次
    _fastDropTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (gameStarted && !gameOver) {
        moveDown();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopFastDrop() {
    // 停止快速下落
    if (_fastDropTimer.isActive) {
      _fastDropTimer.cancel();
    }
  }

  void _startLeftMove() {
    // 首次延迟后开始连续左移，降低灵敏度避免误触连发
    _leftMoveTimer = Timer(const Duration(milliseconds: 180), () {
      if (gameStarted && !gameOver) {
        moveLeft();
        _leftMoveTimer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
          if (gameStarted && !gameOver) {
            moveLeft();
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _stopLeftMove() {
    // 停止快速左移
    if (_leftMoveTimer.isActive) {
      _leftMoveTimer.cancel();
    }
  }

  void _startRightMove() {
    // 首次延迟后开始连续右移，降低灵敏度避免误触连发
    _rightMoveTimer = Timer(const Duration(milliseconds: 180), () {
      if (gameStarted && !gameOver) {
        moveRight();
        _rightMoveTimer = Timer.periodic(const Duration(milliseconds: 110), (timer) {
          if (gameStarted && !gameOver) {
            moveRight();
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _stopRightMove() {
    // 停止快速右移
    if (_rightMoveTimer.isActive) {
      _rightMoveTimer.cancel();
    }
  }

  bool checkCollision(int x, int y, List<List<int>> shape) {
    for (int i = 0; i < shape.length; i++) {
      for (int j = 0; j < shape[i].length; j++) {
        if (shape[i][j] != 0) {
          int newX = x + j;
          int newY = y + i;
          if (newX < 0 || newX >= cols || newY >= rows) {
            return true;
          }
          if (newY >= 0 && board[newY][newX] != 0) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void lockPiece() {
    for (int i = 0; i < currentPiece.shape.length; i++) {
      for (int j = 0; j < currentPiece.shape[i].length; j++) {
        if (currentPiece.shape[i][j] != 0) {
          int newY = currentPiece.y + i;
          int newX = currentPiece.x + j;
          if (newY >= 0) {
            board[newY][newX] = currentPiece.color;
          }
        }
      }
    }
  }

  void clearLines() {
    if (_isClearing) return;
    List<int> linesToClear = [];
    for (int row = rows - 1; row >= 0; row--) {
      bool isLineFull = true;
      for (int col = 0; col < cols; col++) {
        if (board[row][col] == 0) {
          isLineFull = false;
          break;
        }
      }
      if (isLineFull) {
        linesToClear.add(row);
      }
    }
    
    if (linesToClear.isNotEmpty) {
      setState(() {
        _isClearing = true;
        _clearingLines = linesToClear;
      });
      
      // 启动缩放动画
      _controller.forward(from: 0.0);
      // 启动闪光动画（从高亮渐变淡出）
      _flashController.forward(from: 0.0);
      
      // 延迟后清除行（与动画时长同步）
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          int linesCleared = linesToClear.length;
          int startRow = linesToClear.last; // 最上面的消除行
          
          // 从最上面的消除行开始，将所有上方的行向下移动
          for (int r = startRow; r > 0; r--) {
            for (int col = 0; col < cols; col++) {
              board[r + linesCleared - 1][col] = board[r - 1][col];
            }
          }
          
          // 将最上方的 linesCleared 行置为 0
          for (int r = 0; r < linesCleared; r++) {
            for (int col = 0; col < cols; col++) {
              board[r][col] = 0;
            }
          }
          
          // 更新分数（传统俄罗斯方块计分：单行/多行不同，并按当前等级放大）
          final int level = speedLevel + 1;
          const Map<int, int> lineScores = {
            1: 100,
            2: 300,
            3: 500,
            4: 800,
          };
          final int gained = (lineScores[linesCleared] ?? linesCleared * 200) * level;
          score += gained;
          totalLines += linesCleared;

          _clearingLines.clear();
          _isClearing = false;

          // 检查是否需要加速
          checkAndUpdateSpeed();

          // 播放消除音效
          _audioManager.playClearLineWithCount(linesCleared);
        });
      });
    }
  }
  
  void checkAndUpdateSpeed() {
    // 计算当前应该达到的速度级别
    int newSpeedLevel = 0;
    int currentScore = score;
    
    // 10000, 20000, 40000, 80000, ...
    int targetScore = 10000;
    while (currentScore >= targetScore) {
      newSpeedLevel++;
      targetScore *= 2;
    }
    
    // 计算新的游戏速度，每次加速10%
    double newSpeed = 500.0 * (math.pow(0.9, newSpeedLevel));
    
    // 确保速度不会过快
    newSpeed = newSpeed.clamp(100.0, 500.0);
    
    if (newSpeed != gameSpeed || newSpeedLevel != speedLevel) {
      setState(() {
        gameSpeed = newSpeed;
        speedLevel = newSpeedLevel;
      });
      // 重新启动游戏循环以应用新速度
      if (gameStarted && !gameOver) {
        startGameLoop();
      }
    }
  }

  Color getColor(int colorCode) => blockColor(colorCode);

  Widget _buildNextPiecePreview() {
    return Container(
      width: 90,
      height: 90,
      padding: const EdgeInsets.all(4),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
        ),
        itemCount: 16,
        itemBuilder: (context, index) {
          int row = index ~/ 4;
          int col = index % 4;
          bool isNextPiece = false;
          if (row < nextPiece.shape.length && col < nextPiece.shape[row].length) {
            isNextPiece = nextPiece.shape[row][col] != 0;
          }
          Color cellColor = isNextPiece ? getColor(nextPiece.color) : Colors.grey[900]!;
          return Container(
            decoration: BoxDecoration(
              color: cellColor,
              border: Border.all(color: Colors.grey[700]!, width: 0.5),
              boxShadow: isNextPiece ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 1,
                ),
              ] : [],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 1),
        Text(value, style: TextStyle(fontSize: 12, color: valueColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData enabledIcon,
    required IconData disabledIcon,
    required bool enabled,
    required VoidCallback onTap,
    List<Color>? activeGradient,
  }) {
    final List<Color> active = activeGradient ?? const [Color(0xFF26c6da), Color(0xFF1e88e5)];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: enabled ? LinearGradient(colors: active) : null,
          color: enabled ? null : Colors.grey[700],
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: enabled
              ? [BoxShadow(color: active.last.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Icon(
          enabled ? enabledIcon : disabledIcon,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMusicButton() {
    return _buildToggleButton(
      enabledIcon: Icons.music_note_rounded,
      disabledIcon: Icons.music_off_rounded,
      enabled: _isMusicEnabled,
      activeGradient: const [Color(0xFF7e57c2), Color(0xFF5e35b1)],
      onTap: () {
        setState(() {
          _audioManager.toggleMusic();
          _isMusicEnabled = _audioManager.isMusicEnabled;
          _saveAudioSettings();
        });
      },
    );
  }

  Widget _buildSfxButton() {
    return _buildToggleButton(
      enabledIcon: Icons.volume_up_rounded,
      disabledIcon: Icons.volume_off_rounded,
      enabled: _isSfxEnabled,
      activeGradient: const [Color(0xFF26c6da), Color(0xFF1e88e5)],
      onTap: () {
        setState(() {
          _audioManager.toggleSfx();
          _isSfxEnabled = _audioManager.isSfxEnabled;
          _saveAudioSettings();
        });
      },
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: togglePause,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: gamePaused ? Colors.orange : Colors.grey[700],
          shape: BoxShape.circle,
        ),
        child: Text(
          gamePaused ? '▶' : '⏸',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGameBoard(double width, double height, double cellSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flashAnimation, _animation]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, height),
          painter: GameBoardPainter(
            board: board,
            currentPiece: currentPiece,
            ghostY: getGhostY(),
            clearingLines: _clearingLines,
            flashValue: _flashAnimation.value,
            clearScale: _animation.value,
            cellSize: cellSize,
            rows: rows,
            cols: cols,
          ),
        );
      },
    );
  }

  Widget _buildOverlayButton(String label, VoidCallback onPressed, List<Color> gradient) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: gradient.last.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String id,
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
    double? size,
    double? width,
    List<Color>? colors,
  }) {
    final double s = size ?? controlButtonSize;
    final double w = width ?? s;
    final bool active = _activeControl == id;
    final List<Color> base = colors ?? const [Color(0xFF2a3340), Color(0xFF1c232c)];
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _activeControl = id);
        onDown();
      },
      onTapUp: (_) {
        setState(() => _activeControl = null);
        onUp();
      },
      onTapCancel: () {
        setState(() => _activeControl = null);
        onUp();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transformAlignment: Alignment.center,
        transform: active ? (Matrix4.identity()..scale(0.94)) : Matrix4.identity(),
        width: w,
        height: s,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? base.map((c) => Color.alphaBlend(Colors.white.withOpacity(0.18), c)).toList()
                : base,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.14),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(active ? 0.15 : 0.45),
              offset: Offset(0, active ? 1 : 4),
              blurRadius: active ? 3 : 8,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: s * 0.5, color: Colors.white,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    // 计算游戏内容最大高度，确保不超出屏幕
    // 桌面端使用更大的高度，接近屏幕高度
    double maxGameHeight = MediaQuery.of(context).size.width >= 600 
        ? screenHeight - 50 // 桌面端只减去少量边距
        : screenHeight - 100; // 移动端减去更多边距
    
    // 计算游戏板尺寸，保持2:1的高宽比
    // 桌面端使用更大的比例
    double boardWidth = MediaQuery.of(context).size.width >= 600 
        ? screenWidth * 0.8 
        : screenWidth * 0.6;
    
    // 确保boardWidth为正数
    boardWidth = boardWidth.clamp(100.0, screenWidth);
    
    // 网格与边框/圆角之间的内边距，避免方块被圆角裁切或被边框遮盖
    const double boardPadding = 3.0;

    double cellSize = (boardWidth - 2 * boardPadding) / cols;
    double boardHeight = cellSize * rows + 2 * boardPadding;
    
    // 确保游戏板高度不超出最大游戏高度
    if (boardHeight > maxGameHeight * 0.8) {
      boardHeight = maxGameHeight * 0.8;
      // 确保boardHeight为正数
      boardHeight = boardHeight.clamp(200.0, maxGameHeight);
      cellSize = (boardHeight - 2 * boardPadding) / rows;
      boardWidth = cellSize * cols + 2 * boardPadding;
    }
    
    // 再次确保boardWidth为正数
    boardWidth = boardWidth.clamp(100.0, screenWidth);
    
    // 计算按钮大小，根据屏幕宽度自适应
    controlButtonSize = screenWidth * 0.18;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景渐变 - 柔和的深色
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1e2a3a),
                  Color(0xFF2a3a4a),
                  Color(0xFF1e2a3a),
                ],
              ),
            ),
          ),
          // 柔和的遮罩层（移除模糊，减少视觉疲劳）
          Container(
            color: Colors.black.withOpacity(0.02),
          ),
          // 游戏内容
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    // Header bar with game stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('TETRIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                            ],
                          ),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildStatItem('Best', '$highScore', Colors.yellow),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildStatItem('Level', '$speedLevel', Colors.cyan),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildMusicButton(),
                          const SizedBox(width: 8),
                          _buildSfxButton(),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildPauseButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game board
                        Container(
                          width: boardWidth,
                          height: boardHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.35), width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.cyanAccent.withOpacity(0.15), blurRadius: 18, spreadRadius: 1),
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(boardPadding),
                              child: RepaintBoundary(
                                child: _buildGameBoard(cellSize * cols, cellSize * rows, cellSize),
                              ),
                            ),
                          ),
                        ),
                        
                        // Sidebar
                        const SizedBox(width: 10),
                        Container(
                          width: MediaQuery.of(context).size.width >= 600 ? 170 : 120,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[700]!, width: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[850],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF26c6da), Color(0xFF1e88e5)]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.filter_none_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Next', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[600]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[900],
                                ),
                                child: _buildNextPiecePreview(),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFffb300), Color(0xFFfb8c00)]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Score', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: MediaQuery.of(context).size.width >= 600 ? 150 : 120,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!, width: 1),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('$score', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF66bb6a), Color(0xFF43a047)]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.linear_scale_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Lines', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: MediaQuery.of(context).size.width >= 600 ? 150 : 120,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!, width: 1),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('$totalLines', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // 减小间距，特别是桌面端
                    const SizedBox(height: 20),
                    
                    // Game controls - 仅移动端显示
                    if (MediaQuery.of(context).size.width < 600)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1a2230), Color(0xFF141b26)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 6), blurRadius: 14),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 方向键区
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildControlButton(
                                        id: 'left',
                                        icon: Icons.arrow_left_rounded,
                                        onDown: () { moveLeft(); _startLeftMove(); },
                                        onUp: _stopLeftMove,
                                      ),
                                      const SizedBox(width: 18),
                                      _buildControlButton(
                                        id: 'right',
                                        icon: Icons.arrow_right_rounded,
                                        onDown: () { moveRight(); _startRightMove(); },
                                        onUp: _stopRightMove,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                      _buildControlButton(
                                        id: 'down',
                                        icon: Icons.arrow_downward_rounded,
                                    onDown: () { moveDown(); _startFastDrop(); },
                                    onUp: _stopFastDrop,
                                    width: controlButtonSize * 2 + 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 44),
                            // 旋转按钮（青色渐变）
                            _buildControlButton(
                              id: 'rotate',
                              icon: Icons.rotate_right_rounded,
                              onDown: rotate,
                              onUp: () {},
                              size: controlButtonSize * 1.7,
                              colors: [Colors.cyan, Colors.blue],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // 开始界面浮层
          if (!gameStarted)
            Container(
              color: Colors.black.withOpacity(0.78),
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1b2735), Color(0xFF243447)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_module_rounded, size: 54, color: Colors.cyanAccent),
                      const SizedBox(height: 14),
                      const Text('TETRIS', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5)),
                      const SizedBox(height: 8),
                      Text(
                        MediaQuery.of(context).size.width >= 600
                            ? 'WASD 移动 · 空格速降 · P 暂停'
                            : '屏幕按钮控制 · A 旋转',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9fb3c8)),
                      ),
                      const SizedBox(height: 32),
                      _buildOverlayButton('开始游戏', startGame, [Colors.cyan, Colors.blue]),
                    ],
                  ),
                ),
              ),
            ),
          
          // 暂停界面浮层
          if (gamePaused && gameStarted && !gameOver)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2a2433), Color(0xFF342a40)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_filled_rounded, size: 50, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text('已暂停', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 10),
                      Text('当前分数: $score', style: const TextStyle(fontSize: 22, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('速度等级: $speedLevel', style: const TextStyle(fontSize: 18, color: Colors.cyan)),
                      const SizedBox(height: 28),
                      _buildOverlayButton('继续游戏', togglePause, [Colors.orange, Colors.deepOrange]),
                    ],
                  ),
                ),
              ),
            ),
          
          // 游戏结束浮层
          if (gameOver)
            Container(
              color: Colors.black.withOpacity(0.72),
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF331c1c), Color(0xFF3a2222)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sentiment_very_dissatisfied_rounded, size: 50, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text('游戏结束', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      const SizedBox(height: 14),
                      Text('本局得分: $score', style: const TextStyle(fontSize: 22, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('最高分: $highScore', style: const TextStyle(fontSize: 18, color: Colors.yellow)),
                      const SizedBox(height: 28),
                      _buildOverlayButton('再来一局', startGame, [Colors.redAccent, Colors.pink]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _flashController.dispose();
    _gameLoopTimer.cancel();
    _fastDropTimer.cancel();
    _leftMoveTimer.cancel();
    _rightMoveTimer.cancel();
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Color blockColor(int code) {
  switch (code) {
    case 1: return Colors.cyan;
    case 2: return Colors.yellow;
    case 3: return Colors.purple;
    case 4: return Colors.green;
    case 5: return Colors.red;
    case 6: return Colors.blue;
    case 7: return Colors.orange;
    default: return const Color(0xFFe0e0e0);
  }
}

class GameBoardPainter extends CustomPainter {
  final List<List<int>> board;
  final Tetromino currentPiece;
  final int ghostY;
  final List<int> clearingLines;
  final double flashValue;
  final double clearScale;
  final double cellSize;
  final int rows;
  final int cols;

  GameBoardPainter({
    required this.board,
    required this.currentPiece,
    required this.ghostY,
    required this.clearingLines,
    required this.flashValue,
    required this.clearScale,
    required this.cellSize,
    required this.rows,
    required this.cols,
  });

  Color _lighten(Color c, double t) => Color.alphaBlend(Colors.white.withOpacity(t), c);
  Color _darken(Color c, double t) => Color.alphaBlend(Colors.black.withOpacity(t), c);

  void _drawEmpty(Canvas canvas, double x, double y) {
    final r = Rect.fromLTWH(x + 0.5, y + 0.5, cellSize - 1, cellSize - 1);
    canvas.drawRect(r, Paint()..color = const Color(0xFF0d1219));
    // 极淡网格线，弱化单元格之间的对比
    canvas.drawRect(
      r,
      Paint()
        ..color = Colors.white.withOpacity(0.018)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawBlock(Canvas canvas, double x, double y, Color base,
      {bool ghost = false, double scale = 1.0, double flash = 0.0}) {
    final inset = cellSize * 0.01;
    final rect = Rect.fromLTWH(x + inset, y + inset, cellSize - 2 * inset, cellSize - 2 * inset);
    final radius = Radius.circular(cellSize * 0.16);

    canvas.save();
    if (scale != 1.0) {
      final cx = x + cellSize / 2;
      final cy = y + cellSize / 2;
      canvas.translate(cx, cy);
      canvas.scale(scale, scale);
      canvas.translate(-cx, -cy);
    }

    final rrect = RRect.fromRectAndRadius(rect, radius);

    if (ghost) {
      canvas.drawRRect(rrect, Paint()..color = base.withOpacity(0.14));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = base.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    } else {
      // 轻微投影，避免每个方块被阴影割裂
      canvas.drawShadow(Path()..addRRect(rrect), Colors.black.withOpacity(0.4), 2.5, false);
      // 立体渐变主体（左上亮、右下暗）
      final body = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(base, 0.32), base, _darken(base, 0.28)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, body);

      // 顶部玻璃高光
      final gloss = Rect.fromLTWH(
        rect.left + rect.width * 0.14,
        rect.top + rect.height * 0.1,
        rect.width * 0.72,
        rect.height * 0.42,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(gloss, Radius.circular(cellSize * 0.14)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.0)],
          ).createShader(gloss),
      );

      // 仅用极淡内高光勾边，不再加深色描边，避免方块间出现割裂感
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 0.8, rect.top + 0.8, rect.width - 1.6, rect.height - 1.6),
          Radius.circular(cellSize * 0.14),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    if (flash > 0) {
      canvas.drawRRect(rrect, Paint()..color = Colors.white.withOpacity(flash * 0.7));
    }

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0b0f14),
    );

    // 已固定的方块
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final code = board[r][c];
        final x = c * cellSize;
        final y = r * cellSize;
        if (code != 0) {
          final clearing = clearingLines.contains(r);
          _drawBlock(
            canvas,
            x,
            y,
            blockColor(code),
            scale: clearing ? clearScale : 1.0,
            flash: clearing ? flashValue : 0.0,
          );
        } else {
          _drawEmpty(canvas, x, y);
        }
      }
    }

    // 幽灵方块
    for (int i = 0; i < currentPiece.shape.length; i++) {
      for (int j = 0; j < currentPiece.shape[i].length; j++) {
        if (currentPiece.shape[i][j] != 0) {
          final x = (currentPiece.x + j) * cellSize;
          final y = (ghostY + i) * cellSize;
          if (y >= 0) _drawBlock(canvas, x, y, blockColor(currentPiece.color), ghost: true);
        }
      }
    }

    // 当前方块
    for (int i = 0; i < currentPiece.shape.length; i++) {
      for (int j = 0; j < currentPiece.shape[i].length; j++) {
        if (currentPiece.shape[i][j] != 0) {
          final x = (currentPiece.x + j) * cellSize;
          final y = (currentPiece.y + i) * cellSize;
          if (y >= 0) _drawBlock(canvas, x, y, blockColor(currentPiece.color));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameBoardPainter old) => true;
}

import 'dart:async';
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

class _TetrisGameState extends State<TetrisGame> with SingleTickerProviderStateMixin {
  static const int rows = 20;
  static const int cols = 10;
  static const String highScoreKey = 'tetris_high_score';
  static const String musicEnabledKey = 'tetris_music_enabled';
  static const String sfxEnabledKey = 'tetris_sfx_enabled';
  late List<List<int>> board;
  late Tetromino currentPiece;
  late Tetromino nextPiece;
  late int score;
  late int highScore;
  bool gameOver = false;
  bool gameStarted = false;
  bool gamePaused = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  List<int> _clearingLines = [];
  late Timer _fastDropTimer;
  late Timer _leftMoveTimer;
  late Timer _rightMoveTimer;
  late Timer _gameLoopTimer;
  late double gameSpeed;
  late int speedLevel;
  late AudioManager _audioManager;
  late bool _isMusicEnabled;
  late bool _isSfxEnabled;

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
      duration: const Duration(milliseconds: 600),
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
      duration: const Duration(milliseconds: 600),
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
    } else {
      startGameLoop();
      _audioManager.resumeBgm();
    }
  }

  void hardDrop() {
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
    // 开始快速左移，每100毫秒移动一次
    _leftMoveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (gameStarted && !gameOver) {
        moveLeft();
      } else {
        timer.cancel();
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
    // 开始快速右移，每100毫秒移动一次
    _rightMoveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (gameStarted && !gameOver) {
        moveRight();
      } else {
        timer.cancel();
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
        _clearingLines = linesToClear;
      });
      
      // 启动缩放动画
      _controller.forward(from: 0.0);
      // 启动闪光动画（从高亮渐变淡出）
      _flashController.forward(from: 0.0);
      
      // 延迟后清除行（与动画时长同步）
      Future.delayed(const Duration(milliseconds: 600), () {
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
          
          // 更新分数
          score += linesCleared * 100;

          _clearingLines.clear();

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

  Color getColor(int colorCode) {
    switch (colorCode) {
      case 1: return Colors.cyan;
      case 2: return Colors.yellow;
      case 3: return Colors.purple;
      case 4: return Colors.green;
      case 5: return Colors.red;
      case 6: return Colors.blue;
      case 7: return Colors.orange;
      default: return Colors.grey[200]!;
    }
  }

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

  Widget _buildSoundButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _audioManager.toggleSfx();
              _isSfxEnabled = _audioManager.isSfxEnabled;
              _saveAudioSettings();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isSfxEnabled ? Colors.green : Colors.grey[700],
              shape: BoxShape.circle,
            ),
            child: const Text('♫', style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ),
      ],
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
    
    double cellSize = boardWidth / cols;
    double boardHeight = cellSize * rows;
    
    // 确保游戏板高度不超出最大游戏高度
    if (boardHeight > maxGameHeight * 0.8) {
      boardHeight = maxGameHeight * 0.8;
      // 确保boardHeight为正数
      boardHeight = boardHeight.clamp(200.0, maxGameHeight);
      boardWidth = boardHeight / 2;
      cellSize = boardWidth / cols;
    }
    
    // 再次确保boardWidth为正数
    boardWidth = boardWidth.clamp(100.0, screenWidth);
    
    // 计算按钮大小，根据屏幕宽度自适应
    double controlButtonSize = screenWidth * 0.18;

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
                          const Text('Tetris', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildStatItem('Best', '$highScore', Colors.yellow),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildStatItem('Level', '$speedLevel', Colors.cyan),
                          Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          _buildSoundButton(),
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
                        SizedBox(
                          width: boardWidth,
                          height: boardHeight,
                          child: RepaintBoundary(
                            child: GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                childAspectRatio: 1,
                              ),
                              itemCount: rows * cols,
                              itemBuilder: (context, index) {
                                int row = index ~/ cols;
                                int col = index % cols;
                                bool isCurrentPiece = false;
                                bool isGhostPiece = false;
                                
                                // 检测当前方块
                                for (int i = 0; i < currentPiece.shape.length; i++) {
                                  for (int j = 0; j < currentPiece.shape[i].length; j++) {
                                    if (currentPiece.shape[i][j] != 0) {
                                      int pieceRow = currentPiece.y + i;
                                      int pieceCol = currentPiece.x + j;
                                      if (pieceRow == row && pieceCol == col) {
                                        isCurrentPiece = true;
                                        break;
                                      }
                                    }
                                  }
                                  if (isCurrentPiece) break;
                                }
                                
                                // 检测幽灵方块
                                if (!isCurrentPiece) {
                                  int ghostY = getGhostY();
                                  for (int i = 0; i < currentPiece.shape.length; i++) {
                                    for (int j = 0; j < currentPiece.shape[i].length; j++) {
                                      if (currentPiece.shape[i][j] != 0) {
                                        int pieceRow = ghostY + i;
                                        int pieceCol = currentPiece.x + j;
                                        if (pieceRow == row && pieceCol == col) {
                                          isGhostPiece = true;
                                          break;
                                        }
                                      }
                                    }
                                    if (isGhostPiece) break;
                                  }
                                }
                                
                                Color cellColor;
                                if (isCurrentPiece) {
                                  cellColor = getColor(currentPiece.color);
                                } else if (isGhostPiece) {
                                  cellColor = getColor(currentPiece.color).withOpacity(0.3);
                                } else {
                                  cellColor = board[row][col] == 0 ? Colors.grey[850]! : getColor(board[row][col]);
                                }
                                
                                bool isClearing = _clearingLines.contains(row);
                                
                                return AnimatedBuilder(
                                  animation: _flashAnimation,
                                  builder: (context, child) {
                                    return ScaleTransition(
                                      scale: isClearing ? _animation : AlwaysStoppedAnimation(1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cellColor,
                                          border: Border.all(
                                            color: isCurrentPiece || board[row][col] != 0 
                                              ? cellColor.withOpacity(0.8) 
                                              : Colors.grey[700]!,
                                            width: 0.3,
                                          ),
                                          boxShadow: isCurrentPiece || board[row][col] != 0 ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.5),
                                              offset: const Offset(4, 4),
                                              blurRadius: 4,
                                            ),
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.2),
                                              offset: const Offset(-3, -3),
                                              blurRadius: 3,
                                            ),
                                            BoxShadow(
                                              color: cellColor.withOpacity(0.3),
                                              offset: const Offset(-1, -1),
                                              blurRadius: 1,
                                            ),
                                          ] : [],
                                          gradient: isCurrentPiece || board[row][col] != 0 
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  cellColor.withOpacity(1.0),
                                                  cellColor.withOpacity(0.7),
                                                  cellColor.withOpacity(0.5),
                                                ],
                                              )
                                            : null,
                                        ),
                                        child: isClearing
                                          ? Container(
                                              color: Colors.white.withOpacity(_flashAnimation.value * 0.6),
                                            )
                                          : null,
                                      ),
                                    );
                                  },
                                );
                              },
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
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Next', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
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
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Score', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // 减小间距，特别是桌面端
                    const SizedBox(height: 20),
                    
                    // Game controls - only show on mobile devices (including mobile browsers)
                    if (MediaQuery.of(context).size.width < 600) Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!, width: 1),
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.grey[800],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Direction pad (经典十字方向键)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[700]!, width: 1),
                            ),
                            child: Column(
                              children: [
                                // 左右按钮
                                Row(
                                  children: [
                                    GestureDetector(
                                              onTapDown: (details) {
                                                // 立即移动一次
                                                moveLeft();
                                                // 开始快速左移
                                                _startLeftMove();
                                              },
                                              onTapUp: (details) {
                                                // 结束长按
                                                _stopLeftMove();
                                              },
                                              onTapCancel: () {
                                                // 结束长按
                                                _stopLeftMove();
                                              },
                                              child: Container(
                                                width: controlButtonSize,
                                                height: controlButtonSize,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[700],
                                                  border: Border.all(color: Colors.grey[500]!, width: 1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      offset: const Offset(2, 2),
                                                      blurRadius: 2,
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.white.withOpacity(0.1),
                                                      offset: const Offset(-1, -1),
                                                      blurRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                                child: const Center(child: Text('←', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTapDown: (details) {
                                                // 立即移动一次
                                                moveRight();
                                                // 开始快速右移
                                                _startRightMove();
                                              },
                                              onTapUp: (details) {
                                                // 结束长按
                                                _stopRightMove();
                                              },
                                              onTapCancel: () {
                                                // 结束长按
                                                _stopRightMove();
                                              },
                                              child: Container(
                                                width: controlButtonSize,
                                                height: controlButtonSize,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[700],
                                                  border: Border.all(color: Colors.grey[500]!, width: 1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      offset: const Offset(2, 2),
                                                      blurRadius: 2,
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.white.withOpacity(0.1),
                                                      offset: const Offset(-1, -1),
                                                      blurRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                                child: const Center(child: Text('→', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                                              ),
                                            ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // 向下按钮
                                GestureDetector(
                                          onTapDown: (details) {
                                            // 立即移动一次
                                            moveDown();
                                            // 开始快速下落
                                            _startFastDrop();
                                          },
                                          onTapUp: (details) {
                                            // 结束长按
                                            _stopFastDrop();
                                          },
                                          onTapCancel: () {
                                            // 结束长按
                                            _stopFastDrop();
                                          },
                                          child: Container(
                                            width: controlButtonSize * 2 + 8,
                                            height: controlButtonSize,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              border: Border.all(color: Colors.grey[500]!, width: 1),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  offset: const Offset(2, 2),
                                                  blurRadius: 2,
                                                ),
                                                BoxShadow(
                                                  color: Colors.white.withOpacity(0.1),
                                                  offset: const Offset(-1, -1),
                                                  blurRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: const Center(child: Text('↓', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                                          ),
                                        ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 40),
                          
                          // A button for rotate (圆形按钮)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[700]!, width: 1),
                            ),
                            child: GestureDetector(
                              onTap: rotate,
                              child: Container(
                                width: controlButtonSize * 1.6,
                                height: controlButtonSize * 1.6,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  border: Border.all(color: Colors.blue[300]!, width: 2),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      offset: const Offset(3, 3),
                                      blurRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      offset: const Offset(-2, -2),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(child: Text('A', style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Pause button
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[700]!, width: 1),
                            ),
                            child: GestureDetector(
                              onTap: togglePause,
                              child: Container(
                                width: controlButtonSize * 1.2,
                                height: controlButtonSize * 1.2,
                                decoration: BoxDecoration(
                                  color: gamePaused ? Colors.orange : Colors.grey[600],
                                  border: Border.all(color: gamePaused ? Colors.orange[300]! : Colors.grey[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      offset: const Offset(3, 3),
                                      blurRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: (gamePaused ? Colors.orange : Colors.grey[600])!.withOpacity(0.3),
                                      offset: const Offset(-2, -2),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(child: Text(gamePaused ? '▶' : '⏸', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                            ),
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
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Welcome to Tetris!', style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    MediaQuery.of(context).size.width >= 600 
                      ? const Text('Use WASD to control', style: TextStyle(fontSize: 18, color: Colors.white)) 
                      : const Text('Use on-screen buttons to control', style: TextStyle(fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: startGame,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                        textStyle: const TextStyle(fontSize: 24),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('Start Game'),
                    ),
                  ],
                ),
              ),
            ),
          
          // 暂停界面浮层
          if (gamePaused && gameStarted && !gameOver)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('游戏暂停', style: TextStyle(fontSize: 36, color: Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text('当前分数: $score', style: const TextStyle(fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text('速度等级: $speedLevel', style: const TextStyle(fontSize: 20, color: Colors.cyan)),
                    const SizedBox(height: 60),
                    ElevatedButton(
                      onPressed: togglePause,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                        textStyle: const TextStyle(fontSize: 20),
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('继续游戏'),
                    ),
                  ],
                ),
              ),
            ),
          
          // 游戏结束浮层
          if (gameOver) 
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Game Over!', style: TextStyle(fontSize: 36, color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text('Score: $score', style: const TextStyle(fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text('Best: $highScore', style: const TextStyle(fontSize: 20, color: Colors.yellow)),
                    const SizedBox(height: 60),
                    ElevatedButton(
                      onPressed: startGame,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                        textStyle: const TextStyle(fontSize: 20),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('重新开始'),
                    ),
                  ],
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
    super.dispose();
  }
}

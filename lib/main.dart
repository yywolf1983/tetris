import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

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
  late List<List<int>> board;
  late Tetromino currentPiece;
  late Tetromino nextPiece;
  late int score;
  bool gameOver = false;
  bool gameStarted = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  List<int> _clearingLines = [];
  late Timer _fastDropTimer;
  late Timer _leftMoveTimer;
  late Timer _rightMoveTimer;
  late double gameSpeed;
  late int speedLevel;

  @override
  void initState() {
    super.initState();
    board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    currentPiece = Tetromino.random();
    nextPiece = Tetromino.random();
    score = 0;
    gameSpeed = 500.0;
    speedLevel = 0;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(_controller);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _clearingLines.clear();
        });
      }
    });
    _fastDropTimer = Timer(Duration.zero, () {});
    _leftMoveTimer = Timer(Duration.zero, () {});
    _rightMoveTimer = Timer(Duration.zero, () {});
  }

  void startGameLoop() async {
    while (!gameOver) {
      await Future.delayed(Duration(milliseconds: gameSpeed.toInt()));
      if (!gameOver) {
        moveDown();
      }
    }
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
    startGameLoop();
  }

  void moveLeft() {
    if (!gameOver && gameStarted && !checkCollision(currentPiece.x - 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x--;
      });
    }
  }

  void moveRight() {
    if (!gameOver && gameStarted && !checkCollision(currentPiece.x + 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x++;
      });
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
      }
    }
  }

  void _startFastDrop() {
    // 开始快速下落，每50毫秒移动一次
    _fastDropTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
    // 开始快速左移，每50毫秒移动一次
    _leftMoveTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
    // 开始快速右移，每50毫秒移动一次
    _rightMoveTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
      _controller.forward(from: 0.0);
      
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
          
          // 更新分数
          score += linesCleared * 100;
          
          _clearingLines.clear();
          
          // 检查是否需要加速
          checkAndUpdateSpeed();
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double boardWidth = screenWidth * 0.6;
    double cellSize = boardWidth / cols;
    double boardHeight = cellSize * rows;
    double controlButtonSize = screenWidth * 0.18;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景渐变
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
          ),
          // 淡淡的毛玻璃效果
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          // 游戏内容
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    const Text('Tetris', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game board
                        SizedBox(
                          width: boardWidth,
                          height: boardHeight,
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
                              
                              Color cellColor;
                              if (isCurrentPiece) {
                                cellColor = getColor(currentPiece.color);
                              } else {
                                cellColor = board[row][col] == 0 ? Colors.grey[800]! : getColor(board[row][col]);
                              }
                              
                              bool isClearing = _clearingLines.contains(row);
                              
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
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Sidebar
                        const SizedBox(width: 10),
                        Container(
                          width: 120,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[600]!, width: 1),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[800],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
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
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!, width: 1),
                                ),
                                child: Text('$score', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Level', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!, width: 1),
                                ),
                                child: Text('$speedLevel', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Game controls
                    Container(
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
                    const SizedBox(height: 60),
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
          
          // 游戏结束浮层
          if (gameOver) 
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Game Over!', style: TextStyle(fontSize: 36, color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text('Score: $score', style: const TextStyle(fontSize: 24, color: Colors.white)),
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
    super.dispose();
  }
}

class Tetromino {
  int x;
  int y;
  List<List<int>> shape;
  int color;

  Tetromino(this.x, this.y, this.shape, this.color);

  static Tetromino random() {
    Random random = Random();
    int type = random.nextInt(7);
    List<List<int>> shape;
    int color;

    switch (type) {
      case 0: // I piece
        shape = [
          [0, 0, 0, 0],
          [1, 1, 1, 1],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 1;
        break;
      case 1: // O piece
        shape = [
          [0, 2, 2, 0],
          [0, 2, 2, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 2;
        break;
      case 2: // T piece
        shape = [
          [0, 3, 0, 0],
          [3, 3, 3, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 3;
        break;
      case 3: // S piece
        shape = [
          [0, 4, 4, 0],
          [4, 4, 0, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 4;
        break;
      case 4: // Z piece
        shape = [
          [5, 5, 0, 0],
          [0, 5, 5, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 5;
        break;
      case 5: // J piece
        shape = [
          [6, 0, 0, 0],
          [6, 6, 6, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 6;
        break;
      case 6: // L piece
        shape = [
          [0, 0, 7, 0],
          [7, 7, 7, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 7;
        break;
      default:
        shape = [
          [0, 0, 0, 0],
          [1, 1, 1, 1],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ];
        color = 1;
    }

    return Tetromino(3, 0, shape, color);
  }

  List<List<int>> rotate() {
    int n = shape.length;
    List<List<int>> rotated = List.generate(n, (_) => List.generate(n, (_) => 0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        rotated[j][n - 1 - i] = shape[i][j];
      }
    }
    return rotated;
  }
}

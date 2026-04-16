import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
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
  bool showWelcome = true;

  // Animation variables
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<int> _linesToClear = [];
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    currentPiece = Tetromino.random();
    nextPiece = Tetromino.random();
    score = 0;
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize animation
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Animation completed, clear the lines
          _clearLinesAfterAnimation();
        }
      });
    
    // Don't start game loop automatically, wait for user to click start
    // startGameLoop();
  }

  @override
  void dispose() {
    // Dispose animation controller
    _animationController.dispose();
    super.dispose();
  }

  void startGameLoop() async {
    while (!gameOver) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!gameOver && !_isAnimating) {
        moveDown();
      }
    }
  }

  void moveLeft() {
    if (!gameOver && !checkCollision(currentPiece.x - 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x--;
      });
    }
  }

  void moveRight() {
    if (!gameOver && !checkCollision(currentPiece.x + 1, currentPiece.y, currentPiece.shape)) {
      setState(() {
        currentPiece.x++;
      });
    }
  }

  void moveDown() {
    if (gameOver) return;
    
    if (!checkCollision(currentPiece.x, currentPiece.y + 1, currentPiece.shape)) {
      setState(() {
        currentPiece.y++;
      });
    } else {
      lockPiece();
      clearLines();
      // Use next piece as current piece
      currentPiece = nextPiece;
      // Generate new next piece
      nextPiece = Tetromino.random();
      // Check if game is over (piece is above the board)
      if (isGameOver()) {
        setState(() {
          gameOver = true;
          showWelcome = false;
        });
      }
    }
  }

  void rotate() {
    if (!gameOver) {
      List<List<int>> rotatedShape = currentPiece.rotate();
      if (!checkCollision(currentPiece.x, currentPiece.y, rotatedShape)) {
        setState(() {
          currentPiece.shape = rotatedShape;
        });
      }
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
          // Lock piece even if it's above the board
          if (newY >= 0 && newY < rows) {
            board[newY][newX] = currentPiece.color;
          }
        }
      }
    }
  }

  bool isGameOver() {
    // Check if any part of the current piece is above the board or collides with locked pieces
    for (int i = 0; i < currentPiece.shape.length; i++) {
      for (int j = 0; j < currentPiece.shape[i].length; j++) {
        if (currentPiece.shape[i][j] != 0) {
          int newY = currentPiece.y + i;
          int newX = currentPiece.x + j;
          if (newY < 0) {
            return true;
          }
          if (newY >= 0 && newY < rows && newX >= 0 && newX < cols) {
            if (board[newY][newX] != 0) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  void clearLines() {
    // Find lines to clear
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
    
    // If there are lines to clear, start animation
    if (linesToClear.isNotEmpty && !_isAnimating) {
      setState(() {
        _linesToClear = linesToClear;
        _isAnimating = true;
      });
      _animationController.forward(from: 0.0);
    }
  }

  void _clearLinesAfterAnimation() {
    // Sort lines in descending order to handle from bottom to top
    List<int> sortedLines = List.from(_linesToClear)..sort((a, b) => b.compareTo(a));
    
    // Clear the lines
    for (int row in sortedLines) {
      for (int r = row; r > 0; r--) {
        for (int col = 0; col < cols; col++) {
          board[r][col] = board[r - 1][col];
        }
      }
      for (int col = 0; col < cols; col++) {
        board[0][col] = 0;
      }
    }
    
    // Update score
    score += _linesToClear.length * 100;
    
    // Reset animation variables
    setState(() {
      _linesToClear = [];
      _isAnimating = false;
    });
  }

  void newGame() {
    setState(() {
      board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
      currentPiece = Tetromino.random();
      nextPiece = Tetromino.random();
      score = 0;
      gameOver = false;
      showWelcome = false;
    });
    startGameLoop();
  }

  Color getColor(int colorCode) {
    switch (colorCode) {
      case 1: return Colors.teal;        // I piece
      case 2: return Colors.amber;       // O piece
      case 3: return Colors.purple;      // T piece
      case 4: return Colors.lime;        // S piece
      case 5: return Colors.red;         // Z piece
      case 6: return Colors.indigo;      // J piece
      case 7: return Colors.orange;      // L piece
      default: return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate board size with aspect ratio consideration
    double boardWidth;
    double boardHeight;
    double cellSize;
    
    // Determine the maximum possible board width and height
    double maxBoardWidth = screenWidth * 0.6;
    double maxBoardHeight = screenHeight * 0.7;
    
    // Calculate cell size based on width
    double cellSizeByWidth = maxBoardWidth / cols;
    double boardHeightByWidth = cellSizeByWidth * rows;
    
    // Calculate cell size based on height
    double cellSizeByHeight = maxBoardHeight / rows;
    double boardWidthByHeight = cellSizeByHeight * cols;
    
    // Choose the smaller cell size to ensure board fits on screen
    if (boardHeightByWidth <= maxBoardHeight) {
      // Width-based calculation works
      cellSize = cellSizeByWidth;
      boardWidth = maxBoardWidth;
      boardHeight = boardHeightByWidth;
    } else {
      // Height-based calculation works better
      cellSize = cellSizeByHeight;
      boardWidth = boardWidthByHeight;
      boardHeight = maxBoardHeight;
    }

    // Calculate next piece preview size
    double nextPieceSize = boardWidth * 0.5;
    double nextPieceCellSize = nextPieceSize / 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tetris'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 20),
                  // Game board
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          Container(
                            width: boardWidth,
                            height: boardHeight,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                            ),
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
                                  cellColor = board[row][col] == 0 ? Colors.grey[100]! : getColor(board[row][col]);
                                }
                                
                                // Check if this row is being cleared
                                bool isClearing = _linesToClear.contains(row);
                                
                                return Transform.scale(
                                  scale: isClearing ? _animation.value : 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cellColor.withOpacity(1.0),
                                          cellColor.withOpacity(0.7),
                                        ],
                                      ),
                                      border: Border(
                                        top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1),
                                        left: BorderSide(color: Colors.white.withOpacity(0.8), width: 1),
                                        right: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                        bottom: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          spreadRadius: 0,
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Welcome screen overlay
                          if (showWelcome) ...[
                            Container(
                              width: boardWidth,
                              height: boardHeight,
                              color: Colors.black.withOpacity(0.7),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Tetris', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 40),
                                    const Text('Welcome to Tetris!', style: TextStyle(fontSize: 24, color: Colors.white)),
                                    const SizedBox(height: 20),
                                    const Text('Use W, A, S, D to control the pieces', style: TextStyle(fontSize: 18, color: Colors.white)),
                                    const SizedBox(height: 40),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          showWelcome = false;
                                        });
                                        startGameLoop();
                                      },
                                      child: const Text('Start Game', style: TextStyle(fontSize: 20)),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Game over screen overlay
                          if (gameOver) ...[
                            Container(
                              width: boardWidth,
                              height: boardHeight,
                              color: Colors.black.withOpacity(0.7),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Game Over!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 40),
                                    Text('Score: $score', style: const TextStyle(fontSize: 24, color: Colors.white)),
                                    const SizedBox(height: 40),
                                    ElevatedButton(
                                      onPressed: newGame,
                                      child: const Text('New Game', style: TextStyle(fontSize: 20)),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Mobile-friendly control layout with ergonomics in mind
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left side: Directional pad (D-pad) for left/right/down
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 3,
                                    blurRadius: 5,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Left and right buttons
                                  Row(
                                    children: [
                                      // Left button
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700]!,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            bottomLeft: Radius.circular(8),
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: moveLeft,
                                          child: const Text('←', style: TextStyle(color: Colors.white, fontSize: 18)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                bottomLeft: Radius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Right button
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin: const EdgeInsets.only(left: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700]!,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: moveRight,
                                          child: const Text('→', style: TextStyle(color: Colors.white, fontSize: 18)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.only(
                                                topRight: Radius.circular(8),
                                                bottomRight: Radius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Down button
                                  Container(
                                    width: 128, // 60*2 + 4*2
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700]!,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: moveDown,
                                      child: const Text('↓', style: TextStyle(color: Colors.white, fontSize: 18)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Right side: Action button (A button for rotate)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 3,
                                    blurRadius: 5,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // A button (rotate)
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(35),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          spreadRadius: 2,
                                          blurRadius: 3,
                                          offset: const Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: rotate,
                                      child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  // Sidebar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Score
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            Text('$score', style: TextStyle(fontSize: 24, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Next Piece
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Next Piece', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            const SizedBox(height: 10),
                            Container(
                              width: nextPieceSize,
                              height: nextPieceSize,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.grey[300]!, width: 0.5),
                              ),
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 1,
                                ),
                                itemCount: 16,
                                itemBuilder: (context, index) {
                                  int row = index ~/ 4;
                                  int col = index % 4;
                                  Color cellColor = Colors.grey[100]!;
                                  if (row < nextPiece.shape.length && col < nextPiece.shape[row].length) {
                                    if (nextPiece.shape[row][col] != 0) {
                                      cellColor = getColor(nextPiece.color);
                                    }
                                  }
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cellColor.withOpacity(1.0),
                                          cellColor.withOpacity(0.7),
                                        ],
                                      ),
                                      border: Border(
                                        top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1),
                                        left: BorderSide(color: Colors.white.withOpacity(0.8), width: 1),
                                        right: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                        bottom: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          spreadRadius: 0,
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Controls
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            const SizedBox(height: 10),
                            Text('W: Rotate', style: TextStyle(color: Colors.grey[700])),
                            Text('A: Move Left', style: TextStyle(color: Colors.grey[700])),
                            Text('S: Move Down', style: TextStyle(color: Colors.grey[700])),
                            Text('D: Move Right', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          [2, 2],
          [2, 2],
        ];
        color = 2;
        break;
      case 2: // T piece
        shape = [
          [0, 3, 0],
          [3, 3, 3],
          [0, 0, 0],
        ];
        color = 3;
        break;
      case 3: // S piece
        shape = [
          [0, 4, 4],
          [4, 4, 0],
          [0, 0, 0],
        ];
        color = 4;
        break;
      case 4: // Z piece
        shape = [
          [5, 5, 0],
          [0, 5, 5],
          [0, 0, 0],
        ];
        color = 5;
        break;
      case 5: // J piece
        shape = [
          [6, 0, 0],
          [6, 6, 6],
          [0, 0, 0],
        ];
        color = 6;
        break;
      case 6: // L piece
        shape = [
          [0, 0, 7],
          [7, 7, 7],
          [0, 0, 0],
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

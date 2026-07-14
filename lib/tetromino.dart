import 'dart:math';

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
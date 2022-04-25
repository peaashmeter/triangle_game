import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';

import 'dart:math';

void main() {
  runApp(const MaterialApp(
    home: GameWidget(),
  ));
}

class GameWidget extends StatefulWidget {
  const GameWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GameWidgetState();
}

class GameWidgetState extends State<GameWidget> {
  late Player player;
  late Stream ticker;
  late List<Object> enemies;
  late EnemyModel enemyModel;

  int tick = 0;

  Offset mousePos = const Offset(1, 0);

  @override
  void initState() {
    ticker = Stream.periodic(const Duration(milliseconds: 17));
    ticker.listen((event) {
      tick++;
      setState(() {});
    });

    enemyModel = EnemyModel(
      [],
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var center = Point(MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2);
    player = Player(center)..rotateToMouse(mousePos);

    if (tick % 60 == 0) {
      enemyModel.spawnEnemy(width, height);
    }
    enemyModel.moveEnemies(center);

    return Container(
      color: Colors.white,
      child: MouseRegion(
        onHover: (event) => mousePos = event.position,
        child: CustomPaint(
          painter: GamePainter(player, enemyModel),
        ),
      ),
    );
  }
}

extension Converter on Point {
  Offset get offset => Offset(x.toDouble(), y.toDouble());
}

class Player {
  final Point<double> centerPoint;

  late Point<double> _a;
  late Point<double> _b;
  late Point<double> _c;

  late List<Path> circlesPaths = [];

  Player(this.centerPoint) {
    _a = const Point(30, 0);
    _b = const Point(-25, -25);
    _c = const Point(-25, 25);
  }

  Path getPath() {
    var path = Path()
      ..moveTo(centerPoint.x + _a.x, centerPoint.y + _a.y)
      ..lineTo(centerPoint.x + _b.x, centerPoint.y + _b.y)
      ..lineTo(centerPoint.x + _c.x, centerPoint.y + _c.y)
      ..lineTo(centerPoint.x + _a.x, centerPoint.y + _a.y);
    path.close();
    return path;
  }

  void rotateToMouse(Offset mousePos) {
    var relativeMousePos = mousePos - centerPoint.offset;

    var cosPhi = relativeMousePos.dx / relativeMousePos.distance;

    var sinPhi = relativeMousePos.dy / relativeMousePos.distance;

    //ХВАТИТ СПАМИТЬ МНЕ В КОНСОЛЬ
    //print(relativeMousePos);

    _a = Point(_a.x * cosPhi - _a.y * sinPhi, _a.x * sinPhi + _a.y * cosPhi);
    _b = Point(_b.x * cosPhi - _b.y * sinPhi, _b.x * sinPhi + _b.y * cosPhi);
    _c = Point(_c.x * cosPhi - _c.y * sinPhi, _c.x * sinPhi + _c.y * cosPhi);

    circlesPaths = getAimCircles(cosPhi, sinPhi);
  }

  List<Path> getAimCircles(double cosPhi, double sinPhi) {
    List<Path> _circlesPaths = [];
    for (var i = 0; i < 10; i++) {
      Point<double> pos = Point(30 * cosPhi + (i + 1) * 30 * cosPhi,
          30 * sinPhi + (i + 1) * 30 * sinPhi);
      var path = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(centerPoint.x + pos.x, centerPoint.y + pos.y),
            radius: 5.0 - i * 0.5));

      _circlesPaths.add(path);
    }
    return _circlesPaths;
  }
}

///Противник, он выглядит как правильный многоугольник, у него есть местоположение и хп. И все.
class Enemy {
  final EnemyType type;
  late int hp;
  late Point<double> position;
  late double speed;

  Enemy(this.position,
      {this.type = EnemyType.square, this.hp = 100, this.speed = 10});

  Path getPath() {
    //TODO: сделать для разных типов фигур
    switch (type) {
      case EnemyType.square:
        const maxSize = 50;
        //Начальный размер 50 (100 хп)
        //Конечный размер 25 (0 хп)

        var size = maxSize - ((maxSize - hp) / 2);

        //От центральной точки половину вниз, вверх, влево, вправо to make a square
        var path = Path()
          ..addRect(Rect.fromCenter(
              center: position.offset, width: size, height: size));

        return path;

      default:
        throw Exception('Чел, ты...');
    }
  }

  void move(Point<double> center) {
    //вектор направления
    var vec = center - position;
    vec *= (1 / vec.magnitude);

    position += vec;
  }

  bool checkCollision(Point position) {
    //TODO: сделать для других фигур
    var size = 100 - ((100 - hp) / 2);
    var r = Rect.fromCenter(center: position.offset, width: size, height: size);

    return r.contains(position.offset);
  }
}

class EnemyModel {
  final List<Enemy> _enemies;
  UnmodifiableListView<Enemy> get enemies => UnmodifiableListView(_enemies);

  EnemyModel(this._enemies);

  void checkCollision(Point position) {
    List<Enemy> disposables = [];
    for (var e in _enemies) {
      if (e.checkCollision(position)) {
        disposables.add(e);
      }
    }
    _enemies.removeWhere((element) => disposables.contains(element));
  }

  void moveEnemies(Point<double> center) {
    for (var enemy in _enemies) {
      enemy.move(center);
    }
  }

  void spawnEnemy(double width, double height) {
    var side = Random().nextInt(4);
    switch (side) {
      case 0:
        _enemies.add(Enemy(Point(Random().nextDouble() * width, -100)));
        break;
      case 1:
        _enemies.add(Enemy(Point(width + 100, Random().nextDouble() * height)));
        break;
      case 2:
        _enemies.add(Enemy(Point(Random().nextDouble() * width, height + 100)));
        break;
      case 3:
        _enemies.add(Enemy(Point(-100, Random().nextDouble() * height)));
        break;
      default:
    }
  }
}

enum EnemyType { square, pentagon, hexagon }

class GamePainter extends CustomPainter {
  final Player player;
  final EnemyModel enemyModel;

  GamePainter(this.player, this.enemyModel);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var enemy in enemyModel.enemies) {
      canvas.drawPath(enemy.getPath(), paint);
    }

    canvas.drawPath(player.getPath(), paint);
    for (var i = 0; i < player.circlesPaths.length; i++) {
      var paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, 1 - 0.1 * i)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(player.circlesPaths[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

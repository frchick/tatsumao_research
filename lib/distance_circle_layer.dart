import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'; // Colors

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong2/latlong.dart';

class DistanceCircleLayerOptions extends LayerOptions
{
  DistanceCircleLayerOptions({
    Key? key,
    Stream<void>? rebuild,
  }) : super(key: key, rebuild: rebuild)
  {}
}

// flutter_map のプラグインとしてレイヤーを実装
class DistanceCircleLayerPlugin implements MapPlugin
{
  @override
  bool supportsLayer(LayerOptions options) {
    return options is DistanceCircleLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size, options as DistanceCircleLayerOptions, map, stream);
      },
    );
  }

  Widget _build(
    BuildContext context, Size size,
    DistanceCircleLayerOptions opts, MapState map, Stream<void> stream)
  {
    return StreamBuilder<void>(
      stream: stream, // a Stream<void> or null
      builder: (BuildContext context, _)
      {
        Widget painter = CustomPaint(
            painter: DistanceCirclePainter(),
            size: size,
            willChange: true);

        return painter;
      },
    );
  }
}

class DistanceCirclePainter extends CustomPainter
{
  DistanceCirclePainter();

  @override
  void paint(Canvas canvas, Size size)
  {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = Color(0x80000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final double r = size.shortestSide / 2;
    canvas.drawCircle(Offset(size.width/2, size.height/2), r, paint);
  }

  //NOTE: これが true を返さないと、StreamBuilder が走っても再描画されないことがある。
  @override
  bool shouldRepaint(DistanceCirclePainter oldDelegate)
  {
    return false;
  }
}

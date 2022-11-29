import 'dart:async';   // Stream使った再描画、Timer
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'mypolyline_layer.dart';

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// 手書き図の実装
late FreehandDrawing freehandDrawing;

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// 手書き図の実装
class FreehandDrawing
{
  FreehandDrawing({required MapController mapController}) :
    _mapController = mapController
  {}

  final MapController _mapController;

  // 図形のリスト
  List<Figure> _figures = [];

  // 最後の図形に、今引いているストロークを追加できるか
  bool _addStrokeToLastFigure = false;

  // 描画した図形のポリラインの集合
  List<MyPolyline> _polylines = [];
  // 描画した図形の再描画
  var _redrawPolylineStream = StreamController<void>.broadcast();

  // 今引いている最中のストローク
  List<MyPolyline> _currentStroke = [];
  List<LatLng>? _currnetStrokePoints;
  // 今引いている最中のストロークの再描画
  var _redrawStrokeStream = StreamController<void>.broadcast();

  // FlutterMap のレイヤー(描画した図形)
  MyPolylineLayerOptions getFiguresLayerOptions()
  {
    return MyPolylineLayerOptions(
      polylines: _polylines,
      rebuild: _redrawPolylineStream.stream);
  }

  // FlutterMap のレイヤー(今引いている最中のストローク)
  MyPolylineLayerOptions getCurrentStrokeLayerOptions()
  {
    return MyPolylineLayerOptions(
      polylines: _currentStroke,
      rebuild: _redrawStrokeStream.stream);
  }

  // ストローク開始
  void onStrokeStart(Offset pt)
  {
    if(_currnetStrokePoints == null){
      final point = _mapController.pointToLatLng(CustomPoint(pt.dx, pt.dy));
      _currnetStrokePoints = [ point! ];

      // 最後の図形にこのストロークを追加できるか？
      if(_figures.isNotEmpty){
        _addStrokeToLastFigure = _figures.last.tryAddNewStroke();
      }else{
        _addStrokeToLastFigure = false;
      }
    }
  }

  // ストロークの継続
  void onStrokeUpdate(Offset pt)
  {
    if(_currnetStrokePoints != null){
      final point = _mapController.pointToLatLng(CustomPoint(pt.dx, pt.dy));
      _currnetStrokePoints!.add(point!);

      var polyline = MyPolyline(
        points: _currnetStrokePoints!,
        color: Color.fromARGB(255, 0, 255, 0),
        strokeWidth: 4.0,
        shouldRepaint: true);
      
      if(_currentStroke.isEmpty) _currentStroke.add(polyline);
      else _currentStroke[0] = polyline;
      _redrawStrokeStream.sink.add(null);
    }
  }

  // ストロークの完了
  void onStrokeEnd()
  {
    if(_currnetStrokePoints != null){
      //!!!!
      print("The stroke has ${_currnetStrokePoints!.length} points.");
      var polyline = MyPolyline(
        points: _currnetStrokePoints!,
        color: Color.fromARGB(255, 0, 255, 0),
        strokeWidth: 4.0,
        shouldRepaint: true);
      _currnetStrokePoints = null;

      // 最後の図形に追加するか、新規図形を作成するか
      if(!_addStrokeToLastFigure){
        _figures.add(Figure());
      }
      _addStrokeToLastFigure = false;
      Figure figure = _figures.last;
      figure.addStroke(polyline);
      redraw();
    }
    _currentStroke.clear();
    _redrawStrokeStream.sink.add(null);
  }

  // 図形を削除
  void removeFigure(Figure figure)
  {
    _figures.remove(figure);
  }

  // 再描画
  void redraw()
  {
    // 現在有効な全ての図形のポリラインを集めて再描画
    _polylines.clear();
    _figures.forEach((var figure)
    {
      _polylines.addAll(figure.polylines);
    });
    _redrawPolylineStream.sink.add(null);
  }
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// 手書き図に含まれる、複数のストロークにより構成される、一塊の図形
class Figure
{
  // 状態
  FigureState _state = FigureState.Open;

  // この図形に含まれるストローク
  List<MyPolyline> _polylines = [];
  List<MyPolyline> get polylines => _polylines;

  // 一塊の図形として連続したストロークと判定する時間のタイマー
  Timer? _openTimer;
  // この図形を表示する期間のタイマー
  Timer? _showTimer;
  // フェードアウトアニメーションのタイマー
  Timer? _fadeAnimTimer;
  // フェードアウトの透明度(0 - 255)
  int _opacity = 0;

  // 一塊の図形として連続したストロークと判定する時間
  var _openDuration = const Duration(seconds: 1);
  // 図形を表示する時間
  var _showDuration = const Duration(seconds: 2);

  // 次のストロークを追加可能か試す。
  // 可能ならその状態へ。出来ないなら false を返す。
  bool tryAddNewStroke()
  {
    //!!!!
    print(">tryAddNewStroke(${_state.toString()})");

    // Open状態でなければ追加できない
    if(_state != FigureState.Open) return false;

    // タイマーを停止
    _openTimer?.cancel();
    _openTimer = null;
    // 状態を切り替え
    print(">FigureState.Open => FigureState.WaitStroke");
    _state = FigureState.WaitStroke;

    return true;
  }

  // ストロークを追加
  bool addStroke(MyPolyline polyline)
  {
    //!!!!
    print(">addStroke(${_state.toString()})");

    // 図形の新規作成(Open)か、連続したストロークの追加(WaitStroke)のみ
    final bool ok = (_state == FigureState.Open) ||
                    (_state == FigureState.WaitStroke);
    if(!ok) return false;

    // ストロークを追加
    _polylines.add(polyline);
    // 連続ストローク判定のタイマーを開始
    print(">${_state.toString()} => FigureState.Open");
    _state = FigureState.Open;
    _openTimer?.cancel();
    _openTimer = Timer(_openDuration, _onOpenTimer);

    return true;
  }

  // 連続ストローク判定のタイマーイベント
  void _onOpenTimer()
  {
    //!!!!
    print(">_onOpenTimer(${_state.toString()})");

    _openTimer = null;
    // 異常な状態遷移は無視
    if(_state != FigureState.Open) return;

    //!!!!
/*  _polylines.forEach((polyline){
      polyline.color = Color.fromARGB(255, 0, 0, 255);
    });
    freehandDrawing.redraw();
*/
    // この図形を表示する期間のタイマーを開始
    print(">FigureState.Open => FigureState.Close");
    _state = FigureState.Close;
    _showTimer?.cancel();
    _showTimer = Timer(_showDuration, _onShowTimer);
  }

  // 表示期間完了のタイマーイベント
  void _onShowTimer()
  {
    //!!!!
    print(">_onShowTimer(${_state.toString()})");

    _showTimer = null;
    // 異常な状態遷移は無視
    if(_state != FigureState.Close) return;

    // フェードアウトアニメーションを開始
    print(">FigureState.Close => FigureState.FadeOut");
    _state = FigureState.FadeOut;
    _fadeAnimTimer?.cancel();
    _fadeAnimTimer = Timer.periodic(Duration(milliseconds: 125), _onFadeAnimTimer);
    _opacity = 255;
  }

  // フェードアウトアニメーション
  void _onFadeAnimTimer(Timer timer)
  {
    //!!!!
    print(">_onShowTimer(${_state.toString()})");

    // 異常な状態遷移は無視
    if(_state != FigureState.FadeOut) return;
    // フェードアウト
    _opacity -= 32;
    if(0 < _opacity){
      // 透明度を変更
      _polylines.forEach((polyline){
        polyline.color = Color.fromARGB(_opacity, 0, 255, 0);
      });
    }else{
      // 完全透明になったら削除
      _fadeAnimTimer?.cancel();
      _fadeAnimTimer = null;
      freehandDrawing.removeFigure(this);
      //!!!!
      print(">Remove Figure!!!!");
    }
    // アニメーションのための再描画
    freehandDrawing.redraw();
  }
}

//-----------------------------------------------------------------------------
enum FigureState {
  Open,       // 次のストロークの追加可能な期間
  WaitStroke, // 次のストロークの完了を待っている
  Close,      // 次のストロークの追加は終了した期間(フェードアウトまでの待ち)
  FadeOut,    // フェードアウト中
}

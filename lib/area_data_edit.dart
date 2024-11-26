import 'dart:async';   // Stream使った再描画、Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'area_data.dart';

class AreaDataEdit
{
  // エリアを構成する頂点のマーカー
  List<Marker> _areaMarkers = [];
  List<bool> _areaMarkersFlag = [];
  List<Marker> _areaMarkersDispList = []; // 表示用

  // 選択されている頂点により構成されるエリアデータ
  List<Polygon> _areaPolygons = [];
  List<Polygon> _areaPolygonsDispList = []; // 表示用

  // マーカーの再描画
  final _redrawAreaMarkers = StreamController<void>.broadcast();
  void redraw() { _redrawAreaMarkers.sink.add(null); }

  // 機能の有効無効
  bool _active = true;
  bool get active => _active;
  set active(bool value)
  {
    if(_active != value){
      _active = value;
      // 非表示の場合は、表示用リストを空に。
      // 表示の場合は、元のリストから表示用リストにコピー。
      if(_active){
        _areaMarkersDispList.addAll(_areaMarkers);
        _areaPolygonsDispList.addAll(_areaPolygons);
      }else{
        _areaMarkersDispList.clear();
        _areaPolygonsDispList.clear();
      }
      redraw();
    }
  }

  // FlutterMap の MarkerLayerOptions (頂点)を作成
  MarkerLayerOptions getMarkerLayerOptions()
  {
    return MarkerLayerOptions(
      markers: _areaMarkersDispList,
      rebuild: _redrawAreaMarkers.stream,
    );
  }

  // FlutterMap の PolygonLayerOptions (頂点により構成されるエリア)を作成
  PolygonLayerOptions getPolygonLayerOptions()
  {
    return PolygonLayerOptions(
      polygons: _areaPolygonsDispList,
      rebuild: _redrawAreaMarkers.stream,
    );
  }

  // エリアを構成するマーカーを構築
  void buildMarkers(AreaData areaData, bool redraw_)
  {
    // 初回のみ、マーカーフラグの配列を作成
    var polygons = areaData.makePolygons();
    int num = 0;
    for(var p in polygons){
      num += p.points.length;
    }
    _areaMarkersFlag = List.filled(num, false);
  
    // マーカー配列を作成
    _areaMarkers.clear();
    _areaMarkersDispList.clear();
    for(var p in polygons){
      for(var c in p.points){
        var marker = _makeOneMarker(c, false);
        _areaMarkers.add(marker);
      }
    }
    _areaMarkersDispList.addAll(_areaMarkers);

    // ポリゴンをリセット
    _areaPolygons.clear();
    _areaPolygonsDispList.clear();

    // 再描画
    if(redraw_){
      redraw();
    }
  }

  // 選択されているマーカーからポリゴンを作成(再描画込み)
  void buildPolygons()
  {
    // 選択されている頂点からポリゴンを作成
    _areaPolygons.clear();
    _areaPolygonsDispList.clear();
    Polygon poly = Polygon(
      points: [],
      color: const Color.fromRGBO(0, 0, 255, 0.3),
      isFilled: true,
    );
    int index = 0;
    for(var v in _areaMarkers){
      if(_areaMarkersFlag[index++]){
        poly.points.add(v.point);
        print("        LatLng(${v.point.latitude}, ${v.point.longitude}),");
      }
    }
    if(3 <= poly.points.length){
      _areaPolygons.add(poly);
      _areaPolygonsDispList.addAll(_areaPolygons);
    }

    redraw();
  }

  // マーカーを一つ作成
  Marker _makeOneMarker(LatLng point, bool check)
  {
    var color = (check? Colors.blue: Colors.red);
    return Marker(
      width: 10,
      height: 10,
      point: point,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // 指定した座標のマーカーを検索
  int findMarker(LatLng point, MapController mapController)
  {
    // 機能が無効なら何もしない
    if(!_active){
      return -1;
    }

    // 指定座標をスクリーン座標に変換
    var p0 = mapController.latLngToScreenPoint(point);
    if(p0 == null){
      return -1;
    }

    // スクリーン座標で最も近いマーカーを検索
    double minDist = (10 * 10); // 10px以内で最も近いマーカー
    int minIndex = -1;
    for(int i = 0; i < _areaMarkers.length; i++){
      var p1 = mapController.latLngToScreenPoint(_areaMarkers[i].point);
      if(p1 != null){
        var dx = p1.x - p0.x;
        var dy = p1.y - p0.y;
        double len = (dx*dx + dy*dy).toDouble();
        if(len < minDist){
          minDist = len;
          minIndex = i;
        }
      }
    }

    if(0 <= minIndex){
      print("Marker[${minIndex}] : " + _areaMarkers[minIndex].point.toString());
    }

    return minIndex;
  }

  // マーカーをマーク(再描画込み)
  void checkMarker(int index)
  {
    if(0 <= index){
      _areaMarkersFlag[index] = !_areaMarkersFlag[index];
      var marker = _makeOneMarker(_areaMarkers[index].point, _areaMarkersFlag[index]);
      _areaMarkers[index] = marker;
      _areaMarkersDispList[index] = marker;
      redraw();
    }
  }

  // マーカーのマークを全てクリア(再描画込み)
  void clearAllMarkersCheck()
  {
    for(int i = 0; i < _areaMarkersFlag.length; i++){
      if(_areaMarkersFlag[i]){
        _areaMarkersFlag[i] = false;
        var marker = _makeOneMarker(_areaMarkers[i].point, false);
        _areaMarkers[i] = marker;
        _areaMarkersDispList[i] = marker;
      }
    }
    _areaPolygons.clear();
    _areaPolygonsDispList.clear();
    redraw();
  }
}

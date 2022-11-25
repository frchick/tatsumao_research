//import 'dart:io'; // HttpClient
import 'dart:async';   // Stream使った再描画
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';

import 'mypolyline_layer.dart';

void main()
{
  runApp(const MyApp());
}

class MyApp extends StatelessWidget
{
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'TatsumaO Research',
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget
{
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
{
  // これまでに書いたライン
  List<Polyline> _polylines = [];
  var _redrawPolylineStream = StreamController<void>.broadcast();

  // 今引いている最中のライン(ストローク)
  List<MyPolyline> _currentStroke = [];
  List<LatLng>? _currnetStrokePoints;
  var _redrawStrokeStream = StreamController<void>.broadcast();

  var _mapController = MapController();

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TatsumaO Research"),
      ),
      body: Stack(
        children: [
          // 地図
          Center(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                allowPanningOnScrollingParent: false,
                interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                center: LatLng(35.309934, 139.076056),  // 丸太の森P
                zoom: 16,
                maxZoom: 18,
                onTap: onTap,
                plugins: [
                  MyPolylineLayerPlugin(),
                ],
              ),
              nonRotatedLayers: [
                // 高さ陰影図
                TileLayerOptions(
                  urlTemplate: "https://cyberjapandata.gsi.go.jp/xyz/hillshademap/{z}/{x}/{y}.png",
                  tileProvider: MyTileProvider(headers: {'User-Agent': 'flutter_map (unknown)'}),
                  maxNativeZoom: 16,
                ),
                // 標準地図
                TileLayerOptions(
                  urlTemplate: "https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png",
                  opacity: 0.64
                ),
                // 手書き
                PolylineLayerOptions(
                  polylines: _polylines,
                  rebuild: _redrawPolylineStream.stream,
                ),
                // 手書きの今引いている最中のライン
                MyPolylineLayerOptions(
                  polylines: _currentStroke,
                  rebuild: _redrawStrokeStream.stream,
                ),
              ],
            ),
          ),
          // 手書き
          Container(
            child: GestureDetector(
              onPanStart: (details)
              {
                if(_currnetStrokePoints == null){
                  final pt = details.localPosition;
                  final point = _mapController.pointToLatLng(CustomPoint(pt.dx, pt.dy));
                  _currnetStrokePoints = [ point! ];
                }
              },
              onPanUpdate: (details)
              {
                if(_currnetStrokePoints != null){
                  final pt = details.localPosition;
                  final point = _mapController.pointToLatLng(CustomPoint(pt.dx, pt.dy));
                  _currnetStrokePoints!.add(point!);

                  var polyline = MyPolyline(
                    points: _currnetStrokePoints!,
                    color: Color(0xFFFF0000),
                    strokeWidth: 4.0,
                    shouldRepaint: true);
                  
                  if(_currentStroke.isEmpty) _currentStroke.add(polyline);
                  else _currentStroke[0] = polyline;
                  _redrawStrokeStream.sink.add(null);
                }
              },
              onPanEnd: (details)
              {
                if(_currnetStrokePoints != null){
                  //!!!!
                  print("The stroke has ${_currnetStrokePoints!.length} points.");
                  var polyline = Polyline(
                    points: _currnetStrokePoints!,
                    color: Color(0xFF00FF00),
                    strokeWidth: 4.0);
                  _polylines.add(polyline);
                  _redrawPolylineStream.sink.add(null);

                  _currnetStrokePoints = null;
                }
                _currentStroke.clear();
                _redrawStrokeStream.sink.add(null);
              },
            ),
          ),
        ],
      ),
    );
  }

  void onTap(TapPosition tapPosition, LatLng point)
  {
    print("onTap() !!!!");
  }
}

// NetworkNoRetryTileProvider のカスタム(WEB専用)
class MyTileProvider extends TileProvider {
  MyTileProvider({
    Map<String, String>? headers,
  }) {
    this.headers = headers ?? {};
  }

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options)
  {
    // options.zoomReverse, options.zoomOffset は使わない前提で無視
    var zoom = coords.z.round();
    var x = coords.x.round();
    var y = coords.y.round();

    if((zoom == 16) && (x == 58085) && ((25888 <= y) && (y <= 25890))){
      String path = "map_tiles/xyz/hillshademap/${zoom}/${x}_${y}.png";
      print("path=${path} ****");
      return AssetImage(path);
    }

    final String url = getTileUrl(coords, options);
    print("url=${url}");
    return NetworkImage(
      url,
      headers: headers..remove('User-Agent'),
    );
  }
}

/* NetworkNoRetryTileProvider のカスタム(WEB以外)
class MyTileProvider extends TileProvider
{
  MyTileProvider({
    Map<String, String>? headers,
    HttpClient? httpClient,
  }) {
    this.headers = headers ?? {};
    this.httpClient = httpClient ?? HttpClient()
      ..userAgent = null;
  }

  late final HttpClient httpClient;

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) =>
      FMNetworkNoRetryImageProvider(
        getTileUrl(coords, options),
        headers: headers,
        httpClient: httpClient,
      );
}
*/

//import 'dart:io'; // HttpClient
import 'dart:async';   // Stream使った再描画、Timer
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';
import 'package:flutter/gestures.dart';  // DragStartBehavior

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

import 'mypolyline_layer.dart';
import 'freehand_drawing.dart';

void main() async
{
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

//-----------------------------------------------------------------------------
class MyHomePage extends StatefulWidget
{
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
{
  late MapController _mapController = MapController();

  @override
  void initState()
  {
    // このアプリケーションインスタンスを一意に識別するキー
    final String appInstKey = UniqueKey().toString();

    _mapController = MapController();
    freehandDrawing = FreehandDrawing(
      mapController:_mapController,
      appInstKey: appInstKey);

    //!!!! テスト
//    testRealtimeDatabase();
  }

  void testRealtimeDatabase() async
  {
    var database = FirebaseDatabase.instance;
    final String dbPath = "freehand_drawing/figure";
    final DatabaseReference ref = database.ref(dbPath);
    List<DatabaseReference> pushs = [];
    for(int i = 0; i < 4; i++){
      final DatabaseReference r = ref.push();
      var data = {
        "stroke": i,
        "color": 1234,
        "time": 5678,
      };
      r.set(data);
      
      pushs.add(r);
      print("${r.key}");
    }
    var listen0 = ref.onChildAdded.listen((event){
      print("onChildAdded > key:${event.snapshot.key} value:${event.snapshot.value}");
    });
    var listen1 = ref.onChildChanged.listen((event){
      print("onChildChanged > key:${event.snapshot.key} value:${event.snapshot.value}");
    });
    var listen2 = ref.onChildRemoved.listen((event){
      print("onChildRemoved > key:${event.snapshot.key} value:${event.snapshot.value}");
    });

    await new Future.delayed(new Duration(seconds: 2));
    {
      final DatabaseReference r = ref.push();
      var data = {
        "stroke": 4,
        "color": 1234,
        "time": 5678,
      };
      r.set(data);
      
      pushs.add(r);
      print("${r.key}");
    }

    await new Future.delayed(new Duration(seconds: 2));
    pushs[0].update({
      "color": 0,
    });

    await new Future.delayed(new Duration(seconds: 2));
    pushs[1].remove();

    await new Future.delayed(new Duration(seconds: 2));
    listen0.cancel();
    listen1.cancel();
    listen2.cancel();
  }

  @override
  Widget build(BuildContext context)
  {
    //!!!!
    print(">MyHomePage.build() !!!!");

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
                // 手書き図形レイヤー
                freehandDrawing.getFiguresLayerOptions(),
                // 手書きの今引いている最中のライン
                freehandDrawing.getCurrentStrokeLayerOptions(),
              ],
            ),
          ),

          // 手書き図
          FreehandDrawingOnMap(),
        ],
      ),
    );
  }
}

//-----------------------------------------------------------------------------
class FreehandDrawingOnMap extends StatefulWidget
{
  const FreehandDrawingOnMap({super.key});

  @override
  State<FreehandDrawingOnMap> createState() => _FreehandDrawingOnMapState();
}

class _FreehandDrawingOnMapState extends State<FreehandDrawingOnMap>
{
  // 手書き有効/無効スイッチ
  bool _freehandDrawingActive = false;

  @override
  void initState()
  {
  }

  @override
  Widget build(BuildContext context)
  {
    //!!!!
    print(">FreehandDrawingOnMap.build() !!!!");

    return Stack(
      children: [
        // 手書き有効/無効ボタン
        Align(
          // 画面右下に配置
          alignment: const Alignment(1.0, 1.0),
          child: ElevatedButton(
            child: const Icon(Icons.border_color, size: 55),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.orange.shade900,
              backgroundColor: _freehandDrawingActive? Colors.white: Colors.transparent,
              shadowColor: Colors.transparent,
              fixedSize: const Size(80,80),
              padding: const EdgeInsets.fromLTRB(0,0,0,20),
              shape: const CircleBorder(),
            ),
            onPressed: ()
            {
              // この setState() は FreehandDrawingOnMap の範囲のみ build を実行
              // FlutterMap 含む MyHomePage は build されない
              setState((){ _freehandDrawingActive = !_freehandDrawingActive; });
            },
          ),
        ),

        // 手書きジェスチャー
        if(_freehandDrawingActive) GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details)
          {
          freehandDrawing.onStrokeStart(details.localPosition);
          },
          onPanUpdate: (details)
          {
            freehandDrawing.onStrokeUpdate(details.localPosition);
          },
          onPanEnd: (details)
          {
            freehandDrawing.onStrokeEnd();
          }
        ),
      ],
    );
  }
}

//-----------------------------------------------------------------------------
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

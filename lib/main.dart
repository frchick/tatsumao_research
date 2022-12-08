//import 'dart:io'; // HttpClient
import 'dart:async';   // Stream使った再描画、Timer
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';

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
  final _mapController = MapController();

  // 手書き図へのアクセスキー
  final _freehandDrawingOnMapKey = GlobalKey<FreehandDrawingOnMapState>();

  @override
  void initState()
  {
    freehandDrawing = FreehandDrawing(
      mapController:_mapController);
    freehandDrawing.open("/1");

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

          Align(
            alignment: const Alignment(-1.0, -1.0),
            child: OnOffSwitch(onChangeSwitch: (value){
              _freehandDrawingOnMapKey.currentState?.setEditLock(value);
            }),
          ),

          // ファイル切り替え相当
          Align(
            alignment: const Alignment(1.0, 1.0),
            child: TextButton(
              child: const Icon(Icons.refresh, size: 50),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                shadowColor: Colors.transparent,
                fixedSize: const Size(80,80),
                padding: const EdgeInsets.fromLTRB(0,0,0,10),
                shape: const CircleBorder(),
              ),
              // 有効/無効切り替え
              onPressed: () {
                freehandDrawing.close();
                freehandDrawing.redraw();
                _freehandDrawingOnMapKey.currentState?.disableDrawing();
                freehandDrawing.open("/1");
              }
            ),
          ),

          // 手書き図
          FreehandDrawingOnMap(key: _freehandDrawingOnMapKey),
        ],
      ),
    );
  }
}

//-----------------------------------------------------------------------------
class OnOffSwitch extends StatefulWidget
{
  OnOffSwitch({ super.key, required this.onChangeSwitch });

  late Function onChangeSwitch;

  @override
  State<OnOffSwitch> createState() => _OnOffSwitchState();
}

class _OnOffSwitchState extends State<OnOffSwitch>
{
  bool _on = false;

  @override
  Widget build(BuildContext context)
  {
    return Switch(
      value: _on,
      onChanged: (bool? value) {
        widget.onChangeSwitch(value);
        setState(() { _on = value!; });
      },
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
      String path = "assets/map_tiles/xyz/hillshademap/${zoom}/${x}_${y}.png";
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

//import 'dart:io'; // HttpClient
import 'dart:async';   // Stream使った再描画、Timer
import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_dragmarker/dragmarker.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';


import 'mypolyline_layer.dart';
import 'freehand_drawing.dart';
import 'distance_circle_layer.dart';
import 'area_data.dart';
import 'area_data_edit.dart';
import 'area_filter_dialog.dart';
import 'myfs_image.dart';

import 'package:location/location.dart';

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

  // エリアデータの編集機能
  AreaDataEdit _areaDataEditor = new AreaDataEdit();

  // メンバーアイコンの読み込み中に表示するアイコン
  final Image _loadingIcon = Image.asset('assets/member_icon/loading.png', width:64, height:72);

  // メンバーアイコンを一意に識別するためのキー
  // これを使わないと、マーカーが画面外に出たときに、マーカーと画像の対応がズレる。
  List<Key> _keyList = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  // GPS位置情報へのアクセス
  Location _location = Location();
  // GPS位置情報を表示するか
  bool _showGPSLocation = false;

  @override
  void initState()
  {
    freehandDrawing = FreehandDrawing(
      mapController:_mapController);
    freehandDrawing.open("/1");

    // エリアを構成するマーカーを構築
    _areaDataEditor.buildMarkers(areaData, false);

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
    var listen0 = ref.onChildAdded.listen((DatabaseEvent event){
      DataSnapshot snapshot = event.snapshot;
      print("onChildAdded > key:${event.snapshot.key} value:${snapshot.value}");
    });
    var listen1 = ref.onChildChanged.listen((DatabaseEvent event){
      DataSnapshot snapshot = event.snapshot;
      print("onChildChanged > key:${event.snapshot.key} value:${snapshot.value}");
    });
    var listen2 = ref.onChildRemoved.listen((DatabaseEvent event){
      DataSnapshot snapshot = event.snapshot;
      print("onChildRemoved > key:${event.snapshot.key} value:${snapshot.value}");
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

  // UIの再描画
  var _updateUIStream = StreamController<void>.broadcast();

  void updateUI()
  {
    _updateUIStream.sink.add(null);
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
                  DistanceCircleLayerPlugin(),
                  DragMarkerPlugin(),
                ],
                // タップした位置のマーカーを検索
                onTap: (tapPosition, point){
                  int i = _areaDataEditor.findMarker(point, _mapController);
                  if(0 <= i){
                    _areaDataEditor.checkMarker(i);
                  }
                },
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
                // ポリゴン(禁猟区)
                PolygonLayerOptions(
                  polygons: areaData.makePolygons(),
                  polygonCulling: true,
                ),
                // ポリゴン編集機能
                _areaDataEditor.getMarkerLayerOptions(),
                _areaDataEditor.getPolygonLayerOptions(),
                // 手書き図形レイヤー
                freehandDrawing.getFiguresLayerOptions(),
                // 手書きの今引いている最中のライン
                freehandDrawing.getCurrentStrokeLayerOptions(),
                // 距離サークル
                DistanceCircleLayerOptions(mapController: _mapController),
                // ドラッグ可能マーカー
                DragMarkerPluginOptions(
                  markers: [
                    DragMarker(
                      point: LatLng(35.309945, 139.0760),
                      width: 64.0,
                      height: 72.0,
                      builder: (ctx) =>
                        MyFSImage('assets/member_icon/000.png', loadingIcon:_loadingIcon, key:_keyList[0]),
                      rotateMarker: false,
                    ),
                    DragMarker(
                      point: LatLng(35.309945, 139.0770),
                      width: 64.0,
                      height: 72.0,
                      builder: (ctx) =>
                        MyFSImage('assets/member_icon/001.png', loadingIcon:_loadingIcon, key:_keyList[1]),
                      rotateMarker: false,
                    ),
                    DragMarker(
                      point: LatLng(35.309945, 139.0780),
                      width: 64.0,
                      height: 72.0,
                      builder: (ctx) =>
                        MyFSImage('assets/member_icon/002.png', loadingIcon:_loadingIcon, key:_keyList[2]),
                      rotateMarker: false,
                    ),
                    DragMarker(
                      point: LatLng(35.309945, 139.0790),
                      width: 64.0,
                      height: 72.0,
                      builder: (ctx) =>
                        MyFSImage('assets/member_icon/003.png', loadingIcon:_loadingIcon, key:_keyList[3]),
                      rotateMarker: false,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 画面左上のUI群
          Align(
            alignment: const Alignment(-1.0, -1.0),
            child: StreamBuilder<void>(
              stream: _updateUIStream.stream,
              builder: ((context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 手書き図形の編集ロック
                    OnOffSwitch(
                      onChangeSwitch: (value) {
                        _freehandDrawingOnMapKey.currentState?.setEditLock(value);
                      }
                    ),
                    
                    // エリア編集機能の有効無効
                    ElevatedButton(
                      onPressed: () {
                        _areaDataEditor.active = !_areaDataEditor.active;
                        updateUI();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _areaDataEditor.active? Colors.blue: Colors.grey,
                        minimumSize: const Size(130, 40),
                      ),
                      child: const Text('Area Editor'),
                    ),
                    SizedBox(height: 4),

                    // エリア編集機能の、マーカーのチェッククリア
                    ElevatedButton(
                      onPressed: !_areaDataEditor.active? null: () {
                        _areaDataEditor.clearAllMarkersCheck();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(130, 40),
                      ),
                      child: const Text('Clear Checks'),
                    ),
                    SizedBox(height: 4),

                    // エリア編集機能の、ポリゴン更新
                    ElevatedButton(
                      onPressed: !_areaDataEditor.active? null: () {
                        _areaDataEditor.buildPolygons();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(130, 40),
                      ),
                      child: const Text('Update Area'),
                    ),
                    SizedBox(height: 8),

                    // ダイアログテスト
                    ElevatedButton(
                      onPressed: () {
                        showTestDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(130, 40),
                      ),
                      child: const Text('Dialog Test'),
                    ),

                    SizedBox(height: 8),

                    // GPSテスト
                    ElevatedButton(
                      onPressed: () {
                        GpeTest(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(130, 40),
                      ),
                      child: const Text('GPS Test'),
                    ),
                    if(_showGPSLocation) const SizedBox(height: 4),
                    if(_showGPSLocation) GPSText(location: _location),
                  ],
                );
              }),
            ),
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

  // ダイアログテスト
  void showTestDialog(BuildContext context)
  {
    showAreaFilterDialog(context);
  }

  Future<bool> GpeTest(BuildContext context) async
  {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('>GPSサービスが無効です');
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text("GPSサービスが無効です"),
            );
          },
        );
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print('>GPSのパーミッションが無効です');
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text("GPSのパーミッションが無効です"),
            );
          },
        );
        return false;
      }
    }

    // 再描画
    setState((){
      _showGPSLocation = !_showGPSLocation;
    });

    return true;
  }
}

//-----------------------------------------------------------------------------
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

//-----------------------------------------------------------------------------
// GPSテスト
class GPSText extends StatefulWidget
{
  GPSText({
    required this.location,
    super.key });

  final Location location;

  @override
  State<GPSText> createState() => _GPSTextState();
}

class _GPSTextState extends State<GPSText>
{
  String _text =  "Waiting...";
  StreamSubscription<LocationData>? _locationSubscription = null;

  @override
  void initState()
  {
    super.initState();

    // GPS位置情報が変化したら、テキストを更新
    _locationSubscription = widget.location.onLocationChanged.listen((LocationData locationData) {
      print(">location.onLocationChanged()");
      setState(() {
        _text = "$locationData";
      });
    });
  }

  @override
  void dispose()
  {
    // GPS位置情報の監視を解除
    _locationSubscription?.cancel();
    _locationSubscription = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return Text(_text);
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

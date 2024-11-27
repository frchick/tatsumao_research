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
import 'distance_circle_layer.dart';
import 'area_data.dart';
import 'area_data_edit.dart';

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

  // 猟場のエリア名
  // NOTE: 設定ボタン表示の都合で、4の倍数個で定義
  // NOTE: TatsumaData.areaBits のビットと対応しているので、後から順番を変えられない。
  final List<String> _areaNames = [
    "暗闇沢", "ホンダメ", "苅野", "笹原林道",
    "桧山", "858", "金太郎L", "最乗寺",
    "裏山(静)", "中尾沢", "", "(未設定)",
  ];

  // ダイアログテスト
  void showTestDialog(BuildContext context)
  {
    // 表示エリアのスタイル
    final visibleBoxDec = BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.orange, width:2),
      color: Colors.orange[200],
    );
    final visibleTexStyle = const TextStyle(color: Colors.white);

    // 非表示エリアのスタイル
    final hideBoxDec = BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.grey, width:2),
    );
    final hideTexStyle = const TextStyle(color: Colors.grey);

    // エリア一覧のスクロールバーを、常に表示するためのおまじない
    final _scrollController = ScrollController();

    // エリアごとのリスト項目を作成
    List<Container> areas = [];
    for(int i = 0; i < _areaNames.length; i++){
      final int maskBit = (1 << i);
      final bool visible = false;

      areas.add(Container(
        height: 42,
      
        child: ListTile(
          // (左側)表示/非表示アイコン
          leading: (visible? const Icon(Icons.visibility): const Icon(Icons.visibility_off)),

          // エリア名タグ
          // 表示/非表示で枠を変える
          title: Row( // このRow入れないと、タグのサイズが横いっぱいになってしまう。
            children: [
              Container(
                child: Text(
                  _areaNames[i],
                  style: (visible? visibleTexStyle: hideTexStyle),
                ),
                decoration: (visible? visibleBoxDec: hideBoxDec),
                padding: const EdgeInsets.symmetric(vertical:2, horizontal:10),
              ),
            ]
          ),
          // タップで
          onTap: (){
          },
        ),
      ));
    };

    // 画面サイズに合わせたダイアログの高さを計算
    // (Flutter のレイアウトによる高さ調整がうまくいかないので…)
    var screenSize = MediaQuery.of(context).size;
    double dialogHeight = 6 + 157 + (areas.length * 42) + 6;
    double dialogWidth = 200;
  
    // 横長画面の場合には、ダイアログを左側に寄せる
    AlignmentGeometry dialogAlignment = 
      (screenSize.height < screenSize.width)? Alignment.topLeft: Alignment.center;
  
    // ダイアログ表示
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          alignment: dialogAlignment,
          insetPadding: EdgeInsets.symmetric(horizontal:20, vertical:20),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            padding: EdgeInsets.symmetric(horizontal:0, vertical:6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダ部分
                Container(
                  padding: EdgeInsets.symmetric(horizontal:12, vertical:0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [1段目]タイトル
                      Text("表示/非表示設定",
                        style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 10),
                      
                      // [2段目]メンバーマーカーサイズ/非表示、GPSログ＆距離サークル表示/非表示スイッチ
                      Row(
                        children: [
                          // メンバーマーカーサイズ/非表示スイッチ
                          ToggleButtons(
                            children: [
                              const Icon(Icons.location_pin, size:30),
                              const Icon(Icons.location_pin, size:22),
                              const Icon(Icons.location_off, size:22),
                            ],
                            isSelected: [ true, false, false],
                            onPressed: (index) {
                            },
                          ),
                          const SizedBox(width:5, height:30),
                          // GPSログ表示/非表示スイッチ
                          ToggleButtons(
                            children: [
                              const Icon(Icons.timeline, size:30),
                            ],
                            isSelected: [ false ],
                            onPressed: (index) {
                            },
                          ),
                          // 距離サークル表示/非表示スイッチ
                          ToggleButtons(
                            children: [
                              const Icon(Icons.radar, size:30),
                            ],
                            isSelected: [ false ],
                            onPressed: (index) {
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 8),

                      // [3段目]一括表示/非表示スイッチ、グレー表示スイッチ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // (左寄せ)一括表示/非表示スイッチ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // 一括表示
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed:() {
                                },
                              ),
                              // 一括非表示
                              IconButton(
                                icon: const Icon(Icons.visibility_off),
                                onPressed:() {
                                },
                              ),
                            ],
                          ),
                          // (右寄せ)グレー表示スイッチ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text("グレー表示", style: Theme.of(context).textTheme.titleMedium),
                              Switch(
                                value: false,
                                onChanged:(r){
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // エリア一覧(スクロール可能)
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: areas,
                      )
                    )
                  )
                )
              ],
            ),
          ),
        );
      },
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

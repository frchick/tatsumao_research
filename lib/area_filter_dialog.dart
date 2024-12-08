import 'package:flutter/material.dart';
import 'mybasic_dialog.dart';

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
// エリア表示フィルターダイアログ

// 猟場のエリア名
// NOTE: 設定ボタン表示の都合で、4の倍数個で定義
// NOTE: TatsumaData.areaBits のビットと対応しているので、後から順番を変えられない。
const List<String> _areaNames = [
  "暗闇沢", "ホンダメ", "苅野", "笹原林道",
  "桧山", "858", "金太郎L", "最乗寺",
  "裏山(静)", "中尾沢", "", "(未設定)",
];
final int _areaFullBits = (1 << _areaNames.length) - 1;

// エリアフィルターのフラグ
int areaFilterBits = 0x000f;  // テスト用の適当な初期値

class AreaFilterDialog extends StatefulWidget
{
  @override
  AreaFilterDialogState createState() => AreaFilterDialogState();
}

class AreaFilterDialogState extends State<AreaFilterDialog>
{
  @override
  Widget build(BuildContext context)
  {
    // 表示エリアのスタイル
    final visibleBoxDec = BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.orange, width:2),
      color: Colors.orange[200],
    );
    var visibleTexStyle = const TextStyle(color: Colors.white);

    // 非表示エリアのスタイル
    final hideBoxDec = BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.grey, width:2),
    );
    var hideTexStyle = const TextStyle(color: Colors.grey);

    // エリア一覧のスクロールバーを、常に表示するためのおまじない
    final scrollController = ScrollController();

    // エリアごとのリスト項目を作成
    List<Container> areas = [];
    for(int i = 0; i < _areaNames.length; i++){
      final int maskBit = (1 << i);
      final bool visible = (areaFilterBits & maskBit) != 0;

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
                decoration: (visible? visibleBoxDec: hideBoxDec),
                padding: const EdgeInsets.symmetric(vertical:2, horizontal:10),
                child: Text(
                  _areaNames[i],
                  style: (visible? visibleTexStyle: hideTexStyle),
                ),
              ),
            ]
          ),
          // タップでエリアの表示/非表示を反転
          onTap: (){
            setState((){
              areaFilterBits = (areaFilterBits ^ maskBit);
            });
          },
        ),
      ));
    };

    // Widget Tree
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダ部分
        Container(
          padding: const EdgeInsets.symmetric(horizontal:12, vertical:0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [1段目]タイトル
              Text("表示/非表示設定",
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              
              // [2段目]メンバーマーカーサイズ/非表示、GPSログ＆距離サークル表示/非表示スイッチ
              Row(
                children: [
                  // メンバーマーカーサイズ/非表示スイッチ
                  ToggleButtons(
                    isSelected: [ true, false, false ],
                    onPressed: (index) {
                    },
                    children: const [
                      Icon(Icons.location_pin, size:30),
                      Icon(Icons.location_pin, size:22),
                      Icon(Icons.location_off, size:22),
                    ],
                  ),
                  const SizedBox(width:5, height:30),
                  // GPSログ表示/非表示スイッチ
                  ToggleButtons(
                    isSelected: [ false ],
                    onPressed: (index) {
                    },
                    children: const [
                      Icon(Icons.timeline, size:30),
                    ],
                  ),
                  // 距離サークル表示/非表示スイッチ
                  ToggleButtons(
                    isSelected: [ false ],
                    onPressed: (index) {
                    },
                    children: const [
                      Icon(Icons.radar, size:30),
                    ],
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
                      IconButton(
                        icon: Icon((areaFilterBits == 0)? Icons.visibility : Icons.visibility_off),
                        onPressed:() {
                          setState((){
                            if(areaFilterBits == 0){
                              areaFilterBits = _areaFullBits;
                            }else{
                              areaFilterBits = 0;
                            }
                          });
                        },
                      ),
                      Text("一括", style: Theme.of(context).textTheme.titleMedium),
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
              const SizedBox(height: 10),
            ],
          ),
        ),

        // エリア一覧(スクロール可能)
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            controller: scrollController,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: areas,
              )
            )
          )
        )
      ],
    );
  }
}

// ダイアログを開く
Future<bool?> showAreaFilterDialog(BuildContext context)
{
  // 表示前のエリアフィルターのフラグ(変更の有無を確認する用)
  final int areaFilterBits0 = areaFilterBits;

  // 画面サイズに合わせたダイアログの高さを計算
  // (Flutter のレイアウトによる高さ調整がうまくいかないので…)
  var screenSize = MediaQuery.of(context).size;
  double dialogHeight = 6 + 147 + (_areaNames.length * 42) + 6;
  double dialogWidth = 200;

  // 横長画面の場合には、ダイアログを左側に寄せる
  AlignmentGeometry dialogAlignment = 
    (screenSize.height < screenSize.width)? Alignment.topLeft: Alignment.center;
    
  // ダイアログ表示
  return showMyBasicDialog<bool>(
    context: context,
    width: dialogWidth,
    height: dialogHeight,
    alignment: dialogAlignment,
    margin: const EdgeInsets.symmetric(horizontal:20, vertical:20),
    padding: const EdgeInsets.symmetric(horizontal:0, vertical:6),
    onClose: () {
      // ダイアログの終了時、変更の有無を確認して戻す
      final bool changeFilter = (areaFilterBits0 != areaFilterBits); 
      print("WillPopScope.onWillPop(): changeFilter=${changeFilter}");
      Navigator.pop(context, changeFilter);
      return Future.value(true);
    },
    builder: (context) {
      return AreaFilterDialog();
    },
  );
}

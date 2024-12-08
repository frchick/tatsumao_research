import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// Firebase Storage からの画像取得
// 事前に Firebase Storage を構成して、クロスサイトオリジンを許可すること。
class MyFSImage extends StatefulWidget
{
  const MyFSImage(this.gsPath, { super.key, this.loadingIcon, this.errorIcon });

  final String gsPath;
  final Widget ?loadingIcon;
  final Widget ?errorIcon;

  @override
  State<MyFSImage> createState() => _MyFSImageState();
}

class _MyFSImageState extends State<MyFSImage>
{
  // 画像。読み込みが完了するまでは null。
  Widget ?_iconImage;

  @override
  void initState()
  {
    super.initState();
    getImage(widget.gsPath);
  }

  void getImage(String gsPath) async
  {
    print("MyFSImage(${gsPath})");

    try {
      // Firebase Storage のURIスキーム(gs://)からURLを取得し、HTTPリクエストで画像を取得
      // NOTE: ブラウザにキャッシュしようとすると、CORSでハマる
      final ref = FirebaseStorage.instance.ref().child(gsPath);
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      // HTTPレスポンスを得られたら画像を作成
      setState(() {
        if(response.statusCode == 200)
        {
          final imageBytes = response.bodyBytes;
          _iconImage = Image.memory(imageBytes);
          print("MyFSImage : _iconImage = ${_iconImage}");
        }else{
          // 成功(200)以外ならエラーアイコン
          _iconImage = widget.errorIcon;
          _iconImage ??= const Icon(Icons.error, size:54);
          print("MyFSImage : Error ${response.statusCode}");
        }
      });
    } catch (e) {
      // 例外が発生したらエラーアイコン
      setState(() {
        _iconImage = widget.errorIcon;
        _iconImage ??= const Icon(Icons.error, size:54);
        print("MyFSImage : Excepthon ${e}");
      });
    }
  }

  @override
  Widget build(BuildContext context)
  {
    // 画像が取得できるまでは、適当なアイコンを返す
    Widget? iconImage = _iconImage;
    iconImage ??= widget.loadingIcon;
    iconImage ??= const Icon(Icons.downloading, size:54);
    return iconImage;
  }
}

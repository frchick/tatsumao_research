# tatsumao_research

Flutter 3.13.9 • channel stable • https://github.com/flutter/flutter.git
Framework • revision d211f42860 (1 year, 2 months ago) • 2023-10-25 13:42:25 -0700
Engine • revision 0545f8705d
Tools • Dart 3.1.5 • DevTools 2.25.0


## Firebase ホスティング

https://tatsumao-research.web.app/


## Firebase Storage から画像を読み込む。

Firebase Storage に対してクロスサイトオリジンを設定する。
https://qiita.com/chima91/items/0cd46b5965e087609ef5

+ gsutil をインストールする。
  https://cloud.google.com/storage/docs/gsutil_install?hl=ja#windows

+ "Google Cloud SDK Shell" で以下を実行
  >gsutil cors set cors.json gs://tatsumao-research.firebasestorage.app

Google Cloud Storage と Firebase storage は、実は同一。
Cloud Storage からみたバケットのパス
  + tatsumao-research.firebasestorage.app

Cloud Storage からアクセスすると、より多くの設定が可能。
  + キャッシュ制御
    + https://cloud.google.com/storage/docs/metadata?hl=ja#cache-control
  + データを一般公開する
    + https://cloud.google.com/storage/docs/access-control/making-data-public?hl=ja#console



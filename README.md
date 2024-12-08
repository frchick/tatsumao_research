# tatsumao_research

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
  tatsumao-research.firebasestorage.app

Cloud Storage からアクセスすると、より多くの設定が可能。
  + キャッシュ制御
    + https://cloud.google.com/storage/docs/metadata?hl=ja#cache-control
  + データを一般公開する
    + https://cloud.google.com/storage/docs/access-control/making-data-public?hl=ja#console



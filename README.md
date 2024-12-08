# tatsumao_research

A new Flutter project.

## Getting Started

## Firebase Storage から画像を読み込む。

Firebase Storage に対してクロスサイトオリジンを設定する。
https://qiita.com/chima91/items/0cd46b5965e087609ef5

+ gsutil をインストールする。
  https://cloud.google.com/storage/docs/gsutil_install?hl=ja#windows

+ "Google Cloud SDK Shell" で以下を実行
  >gsutil cors set cors.json gs://tatsumao-research.firebasestorage.app

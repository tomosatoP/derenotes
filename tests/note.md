# VisualStudioCodeのテストについて

## Unittest Dicovery Error

``VisualStudioCode`` のテストでは、実行できません。
``from kivy.logger import Logger`` があると ``kivy`` の初期化処理が ``sys.exit(2)`` を出力するのが原因のようです。

コマンドラインの ``python -m unittest dicover tests`` は、実行できます。

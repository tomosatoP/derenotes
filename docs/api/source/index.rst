.. derenotes documentation master file, created by
   sphinx-quickstart on Sat Jan 17 15:52:27 2026.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

derenotes API documentation
===========================

**デレステ譜面ファイル作成アプリ** 用に作った ``Python`` モジュールの説明です。

**WSL2 ubuntu** 環境で動作可能です。

- GUIフレームワークには、 ``Kivy`` を使っています。
- 動画ファイルの画像フレームを取り出すために、FFMpeg共有ライブラリィを使っています。

   - python3-dev
   - libavutil-dev
   - libavformat-dev
   - libavcodec-dev
   - libswscale-dev

- FFMpeg共有ライブラリィを使うために、 ``Cython``, ``numpy`` を使っています。

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   modules/derenotes
   modules/derenotes.libs.notes
   modules/derenotes.libs.image

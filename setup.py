"""
``libs.image.video`` モジュールをビルドするためのセットアップスクリプト。

``pyproject.toml`` で指定されたビルドシステムにより実行される。

:依存パッケージ: python3-dev, libavutil-dev, libavformat-dev, libavcodec-dev, libswscale-dev
:ビルドコマンド: python3 setup.py build_ext --inplace
"""

from setuptools import setup, Extension
from Cython.Build import cythonize

extensions = [
    Extension(
        name="derenotes.libs.image.video",
        sources=["derenotes/libs/image/video.pyx"],
        libraries=["avutil", "avformat", "avcodec", "swscale"],
        library_dirs=["/usr/lib/x86_64-linux-gnu"],
        include_dirs=["/usr/include/x86_64-linux-gnu"],
    )
]

setup(ext_modules=cythonize(extensions))

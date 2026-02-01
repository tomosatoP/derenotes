"""
デレステ動画を扱うモジュール。

デレステ動画データの画像フレームを表示するウィジットを扱う。
"""

from fractions import Fraction

from kivy.logger import Logger
from kivy.factory import Factory
from kivy.graphics.texture import Texture  # 仮引数の型アノテーション

import derenotes.libs.image.video as video


class FrameView(Factory.Image):
    """
    デレステ動画データの画像フレームを表示するウィジェット。

    デレステ動画データを保持し、インデックスで指定された画像フレームを表示する。

    :var NumericProperty frame_index: 画像フレームのインデックス。
    :var str colorfmt: 画像フレームの色フォーマット。初期値は、 **rgb** 。
    :var str bufferfmt: 画像フレームのバッファーフォーマット。初期値は、 **ubyte** 。
    """

    frame_index = Factory.NumericProperty(0)  # フレーム番号

    colorfmt: str = "rgb"
    bufferfmt: str = "ubyte"

    _stream: video.Stream | None = None
    _backup_buffer: bytes | None = None  # buffer のバックアップ

    def reset(self) -> None:
        """
        デレステ動画データを破棄し、表示をリセットする。
        """

        # Image のパラメーター
        self.texture = None
        self.fit_mode = "scale-down"
        self.source = "icon/NoImage.png"

        self.frame_index = 0
        self._stream = None
        self._backup_buffer = None

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self, video_filename: str, video_filetype: str = "mp4", video_accelerator: str = None) -> None:
        """
        設定を行う。

        デレステ動画ファイルを読み込んでデレステ動画データを生成し、
        デレステ動画データから取得したフレームサイズで画像フレームを確保する。
        グラフィックスコンテキスト全体が再読み込みされた時のコールバック関数を登録する。

        :param str video_filename: デレステ動画ファイルのパス名。
        """

        self._stream = video.Stream(video_filename, video_filetype, video_accelerator)

        if isinstance(self._stream, video.Stream):
            self.texture = Factory.Texture.create(
                size=(self._stream.width, self._stream.height),
                colorfmt=self.colorfmt,
                bufferfmt=self.bufferfmt,
            )
            self.texture.add_reload_observer(self.reload_buffer)

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def update(self) -> None:
        """
        画像フレームを表示する。

        ウィジットが準備済みでなければ、何もしない。
        指定された ``frame_index`` でフレームバッファを画像フレームに転送する（表示される）。
        グラフィックスコンテキスト全体が再読み込みされた時のためにフレームバッファをバックアップする。
        """

        if isinstance(self._stream, video.Stream) and isinstance(self.texture, Factory.Texture):
            self._backup_buffer = self._stream.frame_buffer(self.frame_index)
            self.texture.blit_buffer(
                self._backup_buffer,
                colorfmt=self.colorfmt,
                bufferfmt=self.bufferfmt,
            )

        Logger.debug(f"{self.__class__.__name__}: update.")

    def reload_buffer(self, texture: Texture) -> None:
        """
        コールバック関数。

        グラフィックスコンテキスト全体が再読み込みされた時のコールバック関数で、バックアップされたフレームのバッファを転送する。

        :param Texture texture: 呼び出し元のグラフィックスコンテキスト。
        """

        texture.blit_buffer(self._backup_buffer)

        Logger.debug(f"{self.__class__.__name__}: reload_buffer.")

    @property
    def total_frames(self) -> int:
        """
        総フレーム数。
        """

        if isinstance(self._stream, video.Stream):
            return self._stream.total_frames
        else:
            return 0

    @property
    def elapsed_time(self) -> tuple[int, Fraction]:
        """
        フレームの経過時間。
        """

        if isinstance(self._stream, video.Stream):
            return (self._stream.timestamp(self.frame_index), self._stream.time_base)
        else:
            return (0, Fraction(0))


if __name__ == "__main__":
    print(__file__)

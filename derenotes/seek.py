"""
デレステ動画データのフレーム番号指定方法を提供するモジュール。

フレーム番号を指定するウィジットとシーク移動量を指定するウィジットを扱う。
"""

from math import prod
from fractions import Fraction

from kivy.logger import Logger
from kivy.factory import Factory


class SeekBar(Factory.BoxLayout):
    """
    画像フレームのインデックスを指定するウィジット。

    シーク用スライダーを操作して画像フレームのインデックスを指定する。
    画像フレームの経過時間を表示する。

    :構成 Label elapsedtime: 経過時間ラベル
    :構成 Slider slider: シーク用スライダー
    """

    def reset(self) -> None:
        """
        初期状態に戻す。
        """

        self.slider.min = 0
        self.slider.max = 0
        self.elapsedtime.text = "0.00 秒"

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self, total_frames: int) -> None:
        """
        設定する。

        デレステ動画データの総フレーム数に基づいて、シーク用スライダーの最大値を設定する。

        :param int total_frames: デレステ動画データの総フレーム数
        """

        self.slider.max = total_frames - 1 if total_frames > 0 else 0

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def update(self, elapsed_time: tuple[int, Fraction]) -> None:
        """
        更新する。

        画像フレームの経過時間を経過時間ラベルに反映する。

        :param tuple elapsed_time: 画像フレームの経過時間 [timestamp, time_base]
        """

        self.elapsedtime.text = f"{prod(elapsed_time):.2f} 秒"

        Logger.debug(f"{self.__class__.__name__}: update.")

    def shift(self, value: int) -> None:
        """
        シーク用スライダーをシフトする。

        シーク移動量ボタンに ``bind`` させて、シーク用スライダー値を操作する。

        :param int value: シーク移動量
        """

        self.slider.value = max(self.slider.min, min(self.slider.max, self.slider.value + value))

        Logger.debug(f"{self.__class__.__name__}: shift {value}.")


class SeekPanel(Factory.BoxLayout):
    """
    シーク移動量を指定するウィジット。
    """

    def reset(self, steps: list[str]) -> None:
        """
        シーク移動量ボタンを配置する。

        ``steps`` に基づいてグルーピングされたシーク移動量ボタンを配置する。
            例： ["-300", "-60", "-10", "-5", "-1", "+1", "+5", "+10", "+60", "+300"]

        :param list[str] steps: シーク移動量を記載した文字列のリスト
        """

        # シーク移動量ボタンを配置。
        if not self.children:
            for step in steps:
                btn = Factory.Button(text=step)
                self.add_widget(btn)

        Logger.debug(f"{self.__class__.__name__}: reset.")


if __name__ == "__main__":
    print(__file__)

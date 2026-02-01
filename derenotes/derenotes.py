"""
デレステ譜面ファイル作成アプリのメインウィンドウ。
"""

from typing import Any
import tomllib

from kivy.app import App
from kivy.logger import Logger
from kivy.factory import Factory

from derenotes.file import FileView
from derenotes.frame import FrameView
from derenotes.seek import SeekBar, SeekPanel
from derenotes.chart import ChartEdit, NoteTypesGridLayout, ChartView

# 設定ファイルが無かった時の設定
SEEK_STEPS: list[str] = ["-300", "-60", "-10", "-5", "-1", "+1", "+5", "+10", "+60", "+300"]
VIDEO_FILETYPE: str = "mp4"
VIDEO_ACCELERATOR: str | None = "cuda"


class MainBoxLayout(Factory.BoxLayout):
    """
    メインウィンドウ。

    :構成 fileview: データ譜面ファイルの管理ウィジット。
    :構成 preview: デレステ動画データの画像フレームを表示するウィジット。
    :構成 seekbar: 画像フレーム番号を指定するウィジット。
    :構成 seekpanel: シーク移動量を指定するウィジット。
    :構成 chartedit: デレステ譜面データを編集するウィジット。
    :構成 notetypes: ノートタイプ選択ウィジット。
    :構成 chartview: デレステ譜面データを表示するウィジット。
    """

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)

        self.check_all_views()
        self.load_config()
        self.reset()

        # シーク値の変更時コールバック関数を登録
        self.seekbar.slider.bind(value=lambda instance, value: self.update())
        # デレステ譜面データの変更時コールバック関数を登録
        self.fileview.bind(chart=lambda instance, value: self.changed_file())
        # シークパネルのシーク移動量ボタンのコールバック関数を登録
        for btn in self.seekpanel.children:
            btn.bind(on_release=lambda btn: self.seekbar.shift(int(btn.text)))

        Logger.debug(f"{self.__class__.__name__}: init.")

    def check_all_views(self) -> None:
        """
        各ウィジットが正しくクラスから生成されていることを確認する。
        """

        if not isinstance(self.fileview, FileView):
            raise Exception("FileView")

        if not isinstance(self.preview, FrameView):
            raise Exception("FrameView")

        if not isinstance(self.seekbar, SeekBar):
            raise Exception("SeekBar")

        if not isinstance(self.seekpanel, SeekPanel):
            raise Exception("SeekPanel")

        if not isinstance(self.chartedit, ChartEdit):
            raise Exception("ChartEdit")

        if not isinstance(self.notetypes, NoteTypesGridLayout):
            raise Exception("NoteTypesGridLayout")

        if not isinstance(self.chartview, ChartView):
            raise Exception("ChartView")

    def load_config(self) -> None:
        """
        設定ファイルを読み込む。
        """

        with open("config/config.toml", "rb") as f:
            config = tomllib.load(f)

            global SEEK_STEPS
            global VIDEO_FILETYPE
            global VIDEO_ACCELERATOR

            SEEK_STEPS = config["steps"]
            VIDEO_FILETYPE = config["filetype"]
            VIDEO_ACCELERATOR = None if config["accelerator"] == "software" else config["accelerator"]

    def changed_file(self) -> None:
        """
        デレステ譜面データが更新（新規作成、開く、閉じる）されたら各ウィジットを再設定する。
        """

        if self.fileview.chart is None:  # ファイルを**閉じる**場合
            self.reset()

        else:  # ファイルを**新規作成**, **開く**の場合
            self.reset()
            self.setup()

            # シーク値を変更することで、update関数を呼び出す
            if self.fileview.chart.last_index == 0:
                # 値が 0 にリセットされているので、0 以外の 1 にする。
                self.seekbar.slider.value = 1
            else:
                self.seekbar.slider.value = self.fileview.chart.last_index

            self.fileview.dismiss()

        Logger.debug(f"{self.__class__.__name__}: changed_file.")

    def reset(self) -> None:
        """
        各ウィジットを初期化する。
        """

        self.check_all_views()

        self.fileview.reset()
        self.preview.reset()
        self.seekbar.reset()
        self.seekpanel.reset(SEEK_STEPS)  # ボタンを配置済みの場合は、何もしない。
        self.chartedit.reset()
        self.chartview.reset()

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self) -> None:
        """
        各ウィジットを設定する。
        """

        self.check_all_views()

        self.fileview.setup()
        self.preview.setup(self.fileview.chart.videofile, VIDEO_FILETYPE, VIDEO_ACCELERATOR)
        self.seekbar.setup(self.preview.total_frames)
        self.chartedit.setup(self.fileview.chart, self.notetypes)
        self.chartview.setup(self.fileview.chart)

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def update(self) -> None:
        """
        シーク値が変更されたら各ウィジットを更新する。

        """

        if self.seekbar.slider.max != 0:  # seekbar のリセット時を除く
            self.check_all_views()

            self.preview.frame_index = int(self.seekbar.slider.value)
            self.fileview.chart.last_index = self.preview.frame_index

            self.preview.update()
            self.seekbar.update(self.preview.elapsed_time)
            self.chartedit.update(self.preview.frame_index, self.preview.elapsed_time)
            self.chartview.update(self.preview.frame_index, self.preview.elapsed_time)

        Logger.debug(f"{self.__class__.__name__}: update.")


class DerenotesApp(App):
    """
    デレステ譜面ファイル作成アプリのエントリーポイント。
    """

    def build(self) -> MainBoxLayout:
        return MainBoxLayout()


if __name__ == "__main__":
    DerenotesApp().run()

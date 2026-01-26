"""
デレステ譜面ファイルを管理するモジュール。

デレステ譜面ファイルの操作を行うウィジットとデレステ譜面データのデレステ楽曲情報を表示するウィジットを扱う。
"""

from typing import Any
from pathlib import Path
from dataclasses import fields

from kivy.logger import Logger
from kivy.factory import Factory
from kivy.uix.widget import Widget  # 仮引数の型アノテーション

import derenotes.libs.notes.song as song

MENU_ITEMS: dict = {
    "新規作成": "pop_new",
    "開く": "pop_open",
    "保存": "save",
    "名前を付けて保存": "pop_save_with_name",
    "閉じる": "close",
}


class NaviBoxLayout(Factory.BoxLayout):
    """
    ナビゲーションドロワー（ポップアップのコンテント）のウィジット
    """

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        self.orientation = "vertical"

        Logger.debug(f"{self.__class__.__name__}: init.")


class FileView(Factory.BoxLayout):
    """
    「♪♪」ボタンとデレステ譜面データの楽曲情報を表示するウィジット。

    「♪♪」からナビゲーションドロワー風ファイルメニューを展開する。
    デレステ譜面データの楽曲情報を表示する。

    :var song.Chart chart: デレステ譜面データ。
    :構成 title: デレステ楽曲のタイトルを表示するラベル。
    :構成 category: デレステ楽曲のカテゴリを表示するラベル。
    :構成 type: デレステ楽曲のタイプを表示するラベル。
    :構成 level: デレステ楽曲のレベルを表示するラベル。
    """

    chart = Factory.ObjectProperty(None, allownone=True)

    def reset(self) -> None:
        """
        楽曲情報表示を初期状態に戻す。
        """

        self.title.text = "タイトル"
        self.category.text = "カテゴリ"
        self.type.text = "タイプ"
        self.level.text = "レベル"

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self) -> None:
        """
        楽曲情報表示をデレステ譜面データに基づいて更新する。
        """

        if self.chart is not None and isinstance(self.chart.song, song.Song):
            self.title.text = self.chart.song.name
            self.category.text = self.chart.song.category.replace(":", "\n")
            self.type.text = self.chart.song.type
            self.level.text = str(self.chart.song.level)

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def dismiss(self) -> None:
        """
        ナビゲーションドロワー風ファイルメニューから呼び出された ``popup`` を閉じる。
        """

        self.popup.dismiss()

        Logger.debug(f"{self.__class__.__name__}: dismiss.")

    def navigation(self) -> None:
        """
        ``NavigationDrawer`` みたいなフィルメニューのモーダルビュー（ポップアップ）を開く。
        """

        content = Factory.NaviBoxLayout()
        for item in MENU_ITEMS.keys():
            # todo: デレステ譜面データが無い時には、"新規作成"・"開く"のみ有効にする。
            btn = Factory.FileHandleButton(text=item, disabled=False)
            content.add_widget(btn)

        self.navi = Factory.ModalView(size_hint=(0.4, 0.3), pos_hint={"x": 0, "y": 0.7})
        self.navi.add_widget(content)
        self.navi.open()

        Logger.debug(f"{self.__class__.__name__}: Navigation.")

    def handler(self, filehandlebutton: Widget) -> None:
        """
        ``FileHandleButton`` ハンドル。

        呼び出した ``filehandlebutton`` に応じてファイル操作を行う。

        :param Widget filehandlebutton: 呼び出したウィジット。
        """

        # 新しい ``popup`` を開くので、呼び出し元のナビゲーションドロワー風ファイルメニューを閉じる。
        if self.navi:
            self.navi.dismiss()

        getattr(self, MENU_ITEMS.get(filehandlebutton.text))()

        Logger.debug(f"{self.__class__.__name__}: handler.")

    def pop_new(self) -> None:
        """
        **新規作成** ダイアログを呼び出す。
        """

        content = NewChartDialog(cancel=self.dismiss, load=self.new)
        self.popup = Factory.Popup(title=content.title, content=content)
        self.popup.open()

    def new(self, path: str, filename: str, name: str, category: str, type: str, level: str) -> None:
        """
        新たにデレステ譜面データを作成する。

        :param str path: 選択したデレステ動画ファイルのフォルダ名。
        :param str filename: 選択したデレステ動画ファイルのファイル名。
        :param str name: デレステ楽曲のタイトル。
        :param str category: デレステ楽曲のカテゴリ。
        :param str type: デレステ楽曲のタイプ。
        :param str level: デレステ楽曲のレベル。
        """

        chart = song.Chart()
        chart.videofile = "/".join([Path(path).name, Path(filename).name])
        chart.song = song.Song(
            name=name,
            category=song.SongCategory(category),
            type=song.SongType(type),
            level=int(level),
        )
        chart.last_index = 0

        self.chart = chart

        Logger.debug(f"{self.__class__.__name__}: new.")

    def pop_open(self) -> None:
        """
        **開く** ダイアログを呼び出す。
        """

        content = LoadChartDialog(cancel=self.dismiss, load=self.open)
        self.popup = Factory.Popup(title=content.title, content=content)
        self.popup.open()

    def open(self, path: str, filename: str) -> None:
        """
        選択したデレステ譜面ファイルを開く。

        :param str path: 選択したデレステ譜面ファイルのフォルダ名。
        :param str filename: 選択したデレステ譜面ファイルのファイル名。
        """

        chart = song.Chart()
        chart.load(Path(filename))

        self.chart = chart

        Logger.debug(f"{self.__class__.__name__}: open.")

    def save(self, new_filename: str | None = None) -> None:
        """
        デレステ譜面ファイルを保存する。

        デレステ譜面ファイルを上書き保存する。
        ファイルがない場合は、 **名前を付けて保存ダイアログ** を呼び出す。
        ``new_filename`` が与えられた場合は、新たに名前を付けて保存する。

        :param str new_filename: 新たに名前を付けて保存する際のファイル名。初期値は、 ``None`` 。
        """

        if not new_filename:
            if self.chart._path.is_file():
                self.chart.save(self.chart._path)
            else:
                self.pop_save_with_name()
        else:
            save_path = Path("/".join(["output", new_filename]))
            self.chart.save(save_path)

            self.dismiss()

        Logger.debug(f"{self.__class__.__name__}: save.")

    def pop_save_with_name(self) -> None:
        """
        **名前を付けて保存** ダイアログを呼び出す。
        """

        content = SaveChartWithNameDialog(fileview=self, cancel=self.dismiss, load=self.save)
        self.popup = Factory.Popup(
            title=content.title,
            content=content,
            pos_hint={"left": 0.0, "top": 0.9},
            size_hint=(1.0, 0.2),
        )
        self.popup.open()

    def close(self) -> None:
        """
        デレステ譜面データを破棄する。
        """

        self.chart = None

        Logger.debug(f"{self.__class__.__name__}: close.")


class LoadChartDialog(Factory.FloatLayout):
    """
    デレステ譜面ファイルを **開く** ダイアログ。

    :構成 FileChooser filechooser: ファイル選択を行うウィジット。
    :構成 BoxLayout fileinfo: 楽曲情報表示するウィジット。
    :構成 Button load_button: **開く** ボタン。
    """

    cancel = Factory.ObjectProperty(None)
    load = Factory.ObjectProperty(None)

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)

        self.filechooser.rootpath = "output"
        self.filechooser.filters = ["*.json"]
        self.title = "読み込む譜面ファイルを選択してください。"

        # 選択したデレステ譜面ファイルの楽曲情報の表示欄
        for info in ["video file"] + list(map(lambda x: x.name, fields(song.Song))):
            infolabel = Factory.InfoLabel()
            infolabel.key.text = info
            self.fileinfo.add_widget(infolabel)

        Logger.debug(f"{self.__class__.__name__}: init.")

    def view(self, path: str, filename: str) -> None:
        """
        選択しているデレステ譜面ファイル情報の表示。

        :param str path: 選択してるデレステ譜面ファイのフォルダ名。
        :param str filename: 選択しているデレステ譜面ファイルのファイルのパス名
        """

        # load_button を有効化
        if self.load_button.disabled:
            self.load_button.disabled = False

        # 選択したデレステ譜面ファイルの楽曲情報を表示
        if self.filechooser.selection != []:
            chart = song.Chart()
            chart.load(Path(filename))

            self.fileinfo.children[4].value.text = chart.videofile
            self.fileinfo.children[3].value.text = chart.song.name
            self.fileinfo.children[2].value.text = chart.song.category
            self.fileinfo.children[1].value.text = chart.song.type
            self.fileinfo.children[0].value.text = str(chart.song.level)

        Logger.debug(f"{self.__class__.__name__}: view.")


class NewChartDialog(Factory.FloatLayout):
    """
    デレステ譜面ファイルの **新規作成** ダイアログ。

    :構成 FileChooser filechooser: デレステ動画ファイルを選択するウィジット。
    :構成 FrameView video_frame: 選択したデレステ動画ファイルのプレビューウィジット。
    :構成 SongBoxLayout fileinfo: 新規作成するデレステ譜面ファイルの楽曲情報を入力するウィジット。
    :構成 Button load_button: **新規作成** ボタン。
    """

    cancel = Factory.ObjectProperty(None)
    load = Factory.ObjectProperty(None)

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)

        self.filechooser.rootpath = "input"
        self.filechooser.filters = ["*.mp4"]
        self.title = "デレステ譜面データの基となるデレステ動画ファイルを選択してください。"

        # 選択したデレステ動画ファイルのプレビュー欄
        self.video_frame.reset()

        # 選択したデレステ動画ファイルの楽曲情報の入力欄
        self.fileinfo.category.values = list(song.SongCategory)
        self.fileinfo.category.text = song.SongCategory.WIDE_MASTER_PLUS
        self.fileinfo.type.values = list(song.SongType)
        self.fileinfo.type.text = song.SongType.ALL

        Logger.debug(f"{self.__class__.__name__}: init.")

    def view(self) -> None:
        """
        選択しているデレステ動画ファイルの情報を表示する。
        """

        # "load_button"の有効化。
        if self.load_button.disabled:
            self.load_button.disabled = False

        # デレステ動画ファイルのプレビュー。
        if self.filechooser.selection != []:
            self.video_frame.reset()
            self.video_frame.setup(self.filechooser.selection[0])
            self.video_frame.update()

        # デレステ譜面ファイルの楽曲情報を入力する。
        self.fileinfo.name.text = Path(self.filechooser.selection[0]).stem

        Logger.debug(f"{self.__class__.__name__}: view.")


class SaveChartWithNameDialog(Factory.FloatLayout):
    """
    デレステ譜面ファイルに **名前を付けて保存** ダイアログ。

    :param FileView fileview: 呼び出し元の ``FileView`` のインスタンス
    """

    load = Factory.ObjectProperty(None)
    cancel = Factory.ObjectProperty(None)

    def __init__(self, fileview: FileView, **kwargs: Any) -> None:
        super().__init__(**kwargs)

        self.fileview = fileview

        self.title = "名前を付けてデレステ譜面ファイルを保存。"

        self.name.text = self.fileview.chart.song.name + ".json"

        Logger.debug(f"{self.__class__.__name__}: init.")


if __name__ == "__main__":
    print(__file__)

"""
デレステ譜面データを扱うモジュール。

ノートタイプ選択ウィジットとデレステ譜面データを編集・表示するウィジットを扱う。
"""

from math import ceil
from fractions import Fraction

from kivy.logger import Logger
from kivy.factory import Factory

from derenotes.libs.notes import song


# 譜面表示の時間幅(秒)
RANGE: int = 2
# ノートタイプのカテゴリの色
NOTECATEGORY_RGBA: dict[str, tuple] = {
    "TAP": (0.8, 0.8, 0.8, 1),
    "FLICK": (0, 0.8, 0.8, 1),
    "LONG": (0, 0.8, 0, 1),
    "SLIDE": (0.8, 0.8, 0, 1),
    "DAMAGE": (0.7, 0.7, 0.7, 1),
    "_": (0.7, 0.7, 0.7, 1),
}
# ノートタイプの色
NOTETYPES_RGBA: dict[str, tuple] = {
    "TAP": NOTECATEGORY_RGBA["TAP"],
    "FLICK:LEFT": NOTECATEGORY_RGBA["FLICK"],
    "FLICK:RIGHT": NOTECATEGORY_RGBA["FLICK"],
    "LONG:ON": NOTECATEGORY_RGBA["LONG"],
    "LONG:OFF": NOTECATEGORY_RGBA["LONG"],
    "LONG:FLICK:LEFT": NOTECATEGORY_RGBA["LONG"],
    "LONG:FLICK:RIGHT": NOTECATEGORY_RGBA["LONG"],
    "SLIDE:ON": NOTECATEGORY_RGBA["SLIDE"],
    "SLIDE:PASS": NOTECATEGORY_RGBA["SLIDE"],
    "SLIDE:OFF": NOTECATEGORY_RGBA["SLIDE"],
    "SLIDE:FLICK:LEFT": NOTECATEGORY_RGBA["SLIDE"],
    "SLIDE:FLICK:RIGHT": NOTECATEGORY_RGBA["SLIDE"],
    "DAMAGE": NOTECATEGORY_RGBA["DAMAGE"],
    "START": NOTECATEGORY_RGBA["_"],
    "END": NOTECATEGORY_RGBA["_"],
}
# 楽曲カテゴリのレーン数
LANE_NUMBER: dict[str, int] = {
    "SMART:LIGHT": 1,
    "SMART:TRICK": 1,
    "WIDE:DEBUT": 5,
    "WIDE:REGULAR": 5,
    "WIDE:PRO": 5,
    "WIDE:MASTER": 5,
    "WIDE:MASTER+": 5,
    "WITCH:WITCH": 5,
    "GRAND:PIANO": 15,
    "GRAND:FORTE": 15,
}


class _NoteImage(Factory.Image):
    """
    枠付き背景（イメージ）。

    ``_NoteTypeToggleButton`` に継承される。
    枠付き背景の色設定を行う。

    :param ColorProperty notecolor: ``NoteType`` に基づく枠の配色。
    """

    notecolor = Factory.ColorProperty()


class _NoteTypeToggleButton(Factory.ToggleButtonBehavior, _NoteImage):
    """
    枠付き背景（イメージ）のトグルボタン。

    ``NoteTypesGridLayout`` に配置される。
    トグルボタンの状態（``state``: ``down``, ``normal``）でノートタイプ画像を切り替える。

    :param StringProperty down_png_name: ``down`` 時の ``NoteType`` 画像(``PNG``)ファイルパス。
    :param StringProperty normal_png_name: `` normal`` 時の ``NoteType`` 画像(``PNG``)ファイルパス。
    """

    down_png_name = Factory.StringProperty()
    normal_png_name = Factory.StringProperty()

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        if self.state == "down":
            self.source = self.down_png_name
        else:
            self.source = self.normal_png_name

        Logger.debug(f"{self.__class__.__name__}: init.")

    def on_state(self, widget, value):
        """
        トグルボタンの状態の変化に応じて画像を切り替える。

        :param widget: 呼び出し元のトグルボタン。
        :param value: 呼び出し元のトグルボタンの状態。 ``normal`` | ``down`` 。
        """

        if value == "normal":
            self.source = self.normal_png_name
        else:
            self.source = self.down_png_name


class NoteTypesGridLayout(Factory.GridLayout):
    """
    デレステ譜面データに追加するノートタイプを選択するウィジェット。
    """

    _notetype = Factory.ObjectProperty(song.NoteType.TAP)  # 選択中の NoteType

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self.cols = ceil(len(song.NoteType) / 2)  # 行数を2として、列数を設定

        # ノートタイプごとに NoteTypeToggleButton を追加
        for notetype in song.NoteType:
            btn = _NoteTypeToggleButton(
                notecolor=NOTETYPES_RGBA[notetype],
                group="note_type",
                down_png_name="icon/" + notetype.name + ".png",
                normal_png_name="icon/" + notetype.name + "_NORMAL.png",
                state="down" if notetype == self._notetype else "normal",
                allow_no_selection=False,
                on_release=lambda x, y=notetype: self.setter("_notetype")(x, y),
            )
            self.add_widget(btn)

        Logger.debug(f"{self.__class__.__name__}: init.")

    @property
    def notetype(self) -> song.NoteType:
        """
        追加可能な ``NoteType``。
        """

        return self._notetype


class _AllocNoteToggleButton(Factory.ToggleButton):
    """
    デレステ譜面データに追加するノートタイプを表示するトグルボタン。

    ``ChartEdit``>``lanes`` に配置される。
    デレステ譜面データに追加する ``Note`` を保持し、ノートタイプを表示する。

    - down: 追加するノートタイプを表示
    - normal: レーン番号を表示

    :var int lane: レーン番号
    :var song.Note | None note: ノート
    """

    lane: int = 0
    note: song.Note | None = None


class ChartEdit(Factory.BoxLayout):
    """
    デレステ譜面データを編集するウィジット。

    ``lanes`` に配置されたトグルボタンに ``note`` をセットし、デレステ譜面データに追加する。
    再度操作すると、デレステ譜面データから ``note`` を取り去ると共に、リセットする。

    :構成 currentnotes: 表示フレームまでのノート数を表示する ``Label``
    :構成 lanes: レーン編集用トグルボタンを配置する ``BoxLayout``
    :構成 totalnotes: 全ノート数を表示する ``Label``
    """

    # 表示フレームのタイムスタンプと時間単位（秒）、update関数で更新される。
    _timestamp: int = 0
    _time_base: Fraction = Fraction()

    # デレステ譜面データ
    _chart: song.Chart | None = None

    def reset(self) -> None:
        """
        初期状態（レーン無し）にする。
        """

        self.currentnotes.text = "--"
        self.lanes.clear_widgets()
        self.totalnotes.text = "--"

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self, chart: song.Chart, notetypes: NoteTypesGridLayout) -> None:
        """
        デレステ楽曲カテゴリに合わせて ``lanes`` に複数のレーン編集用トグルボタンを配置する。

        :param song.Chart chart: デレステ譜面データ
        :param NoteTypesGridLayout notetypes: ノートタイプを保持している ``NoteTypesGridLayout`` のインスタンス
        """

        if isinstance(chart, song.Chart):
            self._chart = chart

        number_lanes: int = LANE_NUMBER.get(self._chart.song.category, 5)
        for lane in range(number_lanes):
            btn = _AllocNoteToggleButton(
                text=f"Lane{lane + 1}",
                state="normal",
                on_release=lambda instance: self._change_note(instance, notetypes),
            )
            btn.lane = lane + 1
            self.lanes.add_widget(btn)

        # currentnotes, totalnotes を更新
        self.currentnotes.text = str(self._chart.current_notes(self._timestamp))
        self.totalnotes.text = str(self._chart.total_notes)

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def _change_note(self, instance: _AllocNoteToggleButton, notetypes: NoteTypesGridLayout):
        """
        レーン編集用トグルボタンををリリースした時のコールバック関数。

        リリースした時の ``state`` に従って、``note`` をデレステ譜面データに反映する。
        ノートタイプは、``notetypes``.``_notetype`` を

        - down: ``note`` を追加。 ``_push_chart()`` を呼び出す。
        - normal: ``note`` を削除。 ``_pop_chart()`` を呼び出す。

        :param _AllocNoteToggleButton instance: トリガーになったレーン編集用トグルボタン
        :param song.Chart chart: デレステ譜面データ
        :param NoteTypesGridLayout notetypes: ノートタイプを保持している ``NoteTypesGridLayout`` のインスタンス
        """

        if instance.state == "down":  # note を追加。
            # todo: widthを取得
            instance.text = notetypes.notetype.name.replace("_", "\n")
            instance.note = song.Note(
                self._timestamp,
                instance.lane,
                1,  # ノート幅(width)
                notetypes.notetype,
                self._time_base,
            )
            self._chart.push(instance.note)

        elif instance.state == "normal":  # note を取り出す。
            self._chart.remove(instance.note)
            instance.text = f"Lane{instance.lane}"
            instance.note = None

        else:
            pass

    def update(self, frame_index: int, elapsed_time: tuple) -> None:
        """
        表示フレームのインデックスに基づいてデレステ譜面データを表示する。

        :param song.Chart chart: デレステ譜面データ
        :param int frame_index: 表示フレームのインデックス
        :param tuple elapsed_time: 表示フレームの経過時間 [timestamp, time_base]
        """

        self._timestamp, self._time_base = elapsed_time

        # lanes の表示を初期化する。
        for lane in self.lanes.children:
            if isinstance(lane, _AllocNoteToggleButton) and lane.state == "down":
                lane.state = "normal"
                lane.note = None
                lane.text = f"Lane{lane.lane}"

        # currentnotes, totalnotes を更新
        self.currentnotes.text = str(self._chart.current_notes(self._timestamp))
        self.totalnotes.text = str(self._chart.total_notes)

        # lanes を更新
        for note in self._chart.find(self._timestamp):
            if isinstance(note, song.Note):
                self.lanes.children[-note.lane].note = note
                self.lanes.children[-note.lane].text = note.type.replace(":", "\n")
                self.lanes.children[-note.lane].state = "down"

        Logger.debug(f"{self.__class__.__name__}: update.")


# ChartViewのレーンに表示するノートアイコン
class _NoteIcon(Factory.Image): ...


class _LaneRelativeLayout(Factory.RelativeLayout):
    """
    デレステ譜面データを表示するレーンのウィジット。

    ``ChartView``>``lanes`` に配置される。
    """

    centerlinecolor = Factory.ColorProperty((1, 1, 1, 1))
    number = Factory.NumericProperty(1)


class ChartView(Factory.BoxLayout):
    """
    デレステ譜面データを表示するウィジット。

    :構成 lanes: レーンを配置する ``BoxLayout``
    """

    # デレステ譜面データ
    _chart: song.Chart | None = None

    def reset(self) -> None:
        """
        初期状態（レーン無し）にする。
        """

        self.lanes.clear_widgets()

        Logger.debug(f"{self.__class__.__name__}: reset.")

    def setup(self, chart: song.Chart) -> None:
        """
        デレステ楽曲カテゴリに合わせて ``lanes`` に複数のレーンを配置する。

        :param FileView fileview: デレステ譜面データ
        """

        if isinstance(chart, song.Chart):
            self._chart = chart

        number_lanes: int = LANE_NUMBER.get(self._chart.song.category, 5)
        for lane in range(number_lanes):
            layout = _LaneRelativeLayout(number=lane + 1)
            self.lanes.add_widget(layout)

        Logger.debug(f"{self.__class__.__name__}: setup.")

    def update(self, frame_index: int, elapsed_time: tuple) -> None:
        """
        デレステ譜面データを表示する。

        表示フレームのインデックスに基づいてデレステ譜面データを各レーンに表示する。
        表示する経過時間の範囲は、``RANGE`` に基づいて決定する。

        :param int frame_index: 表示フレームのインデックス
        :param tuple elapsed_time: 表示フレームの経過時間 [timestamp, base_time]
        """

        # ノートを表示するレーン内の位置を比率で返す。
        def rate(timestamp: int, max_timestamp: int, min_timestamp: int) -> float:
            return (timestamp - min_timestamp) / (max_timestamp - min_timestamp)

        timestamp: int = elapsed_time[0] if isinstance(elapsed_time[0], int) else None
        time_base: Fraction = elapsed_time[1] if isinstance(elapsed_time[1], Fraction) else None

        min_timestamp = timestamp - int(RANGE / 2 / time_base)
        max_timestamp = timestamp + int(RANGE / 2 / time_base)

        # 各レーンの表示をクリア
        for lane in self.lanes.children:
            if isinstance(lane, _LaneRelativeLayout):
                lane.clear_widgets()

        # 各レーンにノートを表示
        if isinstance(self.lanes, Factory.BoxLayout):
            for note in self._chart.search_within_range(min_timestamp, max_timestamp):
                icon = _NoteIcon(
                    source="icon/" + note.type.name + ".png",
                    fit_mode="fill",
                    size_hint=(0.3, 0.08),
                    pos_hint={
                        "center_x": 0.5,
                        "center_y": rate(note.timestamp, max_timestamp, min_timestamp),
                    },
                )
                for lane in filter(lambda lane: lane.number == note.lane, self.lanes.children):
                    lane.add_widget(icon)

        Logger.debug(f"{self.__class__.__name__}: update.")


if __name__ == "__main__":
    print(__file__)

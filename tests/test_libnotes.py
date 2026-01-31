"""
``derenotes.libs.notes.song`` の ``Note``, ``Song``, ``Chart`` のテスト。
"""

import unittest

from pathlib import Path
from subprocess import Popen
from fractions import Fraction

from derenotes.libs.notes import song

COMMAND = [
    "ffmpeg",
    "-f lavfi",
    "-i testsrc2=s=640x480:r=60:d=1,format=yuv420p",
    "-video_track_timescale 9000",
    "-c h264 tests/testsrc2.mp4",
]

if not Path("tests/testsrc2.mp4").exists():
    with Popen(" ".join(COMMAND).split()) as res:
        print(f"{res.returncode}")

test_note = song.Note()

test_song = song.Song()

test_chart = song.Chart()
test_chart.videofile = "tests/testsrc2.mp4"
test_chart.song = song.Song(name="testsrc2")
test_chart.last_index = 0


class TestLibSong(unittest.TestCase):
    def test_note(self) -> None:
        self.assertIsInstance(test_note, song.Note)
        # 初期値のチェック
        self.assertEqual(test_note.timestamp, 0)
        self.assertEqual(test_note.lane, 1)
        self.assertEqual(test_note.type, song.NoteType.TAP)
        self.assertEqual(test_note.time_base, Fraction(1, 1))

    def test_song(self) -> None:
        self.assertIsInstance(test_song, song.Song)
        # 初期値のチェック
        self.assertEqual(test_song.name, "未設定")
        self.assertEqual(test_song.category, song.SongCategory.WIDE_MASTER)
        self.assertEqual(test_song.type, song.SongType.ALL)
        self.assertEqual(test_song.level, 1)

    def test_chart(self) -> None:
        self.assertIsInstance(test_chart, song.Chart)
        # 初期値のチェック
        self.assertEqual(test_chart.last_index, 0)
        # プロパティのチェック
        self.assertEqual(test_chart.videofile, "tests/testsrc2.mp4")
        self.assertEqual(test_chart.song.name, "testsrc2")
        self.assertEqual(test_chart.total_notes, 0)
        # メソッドのチェック


if __name__ == "__main__":
    unittest.main()

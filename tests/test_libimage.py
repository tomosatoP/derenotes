"""
``derenotes.libs.iamge.video`` の ``Stream`` のテスト。
"""

import unittest

from pathlib import Path
from subprocess import Popen
from fractions import Fraction

from derenotes.libs.image.video import Stream, VIDEOError

COMMAND = [
    "ffmpeg",
    "-f lavfi",
    "-i testsrc2=s=640x480:r=60:d=1,format=yuv420p",
    "-c h264",
    "-video_track_timescale 9000",
    "tests/testsrc2.mp4",
]

if not Path("tests/testsrc2.mp4").exists():
    with Popen(" ".join(COMMAND).split()) as res:
        print(f"{res.returncode}")

stream = Stream(url="file:tests/testsrc2.mp4", file_type="mp4", hardware=None)


class TestLibVideo(unittest.TestCase):
    def test_Stream(self) -> None:
        # コンストラクターのエラー
        self.assertRaises(VIDEOError, Stream, url="file:tests/none.mp4")
        self.assertRaises(VIDEOError, Stream, url="file:tests/testsrc2.mp4", file_type="avi")
        self.assertRaises(VIDEOError, Stream, url="file:tests/testsrc2.mp4", file_type="mp4", hardware="vaapi")

        # 想定通りの結果
        self.assertIsInstance(stream, Stream)
        self.assertEqual(stream.decoder_name, "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10")
        self.assertEqual(stream.width, 640)
        self.assertEqual(stream.height, 480)
        self.assertEqual(stream.total_frames, 60)
        self.assertEqual(stream.pixel_format, "yuv420p")
        self.assertEqual(stream.time_base, Fraction(1, 9000))
        self.assertEqual(stream.hardware_supported_by_codecs, "cuda, vaapi, vdpau, vulkan")
        self.assertEqual(len(stream.frame_buffer(0)), 640 * 480 * 3)

        # 指定外のエラー
        self.assertRaises(VIDEOError, stream.timestamp, index=100)
        self.assertRaises(VIDEOError, stream.frame_buffer, index=100)


if __name__ == "__main__":
    unittest.main()

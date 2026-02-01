"""
デレステ譜面ファイル作成アプリで使用するフォルダ・ファイルを準備する。
"""

from pathlib import Path

# 設定ファイル
CONFIG_FILENAME: str = "config/config.toml"
# デレステ動画ファイル置き場
INPUT_FOLDER: str = "input"
# デレステ譜面ファイルの置き場
OUTPUT_FOLDER: str = "output"

CONFIG_CONTENT: str = """
# シーク移動量の文字列の配列
# 例：steps = ["-300", "-60", "-10", "-5", "-1", "+1", "+5", "+10", "+60", "+300"]
steps = ["-300", "-60", "-10", "-5", "-1", "+1", "+5", "+10", "+60", "+300"]
# デレステ動画ファイルのファイルタイプ
# 例：filetype = "mp4"
filetype = "mp4"
# デレステ動画データのデコード用ハードウェアアクセラレータタイプ
# - "software"は、ハードウェア支援なしのデコード。
# - "cuda"は、CUDAを使ってデコード。
# - "vaapi"は、Intel GPUを使ってデコード。
# - "vdpau"は、NVIDIA GPUを使ってデコード。
# - "vulkan"は、各種GPUを使ってデコード。
# 例：accelerator = "cuda"
accelerator = "cuda"
"""


def setup_folders() -> None:
    """
    フォルダを準備する。
    """
    Path(OUTPUT_FOLDER).mkdir(exist_ok=True)
    Path(INPUT_FOLDER).mkdir(exist_ok=True)
    Path(CONFIG_FILENAME).parent.mkdir(exist_ok=True)


def setup_files() -> None:
    """
    ファイルを準備する。
    """
    Path(CONFIG_FILENAME).write_text(CONFIG_CONTENT)


def main() -> None:
    """
    必要なフォルダとファイルを準備する。
    """
    setup_folders()
    setup_files()


if __name__ == "__main__":
    print(__file__)

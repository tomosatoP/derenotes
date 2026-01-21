"""
動画ファイルから画像を取り出すためのモジュール。

:目的: ``入力`` から **任意のタイムスタンプ** の ``出力`` を取り出す。

:入力: デレステのオートLIVEを録画した動画ファイル

    - 動画ファイルの形式: ``MP4``
    - エンコード形式: ``H.264/AVC``

:出力: ``kivy.graphics.texture`` への入力を前提にした画像フレーム（バッファ）

    - ピクセルフォーマット: ``rgb24``
    - データ型: ``uint8`` 配列

:手段: FFMpeg共有ライブラリィから目的に合った機能を呼び出す。以下の機能は、取り扱わない。

    #. 画像のエンコード
    #. 音声や字幕のエンコードおよびデコード

:背景: 可変フレームレートの動画ファイルのインデックス検索で問題があり、画像を取り出せなかった。
"""

from kivy.logger import Logger as videoLogger
import itertools

from fractions import Fraction
from typing import Iterator
from pathlib import Path

from cpython cimport Py_buffer
from libc.stdint cimport int64_t
import numpy as np

from ffmpeg.libavutil cimport (
    EAGAIN,
    AVERROR,
    AVERROR_EOF,
    AVMediaType,
    AVPixelFormat,
    AVBufferRef,
    AVPixFmtDescriptor,
    AVHWDeviceContext,
    av_version_info,
    avutil_version,
    avutil_configuration,
    avutil_license,
    av_frame_alloc,
    av_frame_free,
    av_frame_copy_props,
    av_get_pix_fmt_name,
    av_get_pix_fmt,
    av_frame_get_plane_buffer,
    av_pix_fmt_desc_get,
    av_pix_fmt_count_planes,
    av_buffer_ref,
    av_buffer_unref,
    av_hwdevice_get_type_name,
    av_hwdevice_find_type_by_name,
    av_hwdevice_ctx_create,
    av_hwframe_transfer_data,
    )
from ffmpeg.libavformat cimport (
    AVSEEK_FLAG_BACKWARD,
    AVInputFormat,
    avformat_version,
    avformat_configuration,
    avformat_license,
    av_find_input_format,
    avformat_open_input,
    avformat_find_stream_info,
    av_find_best_stream,
    avformat_close_input,
    av_read_frame,
    av_seek_frame,
    )
from ffmpeg.libavcodec cimport (
    AV_PKT_FLAG_KEY,
    AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX,
    AVCodecHWConfig,
    AVCodec,
    avcodec_version,
    avcodec_configuration,
    avcodec_license,
    avcodec_alloc_context3,
    avcodec_parameters_to_context,
    avcodec_open2,
    avcodec_free_context,
    av_packet_alloc,
    av_packet_free,
    av_packet_unref,
    avcodec_send_packet,
    avcodec_receive_frame,
    avcodec_flush_buffers,
    avcodec_get_hw_config,
    )
from ffmpeg.libswscale cimport (
    SWS_BILINEAR,
    swscale_version,
    swscale_configuration,
    swscale_license,
    sws_getCachedContext,
    sws_freeContext,
    sws_scale_frame,
    )


#### libvideo API用のエラーハンドラ
class VIDEOError(Exception):
    """
    videoモジュールのエラーハンドラ。
    """

    def __init__(self, *args):
        super().__init__(*args)

        videoLogger.error(f"VIDEOError: {args}")

#### libvideoで使っているFFMpeg関連共有ライブラリィの情報
def info_ffmpeg() -> None:
    """
    FFMpeg関連共有ライブラリィの情報をログ出力する。
    """

    videoLogger.info(f"libav version: {av_version_info().decode('utf-8')}")

    # libavutil
    videoLogger.info(f"libavutil version: {avutil_version()}")
    videoLogger.info(f"libavutil config: {avutil_configuration().decode('utf-8')}")
    videoLogger.info(f"libavutil license: {avutil_license().decode('utf-8')}")

    # libavformat
    videoLogger.info(f"libavformat version: {avformat_version()}")
    videoLogger.info(f"libavformat config: {avformat_configuration().decode('utf-8')}")
    videoLogger.info(f"libavformat license: {avformat_license().decode('utf-8')}")

    # libavcodec
    videoLogger.info(f"libavcodec version: {avcodec_version()}")
    videoLogger.info(f"libavcodec config: {avcodec_configuration().decode('utf-8')}")
    videoLogger.info(f"libavcodec license: {avcodec_license().decode('utf-8')}")

    # swscale
    videoLogger.info(f"libswscale version: {swscale_version()}")
    videoLogger.info(f"libswscale config: {swscale_configuration().decode('utf-8')}")
    videoLogger.info(f"libswscale license: {swscale_license().decode('utf-8')}")

#### コールバック関数
cdef AVPixelFormat _get_hw_format(AVCodecContext* ctx, const AVPixelFormat* fmts) noexcept:
    """
    ピクセルフォーマットを選択するコールバック関数。

    ハードウェアを使ったデコーダー用にピクセルフォーマットを選択するコールバック関数。

    :param AVCodecContext* ctx: デコーダー
    :param AVPixelFormat* fmts: ピクセルフォーマット候補リスト（配列）

        終端は、AVPixelFormat.AV_PIX_FMT_NONE
    :return: 選択されたピクセルフォーマット
    :rytpe: AVPixelFormat 
    """

    cdef AVHWDeviceContext* hw_device_ctx = <AVHWDeviceContext*>ctx.hw_device_ctx.data
    cdef AVPixelFormat hw_pix_fmt = av_get_pix_fmt(av_hwdevice_get_type_name(hw_device_ctx.type))

    videoLogger.debug(f"_get_hw_format: pix_fmt - {av_hwdevice_get_type_name(hw_device_ctx.type).decode('utf-8')}")

    for fmt in map(lambda i: fmts[i], itertools.count()):

        if fmt in [AVPixelFormat.AV_PIX_FMT_NONE, hw_pix_fmt]:
            return fmt
        elif fmt in [ctx.sw_pix_fmt]:
            return fmt

    return AVPixelFormat.AV_PIX_FMT_NONE


#### 画像ストリームのクラス
cdef class Stream:
    """
    画像ストリームを扱う。

    | デレステ動画ファイルの画像ストリームを扱う。
    | 画像ストリームから、任意のタイムスタンプに紐付いた画像フレーム（バッファ）を取り出す。

        - ピクセルフォーマット: ``rgb24``
        - データ型: ``uint8`` 配列

    音声および字幕のストリームは無視する。

    :param str url: url形式のデレステ動画ファイル名。
    :param str file_type: デレステ動画ファイルの形式。デフォルトは ``mp4`` 。
    :param str hardware: デコーダーに適用するハードウェア名。デフォルトは ``None`` 。

        ハードウェアデコーダーを有効にする場合は、ハードウェア名を指定する。

            例: "cuda", "vaapi", "vdpau", "vulkan" など
    :raises VIDEOError: 動画ファイルのオープンに失敗、ストリーム情報の取得に失敗、デコーダーの初期化に失敗など
    """

    def __cinit__(self, url: str, file_type: str = "mp4", hardware: str = None):

        cdef const AVInputFormat* input_format
        cdef const AVCodec* decodec

        info_ffmpeg()

        # setup AVFormatContext with AVInputFormat(default: "MP4")
        input_format = av_find_input_format(file_type.encode("utf-8"))

        if avformat_open_input(&self.format_context, url.encode("utf-8"), input_format, NULL) != 0:
            raise VIDEOError(f"{self.__class__.__name__} - avformat_open_input")
        
        if avformat_find_stream_info(self.format_context, NULL) < 0:
            raise VIDEOError(f"{self.__class__.__name__} - avformat_fine_stream_info")

        # setup AVCodecContext with AVCodec for best video stream
        self.best_stream_index = av_find_best_stream(self.format_context, AVMediaType.AVMEDIA_TYPE_VIDEO, -1, -1, &decodec, 0)
        if self.best_stream_index < 0:
            raise VIDEOError(f"{self.__class__.__name__} - av_finde_best_stream")
        
        self.stream = self.format_context.streams[self.best_stream_index]

        self.decodec_context = avcodec_alloc_context3(decodec)

        if avcodec_parameters_to_context(self.decodec_context, self.stream.codecpar) < 0:
            raise VIDEOError(f"{self.__class__.__name__} - avcodec_parameters_to_context")

        # ハードウェアデコーダーを有効化
        if hardware and self._Enable_hardware_decoder(hardware.encode('utf-8')):
            self._enabled_hardware = True
        else:
            self._enabled_hardware = False

        if avcodec_open2(self.decodec_context, decodec, NULL) < 0:
            raise VIDEOError(f"{self.__class__.__name__} - avcodec_open2")

        self.dump()

    def __init__(self, *args, **kwargs):
        # タイムテーブル（timestampをリスト化）を作成

        cdef _Packet packet
        cdef int i

        TIMETABLE = np.dtype([("pts", np.int64), ("dts", np.int64), ("flags", np.int8),])
        timetable = np.ndarray(self.stream.nb_frames, np.dtype(TIMETABLE))

        for i, packet in enumerate(self._iter_packet()):
            timetable[i]["pts"] = packet.entity.pts  # ここでは、デコード順
            timetable[i]["dts"] = packet.entity.dts
            timetable[i]["flags"] = 1 if packet.entity.flags & AV_PKT_FLAG_KEY else 0

        # 表示順でソート: Bフレーム有りの場合、デコード順(dts)と表示順(pts)が異なる
        self.timetable = np.sort(timetable, order="pts")

        videoLogger.debug(f"{self.__class__.__name__}: Timetable is ready.")

    def __del__(self):

        if self.decodec_context:
            if self.decodec_context.hw_device_ctx:
                av_buffer_unref(&self.decodec_context.hw_device_ctx)
            avcodec_free_context(&self.decodec_context)

        if self.format_context:
            avformat_close_input(&self.format_context)
        
        videoLogger.debug(f"{self.__class__.__name__}: Deleted.")

    cdef list[bytes] _hardwares_supported_by_codec(self):
        """
        ハードウェア名のリストを取得する。

        デコーダーのコーデックで利用可能なハードウェア名のリストを取得する。
        
        :return: 利用可能なハードウェアのリスト
        :rtype: list[bytes]
        """

        cdef AVCodecHWConfig* config
        hardwares = list()

        for i in itertools.count():
            config = avcodec_get_hw_config(self.decodec_context.codec, i)
            if config == NULL:
                break
            elif config.methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX:
                hardwares.append(av_hwdevice_get_type_name(config.device_type))
        
        return hardwares

    cdef bint _Enable_hardware_decoder(self, const char* hardware):
        """
        ハードウェアを有効にする。
        
        ハードウェアを利用可能にし、デコーダーに適用する。

        :param const char* hardware: 有効にしたいハードウェア名

            例: "cuda", "vaapi", "vdpau", "vulkan" など
        :return: 成功すればTrue、失敗すればFalse
        :rtype: bint
        :raise VIDEOError: ハードウェアデバイスの作成に失敗
        """

        cdef AVBufferRef* hw_device_ctx

        # 指定のハードウェアが、デコーダーのコーデックで利用可能かどうか調べる
        if hardware in self._hardwares_supported_by_codec():
            device_type = av_hwdevice_find_type_by_name(hardware)
        else:
            return False

        # デコーダーにコールバック関数（ハードウェア対応ピクセルフォーマットを返す）を登録
        self.decodec_context.get_format = &_get_hw_format

        # デコーダーにハードウェアデバイスコンテキストを登録
        if av_hwdevice_ctx_create(&hw_device_ctx, device_type, b"hardware", NULL, 0) < 0:
            raise VIDEOError(f"{self.__class__.__name__} - av_hwdevice_ctx_create {hardware}")

        self.decodec_context.hw_device_ctx = av_buffer_ref(hw_device_ctx)

        videoLogger.debug(f"{self.__class__.__name__}: Hardware {hardware.decode('utf-8')} acceleration decoder enabled.")

        return True

    def dump(self) -> None:
        """
        画像ストリームの情報をデバック用ログに出力する。
        """
        videoLogger.debug(f"{self.__class__.__name__}: Information")

        videoLogger.debug(f"  url                 - {self.video_path}")
        videoLogger.debug(f"  decoder             - {self.decoder_name}")
        videoLogger.debug(f"  pixel format        - {self.pixel_format}")
        videoLogger.debug(f"  frames - number     - {self.total_frames}")
        videoLogger.debug(f"  time base           - {self.time_base.numerator}/{self.time_base.denominator}")
        videoLogger.debug(f"  image size - width  - {self.width}")
        videoLogger.debug(f"  image size - height - {self.height}")
        videoLogger.debug(f"  hardware devices    - {self.hardware_supported_by_codecs}")

    @property
    def video_path(self) -> Path:
        """
        動画ファイルのパス。

        :return: 動画ファイルのパス
        :rtype: Path
        """

        return Path(self.format_context.url.decode("utf-8"))

    @property
    def total_frames(self) -> int:
        """
        動画ファイル内の総フレーム数。

        :return: 総フレーム数
        :rtype: int
        """

        return <int>self.stream.nb_frames
    
    @property
    def decoder_name(self) -> str:
        """
        デコーダー名。

        :return: デコーダー名
        :rtype: str
        """

        return self.decodec_context.codec.long_name.decode("utf-8")

    @property
    def width(self) -> int:
        """
        画像の幅。

        :return: 画像の幅
        :rtype: int
        """

        return self.decodec_context.width
    
    @property
    def height(self) -> int:
        """
        画像の高さ。

        :return: 画像の高さ
        :rtype: int
        """

        return self.decodec_context.height
    
    @property
    def pixel_format(self) -> str:
        """
        ピクセルフォーマット名。

        :return: ピクセルフォーマット名
        :rtype: str
        """

        return av_get_pix_fmt_name(self.decodec_context.pix_fmt).decode("utf-8")

    @property
    def time_base(self) -> Fraction:
        """
        時間単位（秒）。

        :return: 時間単位（秒）
        :rtype: Fraction（分子, 分母）
        """

        return Fraction(self.stream.time_base.num, self.stream.time_base.den)
    
    @property
    def hardware_supported_by_codecs(self) -> str:
        """
        デコーダーで利用可能なハードウェア名の一覧。

        :return: デコーダーで利用可能なハードウェア名の一覧
        :rtype: str
        """

        return ", ".join(list(map(lambda i: str(i, 'utf-8'), self._hardwares_supported_by_codec())))

    def timestamp(self, index: int) -> int:
        """
        画像フレームの ``index`` をタイムスタンプに変換する。
        
        :param int index: タイムスタンプを取得したい画像フレームのインデックス
        :return: 指定のインデックスの画像フレームのタイムスタンプ
        :rtype: int
        :raises VIDEOError: 指定のインデックスが範囲外
        """

        cdef int frame_index = index
        
        if frame_index < 0  or frame_index >= self.stream.nb_frames:
            raise VIDEOError(f"{self.__class__.__name__} - timestamp: Index out of bounds")

        return <int>self.timetable[frame_index].pts

    def nearby_keyframe_buffer(self, index: int, nearby_keyframe: int) -> bytes:
        """
        近傍のキーフレームの画像フレーム（バッファ）を読み出す。

        | ``index`` から ``nearby_keyframe`` （ ``GOP`` 単位）離れた近傍のIフレームの画像フレーム（バッファ）を読み出す。
        | 範囲外の場合には、"黒"画面相当の画像フレーム（バッファ）を返す。

        :param int index: 画像フレームのインデックス
        :param int nearby_frame: 近傍のキーフレームへの間隔（ ``GOP`` 単位）
        :return: 近傍のキーフレームの画像フレーム（バッファ）
        :rtype: bytes
        """

        # index前後のIフレームのインデックスを取得
        keyframes = np.flatnonzero(np.asarray(list(map(lambda element: element["flags"], self.timetable))))
        forward_keyframes = np.extract(keyframes > index, keyframes)
        backward_keyframes = np.extract(keyframes <= index, keyframes)

        if nearby_keyframe < 0 and abs(nearby_keyframe) <= len(backward_keyframes):  # backward
            return self.frame_buffer(backward_keyframes[nearby_keyframe])

        elif nearby_keyframe > 0 and nearby_keyframe <= len(forward_keyframes):  # forward
            return self.frame_buffer(forward_keyframes[nearby_keyframe - 1])

        elif nearby_keyframe == 0:
            return self.frame_buffer(index)

        else:  # 範囲外
            return self._black_frame_buffer()


    def frame_buffer(self, index: int) -> bytes:
        """
        画像フレーム（バッファ）を読み出す。

        | ``index`` に対応したタイムスタンプの画像フレーム（バッファ）を読み出す。
        | ``kivy.graphics.texture`` へ渡すこと前提に、ピクセルフォーマット ``rgb24`` および ``uint8`` 配列に整形し、
        | 画像フレームが見つからなかった際には、 **黒** 画面相当の画像フレーム（バッファ）を返す。
        | 範囲外のindexに対しては、エラー発生。

        :param int index: 読み出したい画像フレームのインデックス
        :return: 指定のインデックスの画像フレーム（バッファ）
        :rtype: bytes
        :raises VIDEOError: 指定のインデックスが範囲外、ハードウェアデコーダー向けのデータ変換に失敗
        """

        cdef _Frame frame
        cdef _Frame frame_software = _Frame()
        cdef _Frame frame_rgb24
        cdef _Swscale swscale = _Swscale()
        cdef int frame_index = index


        if frame_index < 0  or frame_index >= self.stream.nb_frames:
            raise VIDEOError(f"{self.__class__.__name__}.frame_buffer: Index out of bounds")

        # 直前のキーフレームへシーク
        self._seek_keyframe(self.timetable[frame_index].pts)
        
        for frame in self._iter_frame():
            if frame.entity.pts == self.timetable[frame_index].pts:

                frame.dump()

                # ピクセルフォーマット"rgb24"のフレームに変換
                if self._enabled_hardware:
                    # ハードウェアサーフェスからデータをコピー、最初に許容されるピクセルフォーマットへ変換
                    if av_hwframe_transfer_data(frame_software.entity, frame.entity, 0) < 0:
                        raise VIDEOError(f"{self.__class__.__name__}.frame_buffer: hwframe transfer data")
                    av_frame_copy_props(frame_software.entity, frame.entity)

                    frame_software.dump()
                    frame_rgb24 = swscale.rgb24(frame_software)
                else:
                    frame_rgb24 = swscale.rgb24(frame)

                frame_rgb24.dump()

                # フレームのデータをバイト列（RGB24 * width * hight）に変換
                np_frame_buffer = np.frombuffer(_Plane(frame_rgb24, 0), dtype=np.dtype([('R','u1'), ('G','u1'), ('B','u1')]))
                np_frame_buffer = np_frame_buffer.reshape((-1, frame_rgb24.entity.linesize[0] // 3))[:, 0:frame_rgb24.entity.width]
                np_frame_buffer = np.flipud(np_frame_buffer).reshape(-1)
                
                return np_frame_buffer.view(np.uint8).tobytes()
        
        # フレームが見つからなかったら、とりあえず黒い画像を提供
        videoLogger.debug(f"{self.__class__.__name__}: frame_buffer - _Frame was not found. index: {frame_index}")
        return self._black_frame_buffer()
    
    cdef bytes _black_frame_buffer(self):
        """
        黒い画面相当の画像フレーム（バッファ）を提供する。

        ``kivy.graphics.texture`` へ渡すこと前提に、ピクセルフォーマット ``rgb24`` 相当の ``uint8`` 配列を返す。

        :return: **黒** 画面相当の画像フレーム（バッファ）
        :rtype: bytes
        """
        return np.zeros(self.width * self.height * 3, dtype=np.uint8).tobytes()

    cdef void _drain_codec(self):
        """
        ドレインモード

        ストリームを終了し、デコーダーの状態をリセット＆バッファを空にする。
        ストリームの終端時、シークする前、ストリームの変更前に行う。
        """
        cdef _Frame frame = _Frame()

        avcodec_send_packet(self.decodec_context, NULL) # 常に成功、コーデックのドレインモードの開始
        while avcodec_receive_frame(self.decodec_context, frame.entity) != AVERROR_EOF: pass
        avcodec_flush_buffers(self.decodec_context)

    cdef void _seek_keyframe(self, int64_t timestamp):
        """
        指定のタイムスタンプの ``_Frame`` までシークする。

        次の手順でシークする。

            - 指定のタイムスタンプの ``_Frame`` を含む ``GOP`` のキーフレーム（Iフレーム）へシークする。
                キーフレーム（Iフレーム）以外のフレームをデコードするため、``GOP`` のキーフレームをデコーダに送信する。
            - 指定のタイムスタンプの ``_Frame`` への移動を行う。

        :param int64_t timestamp: シーク先のタイムスタンプ
        :raises VIDEOError: シークに失敗
        """

        if av_seek_frame(self.format_context, self.best_stream_index, timestamp, AVSEEK_FLAG_BACKWARD) < 0:
            raise VIDEOError(f"{self.__class__.__name__} - av_seek_frame")

        self._drain_codec()

    def _iter_frame(self) -> Iterator[_Frame]:
        """
        ``_Frame`` を反復して取り出す。

        ``_Packet`` 経由で、デコード済み ``_Frame`` を取り出すイテレータを返す。

        :return: デコード済み ``_Frame`` のイテレータ
        :rtype: Iterator[_Frame]
        """

        cdef _Packet packet
        cdef _Frame frame

        for packet in self._iter_packet():
            for frame in packet.decode():
                yield frame

    def _iter_packet(self) -> Iterator[_Packet]:
        """
        ``_Packet`` を反復して取り出す。

        ``_Packet`` を取得するイテレータを返す。

        :return: ``_Packet`` のイテレータ
        :rtype: Iterator[_Packet]
        """

        cdef _Packet packet = _Packet(self)

        # パケットの読み込みループ
        # TRUE（パケットを読み込んだ）：パケットの所属先の確認へ
        # FALSE（エラーまたはファイル終端）：ドレインモードへ
        while av_read_frame(self.format_context, packet.entity) == 0:

            # パケットの所属先の確認
            # TRUE（パケットがストリームの所属だった）：パケットを返す（呼び出し元でデコーダーにパケットを送信）
            # FALSE（上記以外）：何もしない
            if packet.entity.stream_index == self.best_stream_index:

                # パケットのタイムベースをストリームのタイムベースに設定
                packet.entity.time_base = self.stream.time_base
                yield packet
            
            av_packet_unref(packet.entity)
        
        self._drain_codec()


#### 画像パケットのクラス
cdef class _Packet:
    """
    画像ストリームのパケットを扱う。
    
    クラス ``Stream`` のインスタンスから呼び出され、デコーダー経由でクラス ``_Frame`` のデコード済みインスタンスを提供する。
    
    :param Stream stream: 呼び出し元のクラス ``Stream`` のインスタンス
    """
    
    def __cinit__(self, stream: Stream):
        
        # setup AVPacket
        self.entity = av_packet_alloc()
        # setup AVCodecContext
        self.decode_context = stream.decodec_context
        
        self.dump()

    def __del__(self):

        if (self.entity):
            av_packet_free(&self.entity)

        videoLogger.debug(f"{self.__class__.__name__}: Deleted.")

    def decode(self) -> list[_Frame]:
        """
        ``_Frame`` のインスタンスのリストを返す。

        デコードされた ``_Frame`` のインスタンスのリストを返す。
        ``VIDEO`` の場合は、単一の ``_Frame`` であることがほとんどらしい。

        :return: デコードされた ``_Frame`` のインスタンスのリスト
        :rtype: list[_Frame]
        """

        cdef _Frame frame
        frames = list()

        # パケットをデコーダーに送信
        # 戻り値が０（デコーダーがパケットを受信した）："フレームをデコードするループ"へ入る
        # 戻り値がAVERROR(EAGAIN)（デコーダーがパケットを受信できない状態）：ドレインモードへ
        # 戻り値がAVERROR_EOF（デコーダーはフラッシュ済み）：ドレインモードへ
        # 戻り値がAVERROR(EINVAL)（デコーダーが開かれていない）：ドレインモードへ
        # 戻り値がAVERROR(ENOMEM)（デコーダーがパケットの受信に失敗）：ドレインモードへ
        # 戻り値が上記以外の負値（その他のデコーダーエラー）：ドレインモードへ
        if avcodec_send_packet(self.decode_context, self.entity) == 0:

            while True:
                frame = self.receive_frame()
                if isinstance(frame, _Frame):
                    frames.append(frame)
                else:
                    break
        
        return frames

    cdef _Frame receive_frame(self):
        """
        デコーダーからデコードされた ``_Frame`` を受け取る

        :return: デコードされた ``_Frame`` のインスタンス
        :rtype: _Frame
        :raises VIDEOError: デコーダーから ``_Frame`` の受け取りに失敗
        """

        cdef _Frame frame = _Frame()

        # デコーダーからフレームを受信
        cdef int res = avcodec_receive_frame(self.decode_context, frame.entity)
        if res == 0:
            # 受け取りに成功
            # この後、AVERROR_EOFになるまでデコーダーから繰り返しフレームを受け取る
            frame.entity.time_base = self.entity.time_base
            return frame
        elif res in (AVERROR_EOF, AVERROR(EAGAIN)):
            # AVERROR_EOFの場合、デコーダーからフレームをすべて受け取り終えた
            # AVERROR(EAGAIN)の場合、デコーダーにパケットが送信されていなかったかもしれない
            # この後、デコーダーに新しいパケットを送信
            return
        else:
            raise VIDEOError(f"{self.__class__.__name__} - avcodec_receive_frame")

    def dump(self) -> None:
        """
        情報をデバッグ用ログに一覧出力する。
        """

        videoLogger.debug(f"{self.__class__.__name__}: Information")

        videoLogger.debug(f"  pts          - {self.entity.pts}")
        videoLogger.debug(f"  dts          - {self.entity.dts}")
        videoLogger.debug(f"  duration     - {self.entity.duration}")
        videoLogger.debug(f"  flags        - {self.entity.flags}")
        videoLogger.debug(f"  stream index - {self.entity.stream_index}")
        videoLogger.debug(f"  time base    - {self.entity.time_base.num}/{self.entity.time_base.den}")


#### 画像フレームのクラス
cdef class _Frame:
    """
    画像ストリームのフレームを扱う。

    クラス ``_Packet`` のインスタンスから呼ばれて、クラス ``Stream`` のインスタンスに渡される。
    ``FFMpeg`` の ``AVFrame`` は再利用を前提としているが、このクラスは使い切りなので、``av_frame_unref()`` を実装していない。
    """

    def __cinit__(self):

        # setup AVFrame
        self.entity = av_frame_alloc()

        videoLogger.debug(f"{self.__class__.__name__}: Initialized.")

    def __del__(self):

        if self.entity:
            av_frame_free(&self.entity)

        videoLogger.debug(f"{self.__class__.__name__}: Deleted.")

    def dump(self):
        """
        情報をデバッグ用ログに一覧出力する。

            - AVPixFmtDesctriptor
            - AVComponentDescriptor
            - AVFrame
        """
        
        videoLogger.debug(f"{self.__class__.__name__}: infomations")

        videoLogger.debug(f"  AVPixFmtDescritor")
        cdef const AVPixFmtDescriptor* pix_fmt_desc = av_pix_fmt_desc_get(<AVPixelFormat>self.entity.format)
        videoLogger.debug(f"    name              - {pix_fmt_desc.name.decode()}")
        videoLogger.debug(f"    components number - {pix_fmt_desc.nb_components}")
        videoLogger.debug(f"    flags             - {pix_fmt_desc.flags}")

        videoLogger.debug(f"  AVComponentDescriptor")
        pix_desc_planes = list()
        pix_desc_steps = list()
        pix_desc_offsets = list()
        pix_desc_shifts = list()
        pix_desc_depths = list()
        for i in range(pix_fmt_desc.nb_components):
            pix_desc_planes.append(pix_fmt_desc.comp[i].plane)
            pix_desc_steps.append(pix_fmt_desc.comp[i].step)
            pix_desc_offsets.append(pix_fmt_desc.comp[i].offset)
            pix_desc_shifts.append(pix_fmt_desc.comp[i].shift)
            pix_desc_depths.append(pix_fmt_desc.comp[i].depth)

        videoLogger.debug(f"    plane  - {tuple(pix_desc_planes)}")
        videoLogger.debug(f"    step   - {tuple(pix_desc_steps)}")
        videoLogger.debug(f"    offset - {tuple(pix_desc_offsets)}")
        videoLogger.debug(f"    shift  - {tuple(pix_desc_shifts)}")
        videoLogger.debug(f"    depth  - {tuple(pix_desc_depths)}")

        planes = list()
        for i in range(<int>av_pix_fmt_count_planes(<AVPixelFormat>self.entity.format)):
            planes.append(self.entity.buf[0][i].size)
        videoLogger.debug(f"  buf - size - {tuple(planes)}")

        linesizes = list()
        for i in range(len(self.entity.linesize)):
            linesizes.append(self.entity.linesize[i])
        videoLogger.debug(f"  linesize  - {tuple(linesizes)}")
        videoLogger.debug(f"  key_frame - {self.entity.key_frame}")
        # コンパイル時に警告（非推奨："AV_FRAME_FLAG_KEY"を推奨）となるが、最新版では"AV_FRAME_FLAG_KEY"が廃止
        videoLogger.debug(f"  time_base - {self.entity.time_base.num}/{self.entity.time_base.den}")
        videoLogger.debug(f"  pts       - {self.entity.pts}")
        videoLogger.debug(f"  pkt_dts   - {self.entity.pkt_dts}")
        videoLogger.debug(f"  duration  - {self.entity.pkt_duration}")
        # コンパイル時に警告（非推奨："duration"を推奨）となるが、最新版では"duration"が廃止
        videoLogger.debug(f"  width     - {self.entity.width}")
        videoLogger.debug(f"  height    - {self.entity.height}")


#### 画像フレームのピクセルフォーマットを"RGB24"に変換するクラス
cdef class _Swscale:
    """
    ``_Frame`` のピクセルフォーマット形式変換を扱う。

    ``FFMpeg`` の ``_Swscale``（画像フレームのピクセルフォーマットやサイズなどを変換）をラップして、
    機能の中からピクセルフォーマットを ``RGB24`` に変換する機能のみを実装
    """

    def __del__(self):
        
        if self.sws_context:
            sws_freeContext(self.sws_context)

        videoLogger.debug(f"{self.__class__.__name__}: Deleted.")

    cdef _Frame rgb24(self, _Frame frame):
        """
        ピクセルフォーマットを ``RGB24`` に変換する。

        :param _Frame frame: 入力フレーム
        :return: ピクセルフォーマットを ``RGB24`` に変換した出力フレーム
        :rtype: _Frame
        """

        cdef _Frame frame_rgb24 = _Frame()

        av_frame_copy_props(frame_rgb24.entity, frame.entity)

        self.sws_context = sws_getCachedContext(
            self.sws_context,
            frame.entity.width,
            frame.entity.height,
            <AVPixelFormat>frame.entity.format,
            frame.entity.width,
            frame.entity.height,
            AVPixelFormat.AV_PIX_FMT_RGB24,
            SWS_BILINEAR,
            NULL,
            NULL,
            NULL)

        sws_scale_frame(self.sws_context, frame_rgb24.entity, frame.entity)

        return frame_rgb24        

#### 画像フレームの平面を管理および操作するクラス
cdef class _Plane:
    """
    ``_Frame`` の平面を扱う。

    ``_Frame`` の平面（色空間の成分別の配列）を扱う。

        - **YUV形式( ``planer`` )** では、**Y,U,V** の3平面
        - **RGB24形式** は **RGB** にまとめた ``packed`` なので、1平面のみ

    :param _Frame frame: 呼び出し元の ``_Frame`` クラス
    :param int index: 平面のインデックス
    :todo: ピクセルフォーマット **RGB24** のフレームのみ受け付ける
    """

    def __cinit__(self, frame: _Frame, index: int):

        self.frame = frame
        self.index = index

        videoLogger.debug(f"{self.__class__.__name__}: Initialized.")

    def __del__(self):
        # '__releasebuffer__`の実装が推奨だけど、バッファを移動させないので省略

        videoLogger.debug(f"{self.__class__.__name__}: Deleted.")

    def __getbuffer__(self, Py_buffer* view, int flags):
        """
        バッファリクエストへの応答
        
        バッファプロトコルに即して、memoryviewオブジェクトのバッファリクエストへの応答として平面のバッファを提供する
            - ピクセルフォーマット"RGB24"に限定して実装
            - 長さ: `linesize[index] * height`バイト
            - フォーマット（要素）: "BBB"（`RGB`3バイト）
        
        :param Py_buffer* view: バッファ情報を格納する構造体へのポインタ
        :param int flags: バッファの要求フラグ（呼び出し側から指定する方法が不明）
        :note: 事前にピクセルフォーマットを"RGB24"に変換しておく必要がある
        """

        cdef AVBufferRef* buffer = av_frame_get_plane_buffer(self.frame.entity, self.index)
        if buffer == NULL:
            raise VIDEOError(f"{self.__class__.__name__} - av_frame_get_plane_buffer")

        # バッファ構造体の`shape`配列、次元数だけ確保
        cdef Py_ssize_t [1] shape

        # バッファ構造体を埋める
        view.obj = self
        # メモリ配列
        view.buf = buffer.data
        # 要素の内容を示すstrcutモジュール形式（下記を参照）の構文で記述されたNULL終端文字列
        # ピクセルフォーマット`rgb24`を前提に"BBB"とした
        # https://docs.python.org/ja/3.12/library/struct.html#format-characters
        view.format = "BBB"
        # メモリ配列以内で、"product(shape) * itemsize"と一致させる
        # メモリ配列から余分に確保されている部分を除いた長さとする
        # ただし、`liensize`は32の倍数規制となっているので、後から不要部分を削除する必要あり
        view.len = self.frame.entity.linesize[self.index] * self.frame.entity.height
        # 要素のサイズ（バイト数）
        view.itemsize = sizeof(uint8_t) * 3
        # 書き込み可能かどうか
        view.readonly = 0
        # 次元数、最大値は`PyBUF_MAX_NDIM（64）`
        view.ndim = 1
        # 各次元の要素数
        shape[0] = (view.len // view.itemsize)
        view.shape = shape
        # 各次元のステップ数（バイト数）
        view.strides = &view.itemsize
        view.suboffsets = NULL
        view.internal = NULL

        videoLogger.debug(f"{self.__class__.__name__}: Responded to the buffer request.")
        
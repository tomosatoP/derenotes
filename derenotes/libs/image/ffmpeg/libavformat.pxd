"""
libavformatライブラリィのCython用定義ファイル

対象ライブラリィに含まれるC関数、構造体などの中から、Cythonで呼び出すC関数、構造体などを登録する

libavformat/avformat.h
"""

from libc.stdint cimport int64_t
from libavutil cimport AVDictionary, AVMediaType, AVRational
from libavcodec cimport AVCodec, AVCodecID, AVCodecParameters, AVPacket


cdef extern from "libavformat/avformat.h" nogil:

    cdef int AVSEEK_FLAG_BACKWARD
    cdef int AVSEEK_FLAG_BYTE
    cdef int AVSEEK_FLAG_ANY
    cdef int AVSEEK_FLAG_FRAME
    
    unsigned int avformat_version()
    const char* avformat_configuration()
    const char* avformat_license()

    ctypedef struct AVFormatContext:
        const AVInputFormat* iformat
        unsigned int nb_streams
        AVStream** streams
        char* url
        int64_t start_time
        int64_t duration
        int64_t bit_rate
        AVCodecID video_codec_id
        int64_t start_time_realtime

    ctypedef struct AVInputFormat:
        pass

    ctypedef struct AVStream:
        int index
        int id
        AVCodecParameters* codecpar
        int64_t nb_frames
        AVRational time_base

    ctypedef struct AFProgram:
        pass

    ctypedef struct AFChapter:
        pass

    AVFormatContext* avformat_alloc_context()

    void avformat_free_context(AVFormatContext* s)

    int avformat_open_input(
        AVFormatContext** ps,
        const char* url,
        AVInputFormat* fmt,
        AVDictionary** options)

    int avformat_find_stream_info(
        AVFormatContext* ic,
        AVDictionary** options)

    void avformat_close_input(AVFormatContext** s)

    const AVInputFormat* av_find_input_format(const char* short_name)

    int av_find_best_stream(
        AVFormatContext *ic,
        AVMediaType type,
        int wanted_stream_nb,
        int related_stream,
        const AVCodec **decoder_ret,
        int flags)

    void av_dump_format(
        AVFormatContext* ic,
        int index,
        const char* url,
        int is_output)

    int av_read_frame(AVFormatContext* s, AVPacket* pkt)

    int av_seek_frame(
        AVFormatContext* s,
        int stream_index,
        int64_t timestamp,
        int flags)


"""
libavcodecライブラリィのCython用定義ファイル

対象ライブラリィに含まれるC関数、構造体などの中から、Cythonで呼び出すC関数、構造体などを登録する

libavcodec/avcodec.h
libavcodec/codec.h
libavcodec/packet.h
libavcodec/codec_par.h
"""

from libc.stdint cimport int64_t
from libavutil cimport AVMediaType, AVFrame, AVDictionary, AVPixelFormat, AVRational, AVHWDeviceType, AVBufferRef

cdef extern from "libavcodec/avcodec.h" nogil:

    enum AVCodecID:
        AV_CODEC_ID_NONE
        AV_CODEC_ID_H264

    unsigned int avcodec_version()
    const char* avcodec_configuration()
    const char* avcodec_license()

    ctypedef struct AVCodecContext:
        AVMediaType codec_type
        AVCodec *codec
        AVCodecID codec_id
        int width
        int height
        AVPixelFormat pix_fmt
        AVBufferRef* hw_device_ctx
        AVBufferRef* hw_frames_ctx
        AVPixelFormat sw_pix_fmt
        AVPixelFormat (*get_format)(AVCodecContext* s, const AVPixelFormat* fmts) 

    AVCodecContext* avcodec_alloc_context3(const AVCodec* codec)

    void avcodec_free_context(AVCodecContext** avctx)

    int avcodec_parameters_to_context(
        AVCodecContext* codec,
        const AVCodecParameters* par)

    int avcodec_open2(
        AVCodecContext* avctx,
        const AVCodec* codec,
        AVDictionary** options)

    int avcodec_close(AVCodecContext* avctx)

    int avcodec_send_packet(
        AVCodecContext* avctx,
        const AVPacket* avpkt)

    int avcodec_receive_frame(
        AVCodecContext *avctx,
        AVFrame *frame)

    void avcodec_flush_buffers(AVCodecContext* avctx)

cdef extern from "libavcodec/codec.h" nogil:

    int AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX
    int AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX
    int AV_CODEC_HW_CONFIG_METHOD_INTERNAL
    int AV_CODEC_HW_CONFIG_METHOD_AD_HOC

    struct AVCodec:
        const char* name
        const char* long_name
        AVMediaType type
        AVCodecID id

    struct AVProfile:
        pass

    ctypedef struct AVCodecHWConfig:
        AVPixelFormat pix_fmt
        int methods
        AVHWDeviceType device_type

    const AVCodecHWConfig* avcodec_get_hw_config(const AVCodec* codec, int index)
    AVCodec* avcodec_find_decoder(AVCodecID id)

cdef extern from "libavcodec/packet.h" nogil:

    int AV_PKT_FLAG_KEY
    int AV_PKT_FLAG_CORRUPT
    int AV_PKT_FLAG_DISCARD
    int AV_PKT_FLAG_TRUSTED
    int AV_PKT_FLAG_DISPOSABLE

    ctypedef struct AVPacket:
        int64_t pts
        int64_t dts
        int stream_index
        int flags
        int64_t duration
        AVRational time_base

    AVPacket* av_packet_alloc()

    void av_packet_free(AVPacket** src)

    int av_packet_ref(AVPacket* dst, AVPacket* src)

    void av_packet_unref(AVPacket* pkt)

cdef extern from "libavcodec/codec_par.h" nogil:

    ctypedef struct AVCodecParameters:
        AVMediaType codec_type
        AVCodecID codec_id
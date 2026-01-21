"""
libavutilライブラリィのCython用定義ファイル

対象ライブラリィに含まれるC関数、構造体などの中から、Cythonで呼び出すC関数、構造体などを登録する

libavutil/avutil.h
libavutil/rational.h
libavutil/mathematics.h
libavutil/dict.h
libavutil/frame.h
libavutil/pixfmt.h
libavutil/pixdesc.h
libavutil/imgutils.h
libavutil/buffer.h
libavutil/error.h
libavutil/hwcontext.h
"""

from libc.stdint cimport uint8_t, int64_t


cdef extern from "libavutil/avutil.h" nogil:

    enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN
        AVMEDIA_TYPE_VIDEO
        AVMEDIA_TYPE_AUDIO
        AVMEDIA_TYPE_DATA
        AVMEDIA_TYPE_SUBTITLE
        AVMEDIA_TYPE_ATTACHMENT
        AVMEDIA_TYPE_NB

    enum AVPictureType:
        AV_PICTURE_TYPE_NONE
        AV_PICTURE_TYPE_I
        AV_PICTURE_TYPE_P
        AV_PICTURE_TYPE_B
        AV_PICTURE_TYPE_S
        AV_PICTURE_TYPE_SI
        AV_PICTURE_TYPE_SP
        AV_PICTURE_TYPE_BI

    const char* av_version_info()

    unsigned int avutil_version()
    const char* avutil_configuration()
    const char* avutil_license()

    const char* av_get_media_type_string(AVMediaType media_type)

cdef extern from "libavutil/rational.h" nogil:
    
    ctypedef struct AVRational:
        int num
        int den

cdef extern from "libavutil/mathematics.h" nogil:
    pass

cdef extern from "libavutil/dict.h" nogil:
    
    ctypedef struct AVDictionary:
        pass

cdef extern from "libavutil/frame.h" nogil:

    const int AV_NUM_DATA_POINTERS

    ctypedef struct AVFrame:
        uint8_t* data[AV_NUM_DATA_POINTERS]
        int linesize[AV_NUM_DATA_POINTERS]
        uint8_t** extended_data
        int format
        bint key_frame
        AVPictureType pict_type
        AVRational time_base
        int64_t pts
        int64_t pkt_dts
        AVRational time_base
        AVBufferRef* buf[AV_NUM_DATA_POINTERS]
        int64_t pkt_duration
        int width
        int height

    AVFrame* av_frame_alloc()
    int av_frame_copy_props(AVFrame* dst, const AVFrame* src)
    void av_frame_unref(AVFrame* frame)
    void av_frame_free(AVFrame** frame)

    AVBufferRef* av_frame_get_plane_buffer(const AVFrame* frame, int plane)

cdef extern from "libavutil/pixfmt.h" nogil:

    enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P
        AV_PIX_FMT_RGB24
        AV_PIX_FMT_CUDA
        AV_PIX_FMT_VAAPI
        AV_PIX_FMT_VDPAU
        AV_PIX_FMT_VULKAN

cdef extern from "libavutil/pixdesc.h" nogil:

    ctypedef struct AVComponentDescriptor:
        int plane
        int step
        int offset
        int shift
        int depth

    ctypedef struct AVPixFmtDescriptor:
        const char* name
        uint8_t nb_components
        uint8_t flags
        AVComponentDescriptor[4] comp

    const AVPixFmtDescriptor* av_pix_fmt_desc_get(AVPixelFormat pix_fmt)
    const char* av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    AVPixelFormat av_get_pix_fmt(const char* name)
    int av_pix_fmt_count_planes(AVPixelFormat pix_fmt)

cdef extern from "libavutil/imgutils.h" nogil:

    # av_free(&pointers[0]) で開放
    int av_image_alloc(
        uint8_t* pointers[4],
        int linesizes[4],
        int w,
        int h,
        AVPixelFormat pix_fmt,
        int align)

cdef extern from "libavutil/buffer.h" nogil:

    ctypedef struct AVBuffer:
        pass

    ctypedef struct AVBufferRef:

        AVBuffer* buffer
        uint8_t* data
        size_t size

    AVBufferRef* av_buffer_ref(const AVBufferRef* buf)
    void av_buffer_unref(AVBufferRef** buf)

cdef extern from "libavutil/error.h" nogil:

    # POSIX Error code
    int EAGAIN
    int AVERROR(int error)

    int AVERROR_EOF

cdef extern from "libavutil/hwcontext.h" nogil:

    enum AVHWDeviceType:
        AV_HWDEVICE_TYPE_NONE
    
    enum AVHWFrameTransferDirection:
        AV_HWFRAME_TRANSFER_DIRECTION_FROM
        AV_HWFRAME_TRANSFER_DIRECTION_TO

    ctypedef struct AVHWDeviceInternal:

        #const HWContextType* hw_type
        void* priv
        AVBufferRef* source_device

    ctypedef struct AVHWDeviceContext:

        AVHWDeviceInternal* internal
        AVHWDeviceType type
        void* hwctx
        

    AVHWDeviceType av_hwdevice_iterate_types(AVHWDeviceType prev)
    const char* av_hwdevice_get_type_name(AVHWDeviceType type)
    AVHWDeviceType av_hwdevice_find_type_by_name(const char* name)
    int av_hwdevice_ctx_create(AVBufferRef** device_ctx, AVHWDeviceType type, const char* device, AVDictionary* opts, int flags)
    int av_hwframe_transfer_data(AVFrame* dst, const AVFrame* src, int flags)
    int av_hwframe_transfer_get_formats(AVBufferRef* hwframe_ctx, AVHWFrameTransferDirection dir, AVPixelFormat** formats, int flags)

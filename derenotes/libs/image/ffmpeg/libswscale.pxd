"""
libswscaleライブラリィのCython用定義ファイル

対象ライブラリィに含まれるC関数、構造体などの中から、Cythonで呼び出すC関数、構造体などを登録する

libswscale/swscale.h
"""

from libavutil cimport AVFrame, AVPixelFormat

cdef extern from "libswscale/swscale.h" nogil:

    # 補完方式：サイズ変更はしないので一つだけ定義
    int SWS_BILINEAR

    ctypedef struct SwsFilter:
        pass

    struct SwsContext:
        pass

    unsigned int swscale_version()
    const char* swscale_configuration()
    const char* swscale_license()

    SwsContext* sws_getCachedContext(
        SwsContext* context,
        int srcW,
        int srcH,
        AVPixelFormat srcFormat,
        int dstW,
        int dstH,
        AVPixelFormat dstFromat,
        int flags,
        SwsFilter* srcFilter,
        SwsFilter* dstFilter,
        const double* param)

    SwsContext* sws_getContext(
        int srcW,
        int srcH,
        AVPixelFormat srcFormat,
        int dstW,
        int dstH,
        AVPixelFormat dstFormat,
        int flags,
        SwsFilter srcFilter,
        SwsFilter dstFilter,
        const double* param)

    void sws_freeContext(SwsContext* swsContext)

    int sws_scale_frame(
        SwsContext* c,
        AVFrame* dst,
        const AVFrame* src)

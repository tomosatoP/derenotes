"""libvideo.pxd"""

from libc.stdint cimport int64_t, int8_t, uint8_t

from ffmpeg.libavutil cimport AVFrame
from ffmpeg.libavformat cimport AVFormatContext, AVStream
from ffmpeg.libavcodec cimport AVCodecContext, AVPacket
from ffmpeg.libswscale cimport SwsContext

cdef packed struct timetable:
    int64_t pts
    int64_t dts
    int8_t flags

cdef class Stream:

    cdef AVFormatContext* format_context
    cdef AVCodecContext* decodec_context
    cdef AVStream* stream
    cdef bint _enabled_hardware
    cdef int best_stream_index
    cdef timetable [:] timetable

    cdef list[bytes] _hardwares_supported_by_codec(self)
    cdef bint _Enable_hardware_decoder(self, const char* hardware)
    cdef bytes _black_frame_buffer(self)
    cdef void _drain_codec(self)
    cdef void _seek_keyframe(self, int64_t timestamp)

cdef class _Packet:

    cdef AVPacket* entity
    cdef AVCodecContext* decode_context

    cdef _Frame receive_frame(self)

cdef class _Frame:

    cdef AVFrame* entity

cdef class _Swscale:

    cdef SwsContext* sws_context

    cdef _Frame rgb24(self, _Frame frame)

cdef class _Plane:

    cdef _Frame frame
    cdef int index
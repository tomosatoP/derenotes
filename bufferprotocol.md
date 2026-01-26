# バッファプロトコル

<https://docs.python.org/ja/3.12/c-api/buffer.html>

C言語などが扱う`メモリ配列`は、Pythonの`配列`として扱えない。
Pythonのバッファプロトコルは、`メモリ配列`を`配列`の様に扱う方法を提供する。

~~~mermaid
flowchart LR
    a[**Byte単位以外のメモリ配列**]
    b[**バッファ型**]
    c[**メモリビュー**]
    f[**配列**]
    d[Byte単位のメモリ配列]
    e[bytes, bytearray]

    a == **4** ==> b == **4** ==> c == **4** ==> f
    d -- 1 --> e -- 1 --> f
    d -- 2 --> e -- 2 --> c -- 2 --> f
    d -- 3 --> e -- 3 --> b -- 3 --> c -- 3 --> f
~~~

> `derenotes/libs/image/video.pyx` の `class _Plane` にて、 `AVFrame` から `plane` メモリ配列を取り出すのに使った。

## メモリビュー

Pythonの`memoryview`は、バッファプロトコルを介して`メモリ配列`にアクセスする。

## バッファ型

バイト列ならば`bytes`や`bytearray`がバッファプロトコルとして機能するが、バイト列以外の要素では要素の型に対応した`バッファ型`をバッファプロトコルに即して提供する必要がある

### バッファ構造体 (buffer structure) - Py_buffer

<https://docs.python.org/ja/3.12/c-api/buffer.html#buffer-structure>

~~~c
#define PyBUF_MAX_NDIM 64
typedef Py_buffer {
    void* buf;               # flagsの影響を受けない
    PyObject* obj;           # flagsの影響を受けない
    Py_ssize_t len;          # flagsの影響を受けない
    int readonly;
    Py_ssize_t itemsize;     # flagsの影響を受けない
    char* format;
    int ndim;                # flagsの影響を受けない
    Py_ssize_t* shape;
    Py_ssize_t* strides;
    Py_ssize_t* suboffsets;
    void* internal;
}
~~~

#### バッファ関連の関数

<https://docs.python.org/ja/3.12/c-api/buffer.html#buffer-related-functions>

~~~c
from cpython cimport Py_buffer
from cpython.object cimport PyObject
from cpython.buffer cimport (
    PyObject_CheckBuffer,
    PyObject_GetBuffer,
    PyBuffer_Release,
    PyBuffer_FillInfo,
    PyBUF_WRITEABLE,
    PyBUF_FORMAT,
    )

int PyObject_CheckBuffer(PyObject *obj)

int PyObject_GetBuffer(PyObject *exporter, Py_buffer *view, int flags)
void PyBuffer_Release(Py_buffer *view)

int PyBuffer_FillInfo(Py_buffer *view, PyObject *exporter, void *buf, Py_ssize_t len, int readonly, int flags)
~~~

<https://docs.python.org/ja/3.12/c-api/memoryview.html>

~~~c
from cpython cimport Py_buffer
from cpython.object cimport PyObject
from cpython.memoryview cimport (
    PyMemoryView_FromObject,
    PyMemoryView_FromMemory, 
    PyMemoryView_FromBuffer,
    )
from cpython.buffer cimport (
    PyBUF_READ,
    PyBUF_WRITE,
    )

PyObject *PyMemoryView_FromObject(PyObject *obj)
PyObject *PyMemoryView_FromMemory(char *mem, Py_ssize_t size, int flags)
PyObject *PyMemoryView_FromBuffer(const Py_buffer *view)
~~~

### バッファオブジェクト構造体 (buffer object structure)

<https://docs.python.org/ja/3.12/c-api/typeobj.html#buffer-structs>

~~~c
typedef PyBufferProcs
~~~

## バッファ型の実装方法

特殊メソッドを実装したクラスは、バッファ型を提供できる
特殊メソッドの中で、バッファ構造体のメンバを埋めるか、バッファ関連の関数を経由してバッファ構造体を埋めて、メモリビューに渡す
> メモリビューのコンストラクタにバッファ型を渡すと`配列`のように扱えるようになるが、Pythonのオブジェクトではない（あくまでも`メモリ配列`のラッパー）

### Python - Emulating buffer types

<https://docs.python.org/ja/3.12/reference/datamodel.html#emulating-buffer-types>

~~~python
object.__buffer__(self, flags) -> memoryview
object.__release_buffer__(self, buffer)
~~~

~~~python
view = memoryview(object)
print(f"{view[0]}) # 配列の様に扱える
~~~

> `Python 3.12`以降では、collections.abc.bufferが使える

### Cython - Implementing the buffer protocol

<https://cython.readthedocs.io/en/stable/src/userguide/buffer.html>

~~~python
object.__getbuffer__(self, Py_buffer *buffer, int flags)
object.__releasebuffer__(self, Py_buffer *buffer)
~~~

~~~python
import numpy as np
nparray = np.frombuffer(object)
print(f"{nparray[0]}") # 配列の様に扱える
~~~

> `cython.view.array`からバッファ型を扱えないものか？

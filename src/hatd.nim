#[
## hatd.nim | Preloaded size-doubling hashed array trees.
## https://github.com/davidgarland/nim-hatd
]#

import bitops

type
  HatD*[T] = object
    l: ptr (ptr T) # The lower  superblock, used for shrinking.
    m: ptr (ptr T) # The middle superblock.
    h: ptr (ptr T) # The higher superblock, used for growing.
    m_cap: int # The size of the middle superblock.
    l_len: int # The number of slots occupied in the lower superblock.
    m_len: int # The number of slots occupied in the middle superblock.
    h_len: int # The number of slots occupied in the higher superblock.
    len_p: int # The internal length field.

#[
## Utility
]#

template `+`[T](p: ptr T, o: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% o * sizeof(p[]))

template `[]`[T](p: ptr T, o: int): T =
  (p + o)[]

template `[]=`[T](p: ptr T, o: int, val: T) =
  (p + o)[] = val

func fastNextPow2(x: int): int {.inline.} =
  let c = int(x <= 1)
  (c * 1) + ((1 - c) * (1 shl (fastLog2(x - 1) + 1)))

func locateD(i: int): (int, int) {.inline.} =
  let w = i + 1
  let l = w.fastLog2
  (l, w - (1 shl l))

#[
## Fields
]#

func len*[T](h: HatD[T]): int {.inline.} =
  result = h.len_p

func high*[T](h: HatD[T]): int {.inline.} =
  result = h.len_p - 1

func low*[T](h: HatD[T]): int {.inline.} =
  result = 0

#[
## Allocation
]#

proc newHatD*[T]: HatD[T] =
  result.l = createU(ptr T, 1)
  result.m = createU(ptr T, 1)
  result.h = createU(ptr T, 2)
  result.m_cap = 1

#[
## Move Semantics
]#

proc `=destroy`*[T](h: var HatD[T]) =
  if likely(h.m != nil):
    dealloc(h.l)
    h.l = nil
    dealloc(h.h)
    h.h = nil
    for i in 0 ..< h.m_len:
      for j in 0 ..< (1 shl i):
        `=destroy`(h.m[i][j])
      dealloc(h.m[i])
    dealloc(h.m)
    h.m = nil

proc `=`*[T](dest: var HatD[T]; source: HatD[T]) =
  if dest.m != source.m:
    `=destroy`(dest)
    dest = newHatD[T]()
    for x in source.items:
      dest.add(x)

#[
## Accessors
]#

proc `[]`*[T](h: HatD[T]; i: int): lent T {.inline.} =
  when not defined(danger):
    if unlikely(i >= h.len):
      raise newException(IndexError, "Out of bounds index read.")
  let (bi, si) = locateD i
  result = h.m[bi][si]

proc `[]=`*[T](h: HatD[T]; i: int; e: sink T) {.inline.} =
  when not defined(danger):
    if unlikely(i >= h.len):
      raise newException(IndexError, "Out of bounds index write.")
  let (bi, si) = locateD i
  h.m[bi][si] = e

#[
## Stack Operations
]#

proc add*[T](h: var HatD[T], e: sink T) =
  let (bi, si) = locateD h.len
  if unlikely(bi >= h.m_len):
    if unlikely(bi >= h.m_cap):
      h.m_cap *= 2
      dealloc(h.l)
      h.l = h.m
      h.l_len = h.m_len
      h.m = h.h
      h.h = createU(ptr T, h.m_cap * 2)
      h.h_len = 0
    
    h.m[h.m_len] = createU(T, 1 shl h.m_len)
    inc h.m_len
    
    if likely(h.m_len - h.h_len > 0):
      h.h[h.h_len] = h.m[h.h_len]
      inc h.h_len
    if likely(h.m_len - h.h_len > 0):
      h.h[h.h_len] = h.m[h.h_len]
      inc h.h_len
  h.m[bi][si] = e
  inc h.len_p

proc pop*[T](h: var HatD[T]): T =
  when not defined(danger):
    if unlikely(h.len < 1):
      raise newException(IndexError, "Out of bounds pop.")
  let (bi, si) = locateD (h.len - 1)
  `=sink`(result, h.m[bi][si])
  if unlikely(bi < h.m_len - 1):
    dealloc(h.m[h.m_len - 1])
    if unlikely(bi < h.m_cap shr 1):
      h.m_cap = h.m_cap shr 1
      dealloc(h.h)
      h.h = h.m
      h.h_len = h.m_len
      h.m = h.l
      h.m_len = h.l_len
      h.l = createU(ptr T, max(1, h.m_cap shr 1))
      h.l_len = 0
    else:
      dec h.m_len
    if likely(h.m_cap shr 1 > h.l_len):
      h.l[h.l_len] = h.m[h.l_len]
      inc h.l_len
    if likely(h.m_cap shr 1 > h.l_len):
      h.l[h.l_len] = h.m[h.l_len]
      inc h.l_len
  dec h.len_p

#[
## Iterators
]#

iterator items*[T](h: HatD[T]): lent T =
  for i in 0 ..< h.m_len - 1:
    for j in 0 ..< 1 shl i:
      yield h.m[i][j]
  let c = h.m_len - 1
  for j in 0 .. h.len - (fastNextPow2(h.len) div 2):
    yield h.m[c][j]

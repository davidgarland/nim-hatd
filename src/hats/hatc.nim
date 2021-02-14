## A module implementing preloading hashed array trees. The "C" is mnemonic for
## "constant", as in the size of the sub-blocks is held constant.
##
## https://github.com/davidgarland/nim-hats

import private/ptrmath

type
  HatC*[T; S: static[int]] = object
    ## The type of preloading hashed array trees.
    ## The "S" parameter is the power that should be used for the sub-blocks;
    ## for instance `HatC[T, 3]` would have sub-blocks of size 8 (2^3).
    l: ptr (ptr T) ## The lower superblock, used for O(1) shrinking.
    m: ptr (ptr T) ## The middle superblock.
    h: ptr (ptr T) ## The higher superblock, used for O(1) growing.
    m_cap: int ## The size of the middle superblock.
    l_len: int ## The number of slots occupied in the lower superblock.
    m_len: int ## The number of slots occupied in the middle superblock.
    h_len: int ## The number of slots occupied in the higher superblock.
    len_p: int ## The internal length field.

#[
## Fields
]#

func len*[T, S](h: HatC[T, S]): int {.inline.} =
  ## O(1). The length of the hashed array tree, in elements.
  result = h.len_p

func high*[T, S](h: HatC[T, S]): int {.inline.} =
  ## O(1). The index of the last element in a hashed array tree. Returns -1 if the length is 0.
  result = h.len_p - 1

func low*[T, S](h: HatC[T, S]): int {.inline.} =
  ## O(1). The index of the first element in a hashed array tree.
  result = 0

#[
## Allocation
]#

proc newHatC*[T, S]: HatC[T, S] =
  ## O(1). Allocate a new hashed array tree.
  result.l = createU(ptr T, 1)
  result.m = createU(ptr T, 1)
  result.h = createU(ptr T, 2)
  result.m_cap = 1

#[
## Move Semantics
]#

proc `=destroy`[T, S](h: var HatC[T, S]) =
  if likely(h.m != nil):
    dealloc(h.l)
    h.l = nil
    dealloc(h.h)
    h.h = nil
    for i in 0 ..< h.m_len:
      for j in 0 ..< 100:
        `=destroy`(h.m[i][j])
      dealloc(h.m[i])
    dealloc(h.m)
    h.m = nil

proc `=copy`[T, S](dest: var HatC[T, S]; source: HatC[T, S]) =
  if dest.m != source.m:
    `=destroy`(dest)
    dest = newHatC[T, S]()
    for x in source.items:
      dest.add(x)

#[
## Helper Functions
]#

func blockSiz[T, S](h: HatC[T, S]): int {.inline.} = 1 shl S
func mask[T, S](h: HatC[T, S]): int {.inline.} = h.blockSiz - 1

#[
## Accessors
]#

proc `[]`*[T, S](h: HatC[T, S]; i: int): lent T {.inline.} =
  ##  O(1). Get an element from a hashed array tree at the given index.
  when not defined(danger):
    if unlikely(i >= h.len):
      raise newException(IndexDefect, "Out of bounds index read.")
  result = h.m[i shr S][i and h.mask]

proc `[]=`*[T, S](h: HatC[T, S]; i: int; e: sink T) {.inline.} =
  ## O(1). Set an element in a hashed array tree at the given index.
  when not defined(danger):
    if unlikely(i >= h.len):
      raise newException(IndexDefect, "Out of bounds index write.")
  h.m[i shr S][i and h.mask] = e

#[
## Stack Operations
]#

proc add*[T, S](h: var HatC[T, S]; e: sink T) =
  ## O(1). Add an element onto the end of a hashed array tree.
  let bi = h.len shr S
  let si = h.len and h.mask
  if unlikely(bi >= h.m_len):
    if unlikely(bi >= h.m_cap):
      h.m_cap *= 2
      dealloc(h.l)
      h.l = h.m
      h.l_Len = h.m_len
      h.m = h.h
      h.h = createU(ptr T, h.m_cap * 2)
      h.h_len = 0
    h.m[h.m_len] = createU(T, h.blockSiz)
    inc h.m_len
    if likely(h.m_len - h.h_len > 0):
      h.h[h.h_len] = h.m[h.h_len]
      inc h.h_len
    if likely(h.m_len - h.h_len > 0):
      h.h[h.h_len] = h.m[h.h_len]
      inc h.h_len
  h.m[bi][si] = e
  inc h.len_p

proc pop*[T, S](h: var HatC[T, S]): T =
  ## O(1). Pop an element off the end of a hashed array tree.
  when not defined(danger):
    if unlikely(h.len < 1):
      raise newException(IndexDefect, "Out of bounds pop.")
  let bi = (h.len - 1) shr S
  let si = (h.len - 1) and h.mask
  `=sink`(result, h.m[bi][si])
  if unlikely(bi < h.m_len - 1):
    dealloc(h.m[h.m_len - 1])
    if unlikely(bi < h.m_cap shr 1):
      h.m_cap = h.m_cap shr 1
      dealloc(h.h)
      h.h = h.m
      h.h_len = h.m_len
      h.m = h.l
      h.l = createU(ptr T, max(1, h.m_cap shr 1))
      h.l_len = 0
    dec h.m_len
    if likely(h.m_cap shr 1 > h.l_len):
      h.l[h.l_len] = h.m[h.l_len]
      inc h.l_len
    if likely(h.m_cap shr 1 > h.l_len):
      h.l[h.l_len] = h.m[h.l_len]
      inc h.l_len
  dec h.len_p

iterator items*[T, S](h: HatC[T, S]): lent T =
  ## O(n). Iterate over the elements in a hashed array tree. This only
  ## dereferences the sub-blocks once, making it more efficient than naively
  ## looping with the `[]` operator.
  for i in 0 ..< h.m_len - 1:
    for j in 0 ..< h.blockSiz:
      yield h.m[i][j]
  let c = h.m_len - 1
  for j in 0 ..< (h.len and h.mask):
    yield h.m[c][j]

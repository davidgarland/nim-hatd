template `+`*[T](p: ptr T, o: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% o * sizeof(p[]))

template `[]`*[T](p: ptr T, o: int): T =
  (p + o)[]

template `[]=`*[T](p: ptr T, o: int, val: T) =
  (p + o)[] = val

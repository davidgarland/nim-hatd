import unittest
import sequtils
import hats/hatd
import hats/hatc

suite "HatD":
  var h: HatD[int]
  test "newHatD":
    h = newHatD[int]()
    check(h.len == 0)
  test "add":
    for i in 0 ..< 100:
      h.add(i)
    check(h.len == 100)
  test "[]":
    for i in 0 ..< 100:
      check(h[i] == i)
  test "[]=":
    for i in 0 ..< 100:
      h[i] = 99 - h[i]
      check(h[i] == 99 - i)
  test "=":
    var acc: int
    
    for i in 0 ..< 100:
      acc += i
      acc -= h[i]

    check(acc == 0)

    var h2: HatD[int]
    `=`(h2, h)

    for i in 0 ..< 100:
      acc += i
      acc -= h2[i]

    check(acc == 0)
  test "pop":
    for i in 0 ..< 100:
      var x = h.pop
      check(x == i)
    check(h.len == 0)
  test "applyIt":
    h.add(1)
    h.add(2)
    h.add(3)
    h.applyIt(it * 2)
    check(h[0] == 2)
    check(h[1] == 4)
    check(h[2] == 6)
  test "foldl":
    check(h.foldl(a + b) == 12)

suite "HatC":
  var h: HatC[int, 4]
  test "newHatC":
    h = newHatC[int, 4]()
    check(h.len == 0)
  test "add":
    for i in 0 ..< 100:
      h.add(i)
    check(h.len == 100)
  test "[]":
    for i in 0 ..< 100:
      check(h[i] == i)
  test "[]=":
    for i in 0 ..< 100:
      h[i] = 99 - h[i]
      check(h[i] == 99 - i)
  test "=":
    var acc: int
    
    for i in 0 ..< 100:
      acc += i
      acc -= h[i]

    check(acc == 0)

    var h2: HatC[int, 4]
    `=`(h2, h)

    for i in 0 ..< 100:
      acc += i
      acc -= h2[i]

    check(acc == 0)
  test "pop":
    for i in 0 ..< 100:
      var x = h.pop
      check(x == i)
    check(h.len == 0)
  test "applyIt":
    h.add(1)
    h.add(2)
    h.add(3)
    h.applyIt(it * 2)
    check(h[0] == 2)
    check(h[1] == 4)
    check(h[2] == 6)
  test "foldl":
    check(h.foldl(a + b) == 12)

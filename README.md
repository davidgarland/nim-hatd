# nim-hats

## Hashed array trees.

...Which is a pretty bad misnomer, as there is no hashing involved.

In short, this is a dynamic array with O(1) `add`, O(1) `pop`, and O(1)
indexing, with only two layers of indirection. And no, none of those are
amortized figures.

## Wait, how?

Here I'll step back and walk you through the design space of these sorts of data
structures, and show the tradeoffs made and what motivates them, so that you
hopefully see the idea behind what this repo implements.

### Arrays

Method: Just `malloc` an array, then `realloc` it each time you want to push
or pop an element.

Why It's Good:
- `O(1)` indexing.
- Good cache locality.
- No wasted space whatsoever.
- Simple to implement.

Why It's Bad:
- `O(n)` push/pop because `realloc` may degrade to `malloc`+`memcpy`+`free` in general.
  * Adding `n` elements therefore takes `O(n^2)` time.
    - Technically ["triangular time"](https://en.wikipedia.org/wiki/Triangular_number) but Big-O only cares about asymptotes.

Use statically sized arrays where you can, but they are awful as a dynamic
collection.

### Linked Lists

Method: `malloc` new nodes then point to the rest of the list, with `NULL`
acting as the end of the list.

Why It's Good:
- `O(1)` push/pop because no copying is ever necessary.
- Simple to implement.
- Purely functional.

Why It's Bad:
- In practice, doing `n` calls to `malloc` to build an `n`-element list is slow.
- Usually awful cache locality, as elements are likely not contiguous.
- `O(n)` random access.
- Iteration has to be from the end that you built from unless you want to use recursion and risk a stack overflow.
  * One solution here is to keep a pointer to the end of the list and build from there instead.
    - Iterating is still slower than iterating through an array, though.
    - The structure is now more complicated since your base node has to be unique.
    - The structure is no longer purely functional.
    - And all the other criticisms still apply.
- `O(n)` best case space wastage.
  * One pointers' worth (8 bytes) of wasted space per element at the minimum. More, if you have padding. For instance, a list of 8 bit integers would take 16 bytes per element.
- Even in the one case it makes sense, use as a stack, it's still outclassed by some of the other options here.

In general, avoid linked lists.

SIDE NOTE: They may be defensible as a sort of generator in Haskell, but Haskell
isn't exactly a paragon of performant code, now is it?

### Amortized Arrays

Method: Have an array with `length` and `capacity` fields that denote the number
of spaces occupied and the number of spaces allocated respectively. When
`length` catches up to `capacity`, `realloc` the array to 2x the current size
and double `capacity` to reflect this fact.

Why It's Good:
- `O(1)` amortized push/pop.
- `O(1)` indexing.
- Good cache locality.
- Simple to implement.

Why It's Bad:
- `O(n)` worst case push/pop, causing performance spikes.
- `O(n)` worst case space wastage.

This is probably the single most popular imperative data structure; C++ calls it
`std::vector` (which is easily confused with mathematical vectors), Java calls
it `ArrayList` (weird but pop off), Nim calls it `seq` (which was seemingly
inspired by the Haskell `Seq`, which is a totally different thing.. confusing),
Rust calls it `Vec` (same issue as C++ I guess).

In general it does well enough, clearly. We can do better, though, with some
trade-offs.

### Lists Of Arrays

Method: Have a linked list of constant-sized arrays with a unique base node that
points to the last node and first node and stores the length.

Why It's Good:
- `O(1)` push/pop.
- Indexing has far fewer indirections than a plain linked list.
- Cache locality inside of the sub-arrays is good.
- Traversal from left to right should be only marginally slower than that of an array.
- Only `O(1)` wasted space.

Why It's Bad:
- `O(n)` indexing.

### Lists of Size Doubled Arrays

Method: Same as "List Of Arrays", but each array is now two times the length
of the last array.

Why It's Good:
- `O(1)` push/pop.
- Cache locality gets better the more elements you have.
- Traversal from left to right should be only marginally slower than that of an array.
- `O(log n)` indexing with fewer indirections than the "List Of Arrays".

Why It's Bad:
- `O(log n)` indexing still isn't the ideal `O(1)` we wish we had.
- `O(n)` worst case space wastage.

### Non-Amortized Hashed Array Trees

Method: Have an array of pointers to constant sized sub-arrays, which you do the
naive realloc method on as needed.

Why It's Good:
- `O(1)` indexing with 2 layers of indirection.
- push/pop reallocs copy very little memory, because the pointer array is small.
- Minimal space wastage.

Why It's Bad:
- `O(n)` push/pop still, technically.
- The number of `malloc`s needed scales linearly with space usage, which is not ideal; we'd prefer it to go down.

### Amortized Hashed Array Trees

Method: Same as "Non-Amortized Hashed Array Trees", but with amortization on
the pointer array.

Why It's Good:
- `O(1)` indexing with 2 layers of indirection.
- `O(1)` amortized push/pop.
- Space wastage is less than an amortized array.

Why It's Bad:
- `O(n)` space wastage.

### Preloading Hashed Array Trees

Method: In addition to the pointer array, keep pointer arrays of half the size
and double the size. When you push, move up to 2 uncopied pointers from the
pointer array to the double-size pointer array if necessary. When you pop, move
up to 2 uncopied pointers from the pointer array to the half-size pointer array
if necessary. This way, there is never a need to do a realloc; all the data
is already copied, and you just malloc a new lower or upper block, shifting
things over as needed.

Why It's Good:
- `O(1)` push/pop without amortization.
- `O(1)` indexing with 2 layers of indirection.
- Fewer calls to `malloc` are needed over time, so it is "amortized" in that respect, even if it has no bearing on time complexity.

Why It's Bad:
- `O(n)` space wastage.
- Annoying and error prone to implement.

I'd like to implement this as well soon.

### Size Doubling Hashed Array Trees

Method: Same as "Non-Amortized Hashed Array Trees", but the sizes of the
sub-arrays are powers of two, doubling each time. Amortization on the pointer
block is unnecessary, as it's already accounted for by the size doubling of
sub-blocks. I suppose you could "double-amortize" it if you want, but meh.

Why It's Good:
- `O(1)` amortized push/pop.
- `O(1)` indexing with 2 layers of indirection.
- Cache locality gets better the more elements you have.

Why It's Bad:
- `O(n)` space wastage.

### Preloading Size Doubling Hashed Array Trees

Method: A mix of "Preloading Hashed Array Trees" and "Size Doubling Hashed Array
Trees".

Why It's Good:
- `O(1)` push/pop without amortization.
- `O(1)` indexing with 2 layers of indirection.
- Fewer calls to `malloc` are needed over time, so it is "amortized" in that respect, even if it has no bearing on time complexity.
- Cache locality gets better the more elements you have.

Why It's Bad:
- `O(n)` space wastage.
- Annoying and error prone to implement.

This is what this repo implements.

### Optimal Hashed Array Trees

Method: Similar to "Size Doubling Hashed Array Trees", but the sub-arrays are
roughly `sqrt(n)` sized. This gives a data structure with both optimal time and
space bounds for dynamic arrays. This is also the minimal amount that the
sub-arrays can grow and still be amortized; you could opt to amortize the
pointer array on top of this, but again, meh.

Why It's Good:
- `O(1)` amortized push/pop.
- `O(1)` indexing with 2 layers of indirection.
- `O(sqrt n)` space wastage.

Why It's Bad:
- Worst case push/pop is still technically `O(n)`.
- The math for indexing is complicated, so it will be slower than an array or even a size doubling hashed array tree.
- Not as many elements will be contiguous as in a size doubling hashed array tree.
- Annoying and error prone to implement.

### Preloading Optimal Hashed Array Trees

Method: A mix of the methods described in "Preloading Hashed Array Trees" and
"Optimal Hashed Array Trees".

Why It's Good:
- `O(1)` push/pop without amortization.
- `O(1)` indexing with 2 layers of indirection.
- `O(sqrt n)` space wastage.

Why It's Bad:
- The math for indexing is complicated, so it will be slower than an array or even a size doubling hashed array tree.
- Not as many elements will be contiguous as in a size doubling hashed array tree.
- Annoying and error prone to implement.

I'd like to try implementing this as well soon.

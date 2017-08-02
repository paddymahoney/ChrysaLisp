# ChrysaLisp

It's probably worth a few words specifically about the included Lisp and how it
works, and how many rules it breaks ! The reason for doing the Lisp was to
allow me to create an assembler to replace NASM, I was not concerned with
sticking to 'the lisp way', or whatever your local Lisp guru says. No doubt I
will have many demons in hell awaiting me...

First of all there is no garbage collector by choice. All objects used by the
Lisp are reference counted objects from the class library. Early on the Lisp
was never going to have a problem with cycles because it had no way to create
them, but as I developed the assembler I decided to introduce two functions,
`push` and `elem-set`, that could create cycles. However the efficiency
advantage in coding the assembler made me look the other way. There are now
other ways that a cycle can be created, by naming an environment within its own
scope, but again this was too good an efficiency feature to miss out on. So you
do have to be careful not to create cycles, so think about how your code works.

No tail recursion ! There is a single looping function provided in native code,
`while`, every other looping construct builds on this primitive. I try to stick
to a functional approach in my Lisp code, and manipulate collections of things
in a functional way with operations like `map`, `filter`, `reduce`, `each` etc.
I've not found the lack of tail recursion a problem.

All symbols live in the same environment, functions, macros, everything. The
environment is a chain of hash maps. Each lambda gets a new hash map pushed
onto the environment chain on invocation, and dereferenced on exit. The `env`
function can be used to return the current hash map and optionally resize the
number of buckets from the default of 1. This proves very effective for storing
large numbers of symbols and objects for the assembler as well as creating
caches. Make sure to `setq` the symbol you bind to the result of `env` to `nil`
before returning from the function if you do this, else you will create a cycle
that can't be freed.

`defq` and `bind` always create entries in the top environment hash map. `setq`
searches the environment chain to find an existing entry and sets that entry or
fails with an error. This means `setq` can be used to write to symbols outside
the scope of the current function. Some people don't like this, but used wisely
it can be very powerful. Coming from an assembler background I prefer to have
all the guns and knives available, so try not to shoot you foot off.

There is no cons, cdr or car stuff. Lists are just vector objects and you use
`push`, `cat`, `slice` etc to manipulate elements.

Function and macro definitions are scoped and visible only within the scope of
the declaring function. There is no global macro list. During macro expansion
the environment chain is searched to see if a macro exists.

## Built in symbols

```
&rest
&optional
nil
t
```

## Built in functions

```
add
age
apply
array
bind
bit-and
bit-asr
bit-or
bit-shl
bit-shr
bit-xor
call
cat
char
clear
cmp
code
cond
copy
def
def?
defmacro
defq
div
each!
elem
elem-set
env
eq
eql
eval
fcos
fdiv
file-stream
find
floor
fmod
fmul
frac
fsin
fsqrt
ge
gensym
gt
inst-of
lambda
le
length
list
load
lt
macro
macroexpand
macroexpand-1
match?
mod
mul
ne
not
pipe
pipe-read
pipe-write
points
pop
prin
print
progn
push
quasi-quote
quote
read
read-char
read-line
repl
save
set
setq
slice
some!
split
str
string-stream
sub
sym
throw
time
unquote
unquote-splicing
val?
while
write
write-char
write-line
```

## boot.lisp symbols

```
min_long
max_long
min_int
max_int
fp_shift
fp_2pi
fp_pi
fp_hpi
fp_qpi
fp_int_mask
fp_frac_mask
```

## boot.lisp macros

```
and
ascii
compose
curry
dec
if
inc
let
minus
opt
or
rcurry
run
setd
sym-cat
times
unless
until
when
```

## boot.lisp functions

```
abs
align
bit-not
cubed
defun
divmod
each
each-line
each-mergeable
each-mergeable-rev
each-rev
equalp
every
every-pipe-line
filter
from-base-char
insert
insert-sym
lst?
map
map-rev
max
merge
merge-sym
min
neg
notany
notevery
num?
obj?
partition
pow2
prin-base
range
reduce
shuffle
shuffled
sign
some
sort
sorted
squared
str?
swap
sym?
to-base-char
to-num
trim
trim-end
trim-start
within-compile-env
```
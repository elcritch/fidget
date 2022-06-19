import patty
export patty

import vmath, bumpy, math
export vmath, bumpy, math

import macros, macroutils
import typetraits

macro variants*(name, code: untyped) =
  ## convenience wrapper for Patty variant macros
  result = quote do:
    {.push hint[Name]: off.}
    variantp ScrollEvent:
      ## test
    {.pop.}
  result[1][2] = code


template borrowMaths*(typ: typedesc) =
  proc `+` *(x, y: typ): typ {.borrow.}
  proc `-` *(x, y: typ): typ {.borrow.}
  
  proc `+` *(x: typ): typ {.borrow.}
  proc `-` *(x: typ): typ {.borrow.}

  proc `*` *(x: typ, y: distinctBase(typ)): typ {.borrow.}
  proc `*` *(x: distinctBase(typ), y: typ): typ {.borrow.}

  proc `<` * (x, y: typ): bool {.borrow.}
  proc `<=` * (x, y: typ): bool {.borrow.}
  proc `==` * (x, y: typ): bool {.borrow.}


# template genOps(T, B: untyped, op: untyped) =
#   proc `op`*(a, b: T): T = `op`[B](a.B, b.B).T

macro genOps(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*[`T`](a, b: `T`): `T` = `op`(a.`B`, b.`B`).`T`

macro genOps2(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*(a, b: `T`): `T` = `op`(a.`B`, b.`B`).`T`

macro genBoolOps(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*(a, b: `T`): bool = `op`(a.`B`, b.`B`)

macro genEqOps(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      template `op`*(a: var RawVec2, b: float32) = `op`(a.`B`, b)
      proc `op`*(a: var `T`, b: `T`) = `op`(a.`B`, b.`B`)

macro genMathFns(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*(a: `T`): `T` = `op`(a.`B`).`T`

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 
## Distinct percentages
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 

type
  PercKind* = enum
    relative
    absolute
  Percent* = distinct float32
  Percentages* = tuple[value: float32, kind: PercKind]

borrowMaths(Percent)


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 
## Distinct vec types
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 

type
  RawVec2* = distinct Vec2
  RawRect* = distinct Rect

genOps(RawVec2, Vec2, `+`, `-`, `/`, `*`, `mod`, `div`, `zmod`, min, max)
genEqOps(RawVec2, Vec2, `+=`, `-=`, `*=`, `/=`)
genBoolOps(RawVec2, Vec2, `==`, `!=`, `~=`)
genMathFns(RawVec2, Vec2, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh)
genMathFns(RawVec2, Vec2, exp, ln, log2, sqrt, floor, ceil, abs) 

# genOp(RawRect, Rect, `+`, `-`, `/`, `*`)
# genBoolOp(RawRect, Rect, `==`, `!=`, `~=`)
# genMathFn(RawRect, Rect, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh, exp2, inversesqrt, exp, ln, log2, sqrt, floor, ceil, abs) 

# when isMainModule:
proc testRawVec2() =
  let x = vec2(12.1, 13.4).RawVec2
  let y = vec2(10.0, 10.0).RawVec2
  var z = vec2(0.0, 0.0).RawVec2

  echo "x + y: ", repr(x + y)
  echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / y)
  echo "x * y: ", repr(x * y)
  echo "x == y: ", repr(x == y)
  echo "x ~= y: ", repr(x ~= y)
  echo "min(x, y): ", repr(min(x, y))

  z = vec2(1.0, 1.0).RawVec2
  z += y
  z += 3.1'f32
  echo "z: ", repr(z)
  z = vec2(1.0, 1.0).RawVec2
  echo "z: ", repr(-z)
  echo "z: ", repr(sin(z))

proc testRect() =
  let x = rect(10.0, 10.0, 2.0, 2.0).RawRect
  let y = rect(10.0, 10.0, 5.0, 5.0).RawRect
  var z = rect(10.0, 10.0, 5.0, 5.0).RawRect

#   echo "x + y: ", repr(x + y)
#   echo "x - y: ", repr(x - y)
#   echo "x / y: ", repr(x / y)
#   echo "x * y: ", repr(x * y)
#   # echo "x == y: ", repr(x == y)
#   echo "min(x, y): ", repr(min(x, y))

#   z = rect(10.0, 10.0, 5.0, 5.0).RawRect
#   # z += y
#   # z += 3.1'f32
#   echo "z: ", repr(z)
#   z = rect(10.0, 10.0, 5.0, 5.0).RawRect
#   echo "z: ", repr(-z)
#   echo "z: ", repr(sin(z))

when true:
  testRawVec2()
  testRect()

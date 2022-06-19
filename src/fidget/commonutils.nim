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


template genBoolOp[T, B](op: untyped) =
  proc `op`*(a, b: T): bool = `op`(B(a), B(b))

template genFloatOp[T, B](op: untyped) =
  proc `op`*(a: T, b: float): T = T(`op`(B(a), b))

template genEqOp[T, B](op: untyped) =
  proc `op`*(a: var T, b: float32) = `op`(B(a), b)
  proc `op`*(a: var T, b: T) = `op`(B(a), B(b))

template genEqOpC[T, B, C](op: untyped) =
  proc `op`*[D](a: var T, b: D) = `op`(B(a), C(b))

template genMathFn[T, B](op: untyped) =
  proc `op`*(a: `T`): `T` =
    T(`op`(B(a)))

template genOp[T, B](op: untyped) =
  proc `op`*(a, b: T): T = T(`op`(B(a), B(b)))

macro applyOps(a, b: typed, fn: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      `fn`[`a`, `b`](`op`)

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

genBoolOp[RawVec2, Vec2](`==`)
genBoolOp[RawVec2, Vec2](`!=`)
genBoolOp[RawVec2, Vec2](`~=`)

applyOps(RawVec2, Vec2, genOp, `+`, `-`, `/`, `*`, `mod`, `zmod`, `min`, `zmod`)
applyOps(RawVec2, Vec2, genEqOp, `+=`, `-=`, `*=`, `/=`)
applyOps(RawVec2, Vec2, genMathFn, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh)
applyOps(RawVec2, Vec2, genMathFn, exp, ln, log2, sqrt, floor, ceil, abs) 

applyOps(RawRect, Rect, genOp, `+`)
applyOps(RawRect, Rect, genFloatOp, `*`, `/`)
genBoolOp[RawRect, Rect](`==`)
genEqOpC[RawRect, Rect, Vec2](`xy=`)

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
  let c = 10.0
  var z = rect(10.0, 10.0, 5.0, 5.0).RawRect
  let v = vec2(10.0, 10.0).RawVec2

  echo "x + y: ", repr(x + y)
#   echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / c)
  echo "x * y: ", repr(x * c)
  echo "x == y: ", repr(x == y)

  z = rect(10.0, 10.0, 5.0, 5.0).RawRect
  z.xy= v
  # z += 3.1'f32
  echo "z: ", repr(z)
  z = rect(10.0, 10.0, 5.0, 5.0).RawRect

when true:
  testRawVec2()
  testRect()

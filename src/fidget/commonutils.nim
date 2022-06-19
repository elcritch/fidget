import strformat

import patty
export patty

import vmath except `$`
import bumpy except `$`
import math
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

proc rvec2*(x, y: float32): RawVec2 = RawVec2(vec2(x, y))
genBoolOp[RawVec2, Vec2](`==`)
genBoolOp[RawVec2, Vec2](`!=`)
genBoolOp[RawVec2, Vec2](`~=`)

applyOps(RawVec2, Vec2, genOp, `+`, `-`, `/`, `*`, `mod`, `zmod`, `min`, `zmod`)
applyOps(RawVec2, Vec2, genEqOp, `+=`, `-=`, `*=`, `/=`)
applyOps(RawVec2, Vec2, genMathFn, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh)
applyOps(RawVec2, Vec2, genMathFn, exp, ln, log2, sqrt, floor, ceil, abs) 
applyOps(RawVec2, Vec2, genFloatOp, `*`, `/`)

type
  RawRect* = distinct Rect

proc rrect*(x, y, w, h: float32): RawRect = RawRect(rect(x, y, w, h))

applyOps(RawRect, Rect, genOp, `+`)
applyOps(RawRect, Rect, genFloatOp, `*`, `/`)
genBoolOp[RawRect, Rect](`==`)
genEqOpC[RawRect, Rect, Vec2](`xy=`)

template x*(r: RawRect): float32 = r.Rect.x
template y*(r: RawRect): float32 = r.Rect.y
template w*(r: RawRect): float32 = r.Rect.w
template h*(r: RawRect): float32 = r.Rect.h
template `x=`*(r: RawRect, v: float32) = r.Rect.x = v
template `y=`*(r: RawRect, v: float32) = r.Rect.y = v
template `w=`*(r: RawRect, v: float32) = r.Rect.w = v
template `h=`*(r: RawRect, v: float32) = r.Rect.h = v

template x*(r: RawVec2): float32 = r.Vec2.x
template y*(r: RawVec2): float32 = r.Vec2.y
template `x=`*(r: RawVec2, v: float32) = r.Vec2.x = v
template `y=`*(r: RawVec2, v: float32) = r.Vec2.y = v

proc `$`*(a: Vec2): string =
  &"vec<{a[0]:2.2f}, {a[1]:2.2f}>"
proc `$`*(a: Rect): string =
  &"<{a.x:2.2f}, {a.y:2.2f}; {a.x+a.w:2.2f}, {a.y+a.h:2.2f} [{a.w:2.2f} x {a.h:2.2f}]>"

proc `$`*(a: RawVec2): string {.borrow.}
proc `$`*(a: RawRect): string {.borrow.}

# when isMainModule:
proc testRawVec2() =
  let x = rvec2(12.1, 13.4)
  let y = rvec2(10.0, 10.0)
  var z = rvec2(0.0, 0.0)
  let c = 1.0

  echo "x + y: ", repr(x + y)
  echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / y)
  echo "x / c: ", repr(x / c)
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

  echo "x.w: ", repr(x.w)
  echo "x + y: ", repr(x + y)
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

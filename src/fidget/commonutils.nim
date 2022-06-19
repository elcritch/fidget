import strformat

import patty
export patty

import vmath, bumpy, math
export math, vmath, bumpy

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
  Position* = distinct Vec2

proc position*(x, y: float32): Position = Position(vec2(x, y))
genBoolOp[Position, Vec2](`==`)
genBoolOp[Position, Vec2](`!=`)
genBoolOp[Position, Vec2](`~=`)

applyOps(Position, Vec2, genOp, `+`, `-`, `/`, `*`, `mod`, `zmod`, `min`, `zmod`)
applyOps(Position, Vec2, genEqOp, `+=`, `-=`, `*=`, `/=`)
applyOps(Position, Vec2, genMathFn, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh)
applyOps(Position, Vec2, genMathFn, exp, ln, log2, sqrt, floor, ceil, abs) 
applyOps(Position, Vec2, genFloatOp, `*`, `/`)

type
  Box* = distinct Rect

proc initBox*(x, y, w, h: float32): Box = Box(rect(x, y, w, h))

applyOps(Box, Rect, genOp, `+`)
applyOps(Box, Rect, genFloatOp, `*`, `/`)
genBoolOp[Box, Rect](`==`)
genEqOpC[Box, Rect, Vec2](`xy=`)

template x*(r: Box): float32 = r.Rect.x
template y*(r: Box): float32 = r.Rect.y
template w*(r: Box): float32 = r.Rect.w
template h*(r: Box): float32 = r.Rect.h
template `x=`*(r: Box, v: float32) = r.Rect.x = v
template `y=`*(r: Box, v: float32) = r.Rect.y = v
template `w=`*(r: Box, v: float32) = r.Rect.w = v
template `h=`*(r: Box, v: float32) = r.Rect.h = v

template wh*(r: Box): Position = position(r.w, r.h)

template x*(r: Position): float32 = r.Vec2.x
template y*(r: Position): float32 = r.Vec2.y
template `x=`*(r: Position, v: float32) = r.Vec2.x = v
template `y=`*(r: Position, v: float32) = r.Vec2.y = v

proc `$`*(a: Position): string =
  &"vec<{a.x:2.2f}, {a.y:2.2f}>"
proc `$`*(a: Box): string =
  &"<{a.x:2.2f}, {a.y:2.2f}; {a.x+a.w:2.2f}, {a.y+a.h:2.2f} [{a.w:2.2f} x {a.h:2.2f}]>"

# proc `$`*(a: Position): string {.borrow.}
# proc `$`*(a: Box): string {.borrow.}

template scaled*(a: Box): Rect = Rect(a * common.uiScale)
template descaled*(a: Rect): Box = Box(a / common.uiScale)

template scaled*(a: Position): Vec2 = Vec2(a * common.uiScale)
template descaled*(a: Vec2): Position = Position(a / common.uiScale)

# when isMainModule:
proc testPosition() =
  let x = position(12.1, 13.4)
  let y = position(10.0, 10.0)
  var z = position(0.0, 0.0)
  let c = 1.0

  echo "x + y: ", repr(x + y)
  echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / y)
  echo "x / c: ", repr(x / c)
  echo "x * y: ", repr(x * y)
  echo "x == y: ", repr(x == y)
  echo "x ~= y: ", repr(x ~= y)
  echo "min(x, y): ", repr(min(x, y))

  z = vec2(1.0, 1.0).Position
  z += y
  z += 3.1'f32
  echo "z: ", repr(z)
  z = vec2(1.0, 1.0).Position
  echo "z: ", repr(-z)
  echo "z: ", repr(sin(z))

proc testRect() =
  let x = initBox(10.0, 10.0, 2.0, 2.0).Box
  let y = initBox(10.0, 10.0, 5.0, 5.0).Box
  let c = 10.0
  var z = initBox(10.0, 10.0, 5.0, 5.0).Box
  let v = position(10.0, 10.0)

  echo "x.w: ", repr(x.w)
  echo "x + y: ", repr(x + y)
  echo "x / y: ", repr(x / c)
  echo "x * y: ", repr(x * c)
  echo "x == y: ", repr(x == y)

  z = rect(10.0, 10.0, 5.0, 5.0).Box
  z.xy= v
  # z += 3.1'f32
  echo "z: ", repr(z)
  z = rect(10.0, 10.0, 5.0, 5.0).Box

when true:
  testPosition()
  testRect()

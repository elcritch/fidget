import patty
export patty

import vmath, bumpy
export vmath, bumpy

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


type
  PercKind* = enum
    relative
    absolute
  Percent* = distinct float32
  Percentages* = tuple[value: float32, kind: PercKind]

borrowMaths(Percent)

type
  RawVec2* = distinct GVec2[float32]
  RawRect* = distinct Rect

macro genOp(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*[`T`](a, b: `T`): `T` = `op`(a.`B`, b.`B`).`T`

macro genBoolOp(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*(a, b: `T`): bool = `op`(a.`B`, b.`B`)

macro genEqOp(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      template `op`*(a: var RawVec2, b: float32) = `op`(a.`B`, b)
      proc `op`*(a: var `T`, b: `T`) = `op`(a.`B`, b.`B`)

macro genMathFn(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*[`T`](a: `T`): `T` = `op`(a.`B`).`T`

genOp(RawVec2, Vec2, `+`, `-`, `/`, `*`, `mod`, `div`, `zmod`)
genEqOp(RawVec2, Vec2, `+=`, `-=`, `*=`, `/=`)
genBoolOp(RawVec2, Vec2, `==`, `!=`, `~=`)
genMathFn(RawVec2, Vec2, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh, exp2, inversesqrt, exp, ln, log2, sqrt, floor, ceil, abs) 

# when isMainModule:
when true:
  let x = vec2(12.1, 13.4).RawVec2
  let y = vec2(10.0, 10.0).RawVec2
  var z = vec2(0.0, 0.0).RawVec2

  echo "x + y: ", repr(x + y)
  echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / y)
  echo "x * y: ", repr(x * y)
  echo "x == y: ", repr(x == y)
  echo "x ~= y: ", repr(x ~= y)

  z = vec2(1.0, 1.0).RawVec2
  z += y
  z += 3.1'f32
  echo "z: ", repr(z)
  z = vec2(1.0, 1.0).RawVec2
  echo "z: ", repr(-z)
  echo "z: ", repr(sin(z))


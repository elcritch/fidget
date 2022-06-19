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
  RawVec2* = distinct Vec2
  RawRect* = distinct Rect

macro genOp(T, B: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      proc `op`*[`T`](a, b: `T`): `T` = `op`(a.`B`, b.`B`).`T`

genOp(RawVec2, Vec2, `+`, `-`, `/`, `*`, `mod`, `div`, `zmod`)

let x = vec2(12.1, 13.4).RawVec2
let y = vec2(10.0, 10.0).RawVec2

when isMainModule:
  echo "x + y: ", repr(x + y)
  echo "x - y: ", repr(x - y)
  echo "x / y: ", repr(x / y)
  echo "x * y: ", repr(x * y)


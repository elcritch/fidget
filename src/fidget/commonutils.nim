import patty

import macros, macroutils
import typetraits

macro variants*(name, code: untyped) =
  ## convenience wrapper for Patty variant macros
  let blk = code[1]
  result = quote do:
    {.push hint[Name]: off.}
    variantp `name`:
      `blk`
    {.pop.}


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

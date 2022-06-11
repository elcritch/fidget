import patty

import macros, macroutils

macro variants*(name, code: untyped) =
  ## convenience wrapper for Patty variant macros
  let blk = code[1]
  result = quote do:
    {.push hint[Name]: off.}
    variantp `name`:
      `blk`
    {.pop.}
  echo "VARIANTS: ", result.treeRepr


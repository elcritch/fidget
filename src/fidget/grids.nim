import prelude
import rationals
import variant
import commonutils
import hashes
import sets

type
  GridConstraint* = enum
    gcStart
    gcEnd
    gcScale
    gcStretch
    gcCenter

  GridUnits* = enum
    grFrac
    grAuto
    grUICoord

  TrackSize* = object
    case kind*: GridUnits
    of grFrac:
      frac*: int
    of grAuto:
      discard
    of grUICoord:
      coord*: UICoord
  
  LineName* = distinct Hash

  GridLine* = object
    trackSize*: TrackSize
    aliases*: HashSet[LineName]

  GridTemplate* = ref object
    columns*: seq[GridLine]
    rows*: seq[GridLine]
    rowGap*: UICoord
    columnGap*: UICoord
    justifyItems*: GridConstraint
    alignItems*: GridConstraint

  ItemLocation* = object
    line*: int8
    isSpan*: bool
    isAuto*: bool
  
  GridItem* = ref object
    columnStart*: ItemLocation
    columnEnd*: ItemLocation
    rowStart*: ItemLocation
    rowEnd*: ItemLocation

proc `==`*(a, b: LineName): bool {.borrow.}

proc mkFrac*(size: int): TrackSize = TrackSize(kind: grFrac, frac: size)
proc mkAuto*(): TrackSize = TrackSize(kind: grAuto)
proc mkCoord*(coord: UICoord): TrackSize = TrackSize(kind: grUICoord, coord: coord)

proc toLineName*(name: string): LineName = LineName(name.hash())

proc gridLine*(
    trackSize = mkFrac(1),
    aliases: varargs[LineName, toGridName],
): GridLine =
  GridLine(trackSize: trackSize, aliases: toHashSet(aliases))

let defaultLine = GridLine(trackSize: mkFrac(1))

proc newGridTemplate*(
  columns = @[defaultLine],
  rows = @[defaultLine],
): GridTemplate =
  new(result)
  result.columns = columns
  result.rows = rows

proc newGridItem*(): GridItem =
  new(result)

when isMainModule:
  import unittest

  suite "grids":

    test "basic grid template":

      var gt = newGridTemplate(
        columns = @[gridLine(mkFrac(1)), gridLine(mkFrac(1))],
        rows = @[gridLine(mkFrac(1)), gridLine(mkFrac(1))],
      )

      echo "grid template: ", repr gt

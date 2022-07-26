import prelude
import variant
import strformat
import strutils
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
    grFixed

  TrackSize* = object
    case kind*: GridUnits
    of grFrac:
      frac*: int
    of grAuto:
      discard
    of grFixed:
      coord*: UICoord
  
  LineName* = distinct Hash

  GridLine* = object
    aliases*: HashSet[LineName]
    trackSize*: TrackSize
    position*: UICoord

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
proc mkFixed*(coord: UICoord): TrackSize = TrackSize(kind: grFixed, coord: coord)

proc toLineName*(name: string): LineName = LineName(name.hash())

proc gridLine*(
    trackSize = mkFrac(1),
    aliases: varargs[LineName, toGridName],
): GridLine =
  GridLine(trackSize: trackSize, aliases: toHashSet(aliases))

proc `'fr`*(n: string): GridLine =
  ## numeric literal percent of parent height
  result = gridLine(trackSize=mkFrac(parseInt(n)))

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

proc computeLineLayout*(lines: seq[GridLine]) =
  var
    fixed = 0'ui
    totalFracs = 0
  for col in lines:
    match col.trackSize:
      grFixed(coord): fixed += coord
      grFrac(frac): totalFracs += frac
      grAuto(): discard

proc computeLayout*(grid: GridTemplate) =
  ## computing grid layout
  
  # The free space is calculated after any non-flexible items. In 


when isMainModule:
  import unittest
  import print

  suite "grids":

    test "basic grid template":

      var gt = newGridTemplate(
        columns = @[gridLine(mkFrac(1)), gridLine(mkFrac(1))],
        rows = @[gridLine(mkFrac(1)), gridLine(mkFrac(1))],
      )

      print "grid template: ", gt

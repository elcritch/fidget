import prelude
import variant
import strformat
import sequtils
import strutils
import sugar
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
    track*: TrackSize
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
    track = mkFrac(1),
    aliases: varargs[LineName, toGridName],
): GridLine =
  GridLine(track: track, aliases: toHashSet(aliases))

proc `'fr`*(n: string): GridLine =
  ## numeric literal percent of parent height
  result = gridLine(track=mkFrac(parseInt(n)))

let defaultLine = GridLine(track: mkFrac(1))

proc newGridTemplate*(
  columns = @[defaultLine],
  rows = @[defaultLine],
): GridTemplate =
  new(result)
  result.columns = columns
  result.rows = rows

proc newGridItem*(): GridItem =
  new(result)

proc computeLineLayout*(
    lines: var seq[GridLine],
    length: UICoord,
    spacing: UICoord,
) =
  var
    fixed = 0'ui
    totalFracs = 0.0
    totalAutos = 0.0
  
  # compute total fixed sizes and fracs
  for grdLn in lines:
    match grdLn.track:
      grFixed(coord): fixed += coord
      grFrac(frac): totalFracs += frac.float
      grAuto(): totalAutos += 1
  fixed += spacing * lines.len().UICoord

  var
    fracPos = 0'ui
    freeSpace = length - fixed
  
  # frac's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grFrac:
      grdLn.position = fracPos
      fracPos += freeSpace * UICoord(grdLn.track.frac.float/totalFracs)
  
  # auto's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grAuto:
      grdLn.position = fracPos
      fracPos += freeSpace * UICoord(1.0/totalAutos)

proc computeLayout*(grid: GridTemplate, box: Box) =
  ## computing grid layout
  
  # The free space is calculated after any non-flexible items. In 
  let
    colLen = box.w - box.x
    rowLen = box.h - box.y
  grid.columns.computeLineLayout(length=colLen, spacing=0'ui)
  grid.rows.computeLineLayout(length=rowLen, spacing=0'ui)


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

      gt.computeLayout(initBox(0, 0, 100, 100))
      print "grid template: ", gt

      check gt.columns[0].position == 0'ui
      check gt.columns[1].position == 50'ui
      check gt.rows[0].position == 0'ui
      check gt.rows[1].position == 50'ui

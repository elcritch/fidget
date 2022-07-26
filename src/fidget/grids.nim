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
    start*: UICoord
    width*: UICoord

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
    totalFracs = 0.0'ui
    totalAutos = 0
  
  # compute total fixed sizes and fracs
  for grdLn in lines:
    match grdLn.track:
      grFixed(coord): fixed += coord
      grFrac(frac): totalFracs += frac.UICoord
      grAuto(): totalAutos += 1
  fixed += spacing * lines.len().UICoord

  var
    freeSpace = length - fixed
    remSpace = freeSpace
  
  # frac's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grFrac:
      grdLn.width =
        freeSpace * grdLn.track.frac.UICoord/totalFracs
      remSpace -= grdLn.width 
    elif grdLn.track.kind == grFixed:
      grdLn.width = grdLn.track.coord
  
  # auto's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grAuto:
      grdLn.width = remSpace * 1/totalAutos.UICoord

  var cursor = 0.0'ui
  for grdLn in lines.mitems():
    grdLn.start = cursor
    cursor += grdLn.width

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
        columns = @[gridLine(mkFrac(1))],
        rows = @[gridLine(mkFrac(1))],
      )
      check gt.columns.len() == 1
      check gt.rows.len() == 1

    test "basic grid compute":
      var gt = newGridTemplate(
        columns = @[1'fr, 1'fr],
        rows = @[1'fr, 1'fr],
      )
      gt.computeLayout(initBox(0, 0, 100, 100))
      print "grid template: ", gt

      check gt.columns[0].start == 0'ui
      check gt.columns[1].start == 50'ui
      check gt.rows[0].start == 0'ui
      check gt.rows[1].start == 50'ui

    test "basic grid compute":
      var gt = newGridTemplate(
        columns = @[1'fr, 1'fr, 1'fr],
        rows = @[1'fr, 1'fr, 1'fr],
      )
      gt.computeLayout(initBox(0, 0, 100, 100))
      # print "grid template: ", gt

      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 33.3333) < 1.0e-3
      check abs(gt.columns[2].start.float - 66.6666) < 1.0e-3
      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3
      check abs(gt.rows[1].start.float - 33.3333) < 1.0e-3
      check abs(gt.rows[2].start.float - 66.6666) < 1.0e-3

    test "basic grid compute":
      var gt = newGridTemplate(
        columns = @[1'fr, gridLine(5.mkFixed), 1'fr, 1'fr],
      )
      gt.computeLayout(initBox(0, 0, 100, 100))
      print "grid template: ", gt

      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 33.3333) < 1.0e-3
      check abs(gt.columns[2].start.float - 66.6666) < 1.0e-3
      check abs(gt.columns[3].start.float - 66.6666) < 1.0e-3
      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3

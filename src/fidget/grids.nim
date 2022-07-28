import std/[strformat, sugar]
import std/[sequtils, strutils, hashes, sets]
import macros except `$`
import print
import commonutils

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
    grPerc
    grFixed
    grNone

  TrackSize* = object
    case kind*: GridUnits
    of grFrac:
      frac*: int
    of grAuto:
      discard
    of grPerc:
      perc*: float
    of grFixed:
      coord*: UICoord
    of grNone:
      discard
  
  LineName* = distinct string

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
proc `$`*(a: LineName): string {.borrow.}
proc hash*(a: LineName): Hash {.borrow.}
proc `repr`*(a: HashSet[LineName]): string =
  result = "{" & a.toSeq().join(", ") & "}"

proc mkFrac*(size: int): TrackSize = TrackSize(kind: grFrac, frac: size)
proc mkAuto*(): TrackSize = TrackSize(kind: grAuto)
proc mkFixed*(coord: UICoord): TrackSize = TrackSize(kind: grFixed, coord: coord)
proc mkPerc*(perc: float): TrackSize = TrackSize(kind: grPerc, perc: perc)
proc mkNoneTrack*(): TrackSize = TrackSize(kind: grNone)

proc toLineName*(name: string): LineName = LineName(name)

proc initGridLine*(
    track = mkFrac(1),
    aliases: varargs[LineName, toLineName],
): GridLine =
  GridLine(track: track, aliases: toHashSet(aliases))

proc `'fr`*(n: string): GridLine =
  ## numeric literal percent of parent height
  result = initGridLine(track=mkFrac(parseInt(n)))

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
      grPerc(): discard
      grNone(): discard
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

proc parseTmplCmd*(arg: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  var node: NimNode = arg
  while node.kind == nnkCommand:
    let item = node[0]
    node = node[1]
    # echo "GTC:item: ", item.treeRepr
    case item.kind:
    of nnkBracket:
      for x in item:
        let n = newLit x.strVal
        echo "N: ", repr n
        let res = quote do:
          gl.aliases.incl toLineName(`n`)
        echo "RES: ", res.repr
        result.add res
      # echo "bracket: ", result.repr
    of nnkDotExpr:
      # result.add grdLn
      echo "dotExper... ", repr(item)
      let n = item[0].strVal.parseInt()
      let kd = item[1].strVal
      if kd == "`ui":
        result.add quote do:
          gl = initGridLine(mkFrac(1))
      elif kd == "`perc":
        result.add quote do:
          gl = initGridLine(mkFrac(1))
      else:
        result.add quote do:
          gl = initGridLine(mkFrac(1))
      result.add quote do:
        grids.add move(gl)
    else:
      discard

proc gridTemplateParser*(args: NimNode): NimNode =
  echo "\nGTP:args: ", args.treeRepr
  result = newStmtList()
  result.add quote do:
    var grids {.inject.}: seq[GridLine]
    var gl {.inject.}: GridLine
  result.add parseTmplCmd(args)
  echo "\nGTP:result: ", result.repr

macro gridTemplateColumns*(args: untyped) =
  echo "\nGTC:args: ", args.treeRepr
  result = newStmtList()
  let cols = gridTemplateParser(args)
  result.add quote do:
    if grid.isNil:
      grid = newGridTemplate()
    `cols`
  
  echo "\nGTC:result: ", result.repr

when isMainModule:
  import unittest

  suite "grids":

    test "basic grid template":

      var gt = newGridTemplate(
        columns = @[initGridLine(mkFrac(1))],
        rows = @[initGridLine(mkFrac(1))],
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

    test "3x3 grid compute with frac's":
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

    test "4x1 grid test":
      var gt = newGridTemplate(
        columns = @[1'fr, initGridLine(5.mkFixed), 1'fr, 1'fr],
      )
      gt.computeLayout(initBox(0, 0, 100, 100))
      print "grid template: ", gt

      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 31.6666) < 1.0e-3
      check abs(gt.columns[2].start.float - 36.6666) < 1.0e-3
      check abs(gt.columns[3].start.float - 68.3333) < 1.0e-3
      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3

    test "initial macros":
      var grid: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'perc ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]

      # grid.computeLayout(initBox(0, 0, 100, 100))
      print "grid template: ", grid
      
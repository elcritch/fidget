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
    grEnd

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
    of grEnd:
      discard
  
  LineName* = distinct int

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

  GridIndex* = object
    line*: int
    isSpan*: bool
    isAuto*: bool
    isName*: bool
  
  GridItem* = ref object
    columnStart*: GridIndex
    columnEnd*: GridIndex
    rowStart*: GridIndex
    rowEnd*: GridIndex

proc `==`*(a, b: LineName): bool {.borrow.}
proc `$`*(a: LineName): string {.borrow.}
proc hash*(a: LineName): Hash {.borrow.}
proc `repr`*(a: HashSet[LineName]): string =
  result = "{" & a.toSeq().join(", ") & "}"

proc toLineName*(name: string): LineName =
  LineName(name.hash())
proc toLineNames*(names: varargs[string]): HashSet[LineName] =
  toHashSet names.toSeq().mapIt(it.toLineName())

proc mkIndex*(line: int, isSpan = false, isAuto = false, isName = false): GridIndex =
  GridIndex(line: line, isSpan: isSpan, isAuto: isAuto, isName: isName)

proc mkIndex*(name: string, isSpan = false, isAuto = false): GridIndex =
  GridIndex(line: name.toLineName().int, isSpan: isSpan, isAuto: isAuto, isName: true)

proc `columnStart=`*(item: GridItem, a: int) =
  item.columnStart = GridIndex(line: a, isSpan: false, isAuto: false, isName: false)

proc repr*(a: TrackSize): string =
  match a:
    grFrac(frac): result = $frac & "'fr"
    grFixed(coord): result = $coord & "'ui"
    grPerc(perc): result = $perc & "'perc"
    grAuto(): result = "auto"
    grEnd(): result = "ends"
proc repr*(a: GridLine): string =
  result = fmt"GL({a.track.repr}; <{$a.start} x {$a.width}'w> <- {a.aliases.repr})"
proc repr*(a: GridTemplate): string =
  result = "GridTemplate:"
  result &= "\n\tcols: "
  for c in a.columns:
    result &= &"\n\t\t{c.repr}"
  result &= "\n\trows: "
  for r in a.rows:
    result &= &"\n\t\t{r.repr}"

proc parseTmplCmd*(arg: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  var node: NimNode = arg
  proc prepareNames(item: NimNode): NimNode =
    result = newStmtList()
    for x in item:
      let n = newLit x.strVal
      result.add quote do:
        gl.aliases.incl toLineName(`n`)
  while node.kind == nnkCommand:
    var item = node[0]
    node = node[1]
    ## handle `\` for line wrap
    if node.kind == nnkInfix:
      node = nnkCommand.newTree(node[1], node[2])
    case item.kind:
    of nnkBracket:
      result.add prepareNames(item)
    of nnkIdent:
      if item.strVal != "auto":
        error("argument must be 'auto'", item)
      result.add quote do:
        gl.track = mkAuto()
        grids.add move(gl)
    of nnkDotExpr:
      let n = item[0].strVal.parseInt()
      let kd = item[1].strVal
      if kd == "'fr":
        result.add quote do:
          gl.track = mkFrac(`n`)
      elif kd == "'perc":
        result.add quote do:
          gl.track = mkPerc(`n`)
      elif kd == "'ui":
        result.add quote do:
          gl.track = mkFixed(`n`)
      else:
        error("error: unknown argument ", item)
      result.add quote do:
        grids.add move(gl)
    else:
      discard
  ## add final implicit line
  if node.kind == nnkBracket:
    result.add prepareNames(node)
  result.add quote do:
    gl.track = mkEndTrack()
    grids.add move(gl)

macro gridTemplateImpl*(args: untyped, field: untyped) =
  result = newStmtList()
  let cols = parseTmplCmd(args)
  result.add quote do:
    if gridTemplate.isNil:
      gridTemplate = newGridTemplate()
    block:
      var grids {.inject.}: seq[GridLine]
      var gl {.inject.}: GridLine
      `cols`
      gridTemplate.`field` = grids
  # echo "gridTmplImpl: ", repr field, " => "
  # echo result.repr

proc mkFrac*(size: int): TrackSize = TrackSize(kind: grFrac, frac: size)
proc mkFixed*(coord: UICoord): TrackSize = TrackSize(kind: grFixed, coord: coord)
proc mkPerc*(perc: float): TrackSize = TrackSize(kind: grPerc, perc: perc)
proc mkAuto*(): TrackSize = TrackSize(kind: grAuto)
proc mkEndTrack*(): TrackSize = TrackSize(kind: grEnd)

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
      grEnd(): discard
  fixed += spacing * lines.len().UICoord

  var
    freeSpace = length - fixed
    remSpace = max(freeSpace, 0.0'ui)
  
  # frac's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grFrac:
      grdLn.width =
        freeSpace * grdLn.track.frac.UICoord/totalFracs
      remSpace -= max(grdLn.width, 0.0'ui)
    elif grdLn.track.kind == grFixed:
      grdLn.width = grdLn.track.coord
    elif grdLn.track.kind == grPerc:
      grdLn.width = length * UICoord(grdLn.track.perc / 100.0)
      remSpace -= max(grdLn.width, 0.0'ui)
  
  # auto's
  for grdLn in lines.mitems():
    if grdLn.track.kind == grAuto:
      grdLn.width = remSpace / totalAutos.UICoord

  var cursor = 0.0'ui
  for grdLn in lines.mitems():
    grdLn.start = cursor
    cursor += grdLn.width

proc computeLayout*(grid: GridTemplate, box: Box) =
  ## computing grid layout
  if grid.columns[^1].track.kind != grEnd:
    grid.columns.add initGridLine(mkEndTrack())
  if grid.rows[^1].track.kind != grEnd:
    grid.rows.add initGridLine(mkEndTrack())
  # The free space is calculated after any non-flexible items. In 
  let
    colLen = box.w - box.x
    rowLen = box.h - box.y
  grid.columns.computeLineLayout(length=colLen, spacing=0'ui)
  grid.rows.computeLineLayout(length=rowLen, spacing=0'ui)

template gridTemplateColumns*(args: untyped) =
  gridTemplateImpl(args, columns)

template gridTemplateRows*(args: untyped) =
  gridTemplateImpl(args, rows)

proc findLine(index: GridIndex, lines: seq[GridLine]): UICoord =
  for line in lines:
    if index.line.LineName in line.aliases:
      return line.start
  raise newException(KeyError, "couldn't find index")

proc computePosition*(item: GridItem, grid: GridTemplate): Box =
  ## computing grid layout
  template setPosition(target, index, lines: untyped) =
    if not item.`index`.isName:
      result.`target` = grid.`lines`[item.`index`.line - 1].start
    else:
      result.`target` = findLine(item.`index`, grid.`lines`)
  # find positions
  setPosition(x, columnStart, columns)
  setPosition(w, columnEnd, columns)
  setPosition(y, rowStart, rows)
  setPosition(h, rowEnd, rows)
  result.w = result.w - result.x
  result.h = result.h - result.y


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
      # print "grid template: ", gt

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
      # print "grid template: ", gt

      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 31.6666) < 1.0e-3
      check abs(gt.columns[2].start.float - 36.6666) < 1.0e-3
      check abs(gt.columns[3].start.float - 68.3333) < 1.0e-3
      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3

    test "initial macros":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'perc ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]

      gridTemplate.computeLayout(initBox(0, 0, 100, 100))
      let gt = gridTemplate

      check gt.columns[0].track.kind == grFixed
      check gt.columns[0].track.coord == 40.0'ui
      check gt.columns[0].aliases == toLineNames("first")
      check gt.columns[1].track.kind == grPerc
      check gt.columns[1].track.perc == 50.0
      check gt.columns[1].aliases == toLineNames("second", "line2")
      check gt.columns[2].track.kind == grAuto
      check gt.columns[2].aliases == toLineNames("line3")
      check gt.columns[3].track.kind == grFixed
      check gt.columns[3].track.coord == 50.0'ui
      check gt.columns[3].aliases == toLineNames("col4-start")
      check gt.columns[4].track.kind == grFixed
      check gt.columns[4].track.coord == 40.0'ui
      check gt.columns[4].aliases == toLineNames("five")
      check gt.columns[5].track.kind == grEnd
      check toLineNames("end") == gt.columns[5].aliases

      # print "grid template: ", gridTemplate
      echo "grid template: ", repr gridTemplate

    test "compute macros":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      gridTemplateColumns ["first"] 40'ui \
        ["second", "line2"] 50'ui \
        ["line3"] auto \
        ["col4-start"] 50'ui \
        ["five"] 40'ui ["end"]
      gridTemplateRows ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]

      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      let gt = gridTemplate
      # print "grid template: ", gridTemplate
      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 40.0) < 1.0e-3
      check abs(gt.columns[2].start.float - 90.0) < 1.0e-3
      check abs(gt.columns[3].start.float - 910.0) < 1.0e-3
      check abs(gt.columns[4].start.float - 960.0) < 1.0e-3
      check abs(gt.columns[5].start.float - 1000.0) < 1.0e-3

      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3
      check abs(gt.rows[1].start.float - 250.0) < 1.0e-3
      check abs(gt.rows[2].start.float - 350.0) < 1.0e-3
      check abs(gt.rows[3].start.float - 1000.0) < 1.0e-3
      echo "grid template: ", repr gridTemplate
      
    test "compute macro and item layout":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]
      gridTemplateRows ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      echo "grid template: ", repr gridTemplate

      var gridItem = newGridItem()
      gridItem.columnStart = 2.mkIndex
      gridItem.columnEnd = "five".mkIndex
      gridItem.rowStart = "row1Start".mkIndex
      gridItem.rowEnd = 3.mkIndex

      let itemBox = gridItem.computePosition(gridTemplate)
      print itemBox

      
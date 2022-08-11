import std/[strformat, sugar]
import std/[sequtils, strutils, hashes, sets, tables]
import macros except `$`
import algorithm
import commonutils
import rationals
import typetraits

import print

type
  GridDir = enum
    drow
    dcol

  GridConstraint* = enum
    gcStretch
    gcStart
    gcEnd
    gcCenter

  GridUnits* = enum
    grFrac
    grAuto
    grPerc
    grFixed
    grEnd

  GridFlow* = enum
    grRow
    grRowDense
    grColumn
    grColumnDense

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
  LinePos* = int16

  GridLine* = object
    aliases*: HashSet[LineName]
    track*: TrackSize
    start*: UICoord
    width*: UICoord

  GridTemplate* = ref object
    columns*: seq[GridLine]
    rows*: seq[GridLine]
    autoColumns*: TrackSize
    autoRows*: TrackSize
    rowGap*: UICoord
    columnGap*: UICoord
    justifyItems*: GridConstraint
    alignItems*: GridConstraint
    justifyContent*: GridConstraint
    alignContent*: GridConstraint
    autoFlow*: GridFlow

  GridIndex* = object
    line*: LineName
    isSpan*: bool
    isName*: bool
  
  GridItem* = ref object
    span*: array[GridDir, Slice[int16]]
    columnStart*: GridIndex
    columnEnd*: GridIndex
    rowStart*: GridIndex
    rowEnd*: GridIndex

var lineName: Table[LineName, string]

proc `==`*(a, b: LineName): bool {.borrow.}
proc hash*(a: LineName): Hash {.borrow.}
proc hash*(a: GridItem): Hash =
  if a != nil:
    result = hash(a.span[drow]) !& hash(a.span[dcol])

proc `repr`*(a: LineName): string = lineName[a]
proc `repr`*(a: HashSet[LineName]): string =
  result = "{" & a.toSeq().mapIt(repr it).join(", ") & "}"
proc `repr`*(a: GridIndex): string =
  result = "GridIdx{" 
  result &= "" & $a.line.int
  result &= ",s:" & $a.isSpan
  result &= ",n:" & $a.isName
  result &= "}"

proc `repr`*(a: GridItem): string =
  if a != nil:
    result = "GridItem{" 
    result &= " span[dcol]: " & $a.span[dcol]
    result &= ", span[drow]: " & $a.span
    result &= "\n\t\t"
    result &= ", cS: " & repr a.columnStart
    result &= "\n\t\t"
    result &= ", cE: " & repr a.columnEnd
    result &= "\n\t\t"
    result &= ", rS: " & repr a.rowStart
    result &= "\n\t\t"
    result &= ", rE: " & repr a.rowEnd
    result &= "}"

proc toLineName*(name: int): LineName =
  result = LineName(name)
  lineName[result] = "idx:" & $name
proc toLineName*(name: string): LineName =
  result = LineName(name.hash())
  if result.int == 0:
    result = LineName(result.int + 11)
  if result in lineName:
    assert lineName[result] == name
  else:
    lineName[result] = name

proc toLineNames*(names: varargs[string]): HashSet[LineName] =
  toHashSet names.toSeq().mapIt(it.toLineName())

proc mkIndex*(line: Positive, isSpan = false, isName = false): GridIndex =
  GridIndex(line: line.toLineName(), isSpan: isSpan, isName: isName)

proc mkIndex*(name: string, isSpan = false): GridIndex =
  GridIndex(line: name.toLineName(), isSpan: isSpan, isName: true)

proc mkIndex*(index: GridIndex): GridIndex =
  result = index

proc `column=`*(item: GridItem, rat: Rational[int]) =
  item.columnStart = rat.num.mkIndex
  item.columnEnd = rat.den.mkIndex
proc `row=`*(item: GridItem, rat: Rational[int]) =
  item.rowStart = rat.num.mkIndex
  item.rowEnd = rat.den.mkIndex


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

proc parseTmplCmd*(tgt, arg: NimNode): (int, NimNode) {.compileTime.} =
  result = (0, newStmtList())
  var idx = 0
  var named = false
  var idxLit: NimNode = newIntLitNode(idx)
  var node: NimNode = arg
  template idxIncr() =
    idx.inc
    named = false
    idxLit = newIntLitNode(idx)
  proc handleDotExpr(result, item, tgt: NimNode) =
    let n = item[0].strVal.parseInt()
    let kd = item[1].strVal
    if kd == "'fr":
      result.add quote do:
        `tgt`[`idxLit`].track = mkFrac(`n`)
    elif kd == "'perc":
      result.add quote do:
        `tgt`[`idxLit`].track = mkPerc(`n`)
    elif kd == "'ui":
      result.add quote do:
        `tgt`[`idxLit`].track = mkFixed(`n`)
    else:
      error("error: unknown argument ", item)
  proc prepareNames(item: NimNode): NimNode =
    result = newStmtList()
    for x in item:
      let n = newLit x.strVal
      result.add quote do:
        `tgt`[`idxLit`].aliases.incl toLineName(`n`)
  while node.kind == nnkCommand:
    var item = node[0]
    node = node[1]
    ## handle `\` for line wrap
    if node.kind == nnkInfix:
      node = nnkCommand.newTree(node[1], node[2])
    case item.kind:
    of nnkBracket:
      result[1].add prepareNames(item)
      named = true
    of nnkIdent:
      if item.strVal != "auto":
        error("argument must be 'auto'", item)
      result[1].add quote do:
        `tgt`[`idxLit`].track = mkAuto()
      idxIncr()
    of nnkDotExpr:
      result[1].handleDotExpr(item, tgt)
      idxIncr()
    else:
      discard
  ## add final implicit line
  if node.kind == nnkBracket:
    result[1].add prepareNames(node)
  elif node.kind == nnkDotExpr:
    var item = node
    result[1].handleDotExpr(item, tgt)
    idxIncr()

  result[1].add quote do:
    `tgt`[`idxLit`].track = mkEndTrack()
    # grids.add move(gl)
  result[0] = idx + 1

macro gridTemplateImpl*(gridTmpl, args: untyped, field: untyped) =
  result = newStmtList()
  let tgt = quote do:
    `gridTmpl`.`field`
  let (colCount, cols) = parseTmplCmd(tgt, args)
  result.add quote do:
    if `gridTmpl`.isNil:
      `gridTmpl` = newGridTemplate()
    block:
      if `gridTmpl`.`field`.len() < `colCount`:
        `gridTmpl`.`field`.setLen(`colCount`)
        `cols`

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
  result.autoColumns = mkFixed(0)
  result.autoRows = mkFixed(0)

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
  fixed += spacing * UICoord(lines.len() - 1)

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
    cursor += grdLn.width + spacing

proc computeLayout*(grid: GridTemplate, box: Box) =
  ## computing grid layout
  if grid.columns[^1].track.kind != grEnd:
    grid.columns.add initGridLine(mkEndTrack())
  if grid.rows[^1].track.kind != grEnd:
    grid.rows.add initGridLine(mkEndTrack())
  # The free space is calculated after any non-flexible items. In 
  let
    colLen = box.w
    rowLen = box.h
  grid.columns.computeLineLayout(length=colLen, spacing=grid.columnGap)
  grid.rows.computeLineLayout(length=rowLen, spacing=grid.rowGap)

proc reComputeLayout(grid: GridTemplate) =
  var w, h: float32
  for col in grid.columns:
    if col.track.kind == grEnd:
      w = col.start.float32
      break
  for row in grid.rows:
    if row.track.kind == grEnd:
      h = row.start.float32
      break
  # echo "reCompute"
  grid.computeLayout(initBox(0, 0, w, h))

template parseGridTemplateColumns*(gridTmpl, args: untyped) =
  gridTemplateImpl(gridTmpl, args, columns)

template parseGridTemplateRows*(gridTmpl, args: untyped) =
  gridTemplateImpl(gridTmpl, args, rows)

proc findLine(index: GridIndex, lines: seq[GridLine]): int16 =
  for i, line in lines:
    if index.line in line.aliases:
      return int16(i+1)
  raise newException(KeyError, "couldn't find index: " & repr index)

proc getGrid(lines: seq[GridLine], idx: int): UICoord =
  # if idx == -2: lines[idx-1].start else: lines[^1].start
  lines[idx-1].start

proc setGridSpans(
    item: GridItem,
    grid: GridTemplate,
    contentSize: Position
) =
  ## computing grid layout
  template gridAutoInsert(target, index, lines, idx, cz: untyped) =
    assert idx <= 1000, "max grids exceeded"
    if idx >= grid.`lines`.len():
      while idx >= grid.`lines`.len():
        let offset = grid.`lines`.len() - 1
        var ln = initGridLine(track = grid.`auto lines`)
        if offset+1 == idx and ln.track.kind == grFixed:
          # echo "insert: ", offset+1, "@", idx, "/", grid.`lines`.len()
          ln.track.coord = max(ln.track.coord, cz)
        grid.`lines`.insert(ln, offset)
      grid.reComputeLayout()
  
  template setSpan(index, lines, cz: untyped): int16 =
    ## todo: clean this up? maybe use static bools for col vs row
    if not item.`index`.isName:
      let idx = item.`index`.line.int - 1
      gridAutoInsert(target, index, lines, idx, cz)
      item.`index`.line.int16
    else:
      findLine(item.`index`, grid.`lines`)
  assert not item.isNil

  if item.span[dcol].a == 0:
    item.span[dcol].a = setSpan(columnStart, columns, 0)
  if item.span[dcol].b == 0:
    item.span[dcol].b = setSpan(columnEnd, columns, contentSize.x)

  if item.span[drow].a == 0:
    item.span[drow].a = setSpan(rowStart, rows, 0)
  if item.span[drow].b == 0:
    item.span[drow].b = setSpan(rowEnd, rows, contentSize.x)

proc computePosition*(
    item: GridItem,
    grid: GridTemplate,
    contentSize: Position
): Box =
  ## computing grid layout
  assert not item.isNil
  item.setGridSpans(grid, contentSize)

  # set columns
  result.x = grid.columns.getGrid(item.span[dcol].a)
  let rxw = grid.columns.getGrid(item.span[dcol].b)
  let rww = (rxw - result.x) - grid.columnGap
  case grid.justifyItems:
  of gcStretch:
    result.w = rww
  of gcCenter:
    result.x = result.x + (rww - contentSize.x)/2.0
    result.w = contentSize.x
  of gcStart:
    result.w = contentSize.x
  of gcEnd:
    result.x = rxw - contentSize.x
    result.w = contentSize.x

  # set rows
  result.y = grid.rows.getGrid(item.span[drow].a)
  let ryh = grid.rows.getGrid(item.span[drow].b)
  let rhh = (ryh - result.y) - grid.rowGap
  case grid.alignItems:
  of gcStretch:
    result.h = rhh
  of gcCenter:
    result.y = result.y + (rhh - contentSize.y)/2.0
    result.h = contentSize.y
  of gcStart:
    result.h = contentSize.y
  of gcEnd:
    result.y = ryh - contentSize.y
    result.h = contentSize.y

proc fixedCount*(gridItem: GridItem): range[0..4] =
  if gridItem.columnStart.line.int != 0: result.inc
  if gridItem.columnEnd.line.int != 0: result.inc
  if gridItem.rowStart.line.int != 0: result.inc
  if gridItem.rowEnd.line.int != 0: result.inc

proc isAutoPositioned*(gridItem: GridItem): bool =
  gridItem.fixedCount() == 0

type
  GridNode = ref object
    id: string
    box: Box
    gridItem: GridItem

proc `in`[N](cur: (LinePos, LinePos), col: HashSet[N]): bool =
  for item in col:
    if cur[0] in item.span[dcol] and cur[1] in item.span[drow]:
      return true

proc computeAutoFlow[N](
    gridTemplate: GridTemplate,
    node: N,
    allNodes: seq[N],
) =
  let mx = dcol
  let my = drow
  template mjLines(x: untyped): untyped = x.columns
  template mnLines(x: untyped): untyped = x.rows

  # setup caches
  var autos = newSeqOfCap[N](allNodes.len())
  var fixedCache = newTable[LinePos, HashSet[GridItem]]()
  for i in 1..gridTemplate.mjLines.len():
    fixedCache[i.LinePos] = initHashSet[GridItem]()

  # populate caches
  for child in allNodes:
    if child.gridItem == nil:
      child.gridItem = GridItem()
    if fixedCount(child.gridItem) == 4:
      let item = child.gridItem
      for j in child.gridItem.span[mx]:
        fixedCache[j].incl item
    else:
      autos.add child

  # sort majors by main index
  var cursor = (1.LinePos, 1.LinePos)
  var i = 0

  echo "children: auto flow: ",
        repr (gridTemplate.columns.len(), gridTemplate.rows.len(), )
  template nextMinor(blk, outer: untyped) =
    cursor[0] = 1
    cursor[1].inc
    echo "  .. new minor -- incr majors idx: ", fixedCache[cursor[0]].len(), " => ", cursor.repr
    if cursor[1] >= gridTemplate.mnLines.len():
      echo "  .. new minor -- breaking; minor's overflow"
      break outer
    break blk
  template incrCursor(amt, blk, outer: untyped) =
    echo "  ++ inc'ing: cursor: ", autos[i].id, "[", i, "]", " => idx: ", cursor.repr
    cursor[0].inc
    if cursor[0] > gridTemplate.mjLines.len():
      nextMinor(blk, outer)
  block autoflow:
    while i < len(autos):
      echo "child: auto flow: ", autos[i].id, " [", i, "]", " @ ", repr cursor
      block childBlock:
        ## increment cursor and index until one breaks the mold
        while cursor in fixedCache[cursor[0]]:
          # incrCursor(1 + (fixedCache[cursor[0]][0].b - cursor[0] - 1), childBlock, autoFlow)
          incrCursor(1, childBlock, autoFlow)
          echo "  .. incr index of major cache: ", fixedCache[cursor[0]].len(), " @ ", cursor.repr
        while not (cursor in fixedCache[cursor[0]]):
          echo "  ++ set cursor[0]: ", cursor.repr, " -> ", autos[i].id, "[", i, "]", " :: ", fixedCache[cursor[0]].len
          autos[i].gridItem.span[mx] = cursor[0] .. cursor[0] + 1
          autos[i].gridItem.span[my] = cursor[1] .. cursor[1] + 1
          # mjSpan(autos[i]) = cursor[0] .. cursor[0] + 1
          # mnSpan(autos[i]) = cursor[1] .. cursor[1] + 1
          i.inc
          if i >= autos.len():
            break autoflow
          incrCursor(1, childBlock, autoFlow)
  # # set rest to -1
  # if i >= children.len():
  #   return
  # for j in i ..< children.len():
  #   if fixedCount(children[i].gridItem) == 0:
  #     children[j].gridItem.span[dcol] = -1'i16 .. -1'i16
  #     children[j].gridItem.span[drow] = -1'i16 .. -1'i16

proc computeGridLayout*[N](
    gridTemplate: GridTemplate,
    node: N,
    children: seq[N],
) =
  ## implement full(ish) CSS grid algorithm here
  ## currently assumes that `N`, the ref object, has
  ## both `box: Box` and `gridItem: GridItem` fields. 
  ## 
  ## this algorithm tries to follow the specification at:
  ##   https://www.w3.org/TR/css3-grid-layout/#grid-item-placement-algorithm
  ## 
  
  gridTemplate.computeLayout(node.box)
  echo "gridTemplate: ", gridTemplate.repr

  for child in children:
    if child.gridItem == nil:
      # ensure all grid children have a GridItem
      child.gridItem = GridItem()
    elif fixedCount(child.gridItem) == 4:
      # compute positions for fixed children
      child.box = child.gridItem.computePosition(gridTemplate, child.box.wh)
    
  # compute positions for partially fixed children
  for child in children:
    if fixedCount(child.gridItem) in 1..3:
      # child.box = child.gridItem.computePosition(gridTemplate, child.box.wh)
      assert false, "todo: implement me!"

  # compute positions for auto flow items
  computeAutoFlow(gridTemplate, node, children)

  for child in children:
    if fixedCount(child.gridItem) == 0:
      # print "child: ", child.gridItem
      if 0 notin child.gridItem.span[dcol] and
          0 notin child.gridItem.span[drow]:
        child.box = child.gridItem.computePosition(gridTemplate, child.box.wh)
        echo "child:id: ", child.id, " box: ", child.box.repr

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
      parseGridTemplateColumns gridTemplate, ["first"] 40'ui ["second", "line2"] 50'perc ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]

      # gridTemplate.computeLayout(initBox(0, 0, 100, 100))
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
      # echo "grid template: ", repr gridTemplate

    test "compute macros":
      var tmpl: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns tmpl, ["first"] 40'ui \
        ["second", "line2"] 50'ui \
        ["line3"] auto \
        ["col4-start"] 50'ui \
        ["five"] 40'ui ["end"]
      parseGridTemplateRows tmpl, ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]

      tmpl.computeLayout(initBox(0, 0, 1000, 1000))
      let gt = tmpl
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
      # echo "grid template: ", repr tmpl
      
    test "compute others":
      var gt: GridTemplate

      parseGridTemplateColumns gt, ["first"] 40'ui \
        ["second", "line2"] 50'ui \
        ["line3"] auto \
        ["col4-start"] 50'ui \
        ["five"] 40'ui ["end"]
      parseGridTemplateRows gt, ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]

      gt.columnGap = 10'ui
      gt.rowGap = 10'ui
      gt.computeLayout(initBox(0, 0, 1000, 1000))
      # print "grid template: ", gt
      check abs(gt.columns[0].start.float - 0.0) < 1.0e-3
      check abs(gt.columns[1].start.float - 40.0 - 10.0) < 1.0e-3
      check abs(gt.columns[2].start.float - 90.0 - 20.0) < 1.0e-3
      check abs(gt.columns[3].start.float - 910.0 + 20.0) < 1.0e-3
      check abs(gt.columns[4].start.float - 960.0 + 10.0) < 1.0e-3
      check abs(gt.columns[5].start.float - 1000.0) < 1.0e-3

      check abs(gt.rows[0].start.float - 0.0) < 1.0e-3
      check abs(gt.rows[1].start.float - 250.0 - 10.0) < 1.0e-3
      check abs(gt.rows[2].start.float - 350.0 - 20.0) < 1.0e-3
      check abs(gt.rows[3].start.float - 1000.0) < 1.0e-3
      
    test "compute macro and item layout":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns gridTemplate, ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]
      parseGridTemplateRows gridTemplate, ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      echo "grid template: ", repr gridTemplate

      var gridItem = newGridItem()
      gridItem.columnStart = 2.mkIndex
      gridItem.columnEnd = "five".mkIndex
      gridItem.rowStart = "row1-start".mkIndex
      gridItem.rowEnd = 3.mkIndex
      print gridItem

      let contentSize = initPosition(0, 0)
      let itemBox = gridItem.computePosition(gridTemplate, contentSize)
      print itemBox
      print "post: ", gridItem

      check gridItem.span[dcol].a == 2
      check gridItem.span[dcol].b == 5
      check abs(itemBox.x.float - 40.0) < 1.0e-3
      check abs(itemBox.w.float - 920.0) < 1.0e-3
      check abs(itemBox.y.float - 0.0) < 1.0e-3
      check abs(itemBox.h.float - 350.0) < 1.0e-3

    test "compute macro and item layout":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns gridTemplate, ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]
      parseGridTemplateRows gridTemplate, ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      # echo "grid template: ", repr gridTemplate

      var gridItem = newGridItem()
      gridItem.columnStart = 2.mkIndex
      gridItem.columnEnd = "five".mkIndex
      gridItem.rowStart = "row1-start".mkIndex
      gridItem.rowEnd = 3.mkIndex
      # print gridItem

      let contentSize = initPosition(500, 200)
      var itemBox: Box

      ## test stretch
      itemBox = gridItem.computePosition(gridTemplate, contentSize)
      # print itemBox
      check abs(itemBox.x.float - 40.0) < 1.0e-3
      check abs(itemBox.w.float - 920.0) < 1.0e-3
      check abs(itemBox.y.float - 0.0) < 1.0e-3
      check abs(itemBox.h.float - 350.0) < 1.0e-3

      ## test start
      gridTemplate.justifyItems = gcStart
      gridTemplate.alignItems = gcStart
      itemBox = gridItem.computePosition(gridTemplate, contentSize)
      # print itemBox
      check abs(itemBox.x.float - 40.0) < 1.0e-3
      check abs(itemBox.w.float - 500.0) < 1.0e-3
      check abs(itemBox.y.float - 0.0) < 1.0e-3
      check abs(itemBox.h.float - 200.0) < 1.0e-3

      ## test end
      gridTemplate.justifyItems = gcEnd
      gridTemplate.alignItems = gcEnd
      itemBox = gridItem.computePosition(gridTemplate, contentSize)
      print itemBox
      check abs(itemBox.x.float - 460.0) < 1.0e-3
      check abs(itemBox.w.float - 500.0) < 1.0e-3
      check abs(itemBox.y.float - 150.0) < 1.0e-3
      check abs(itemBox.h.float - 200.0) < 1.0e-3
      
      ## test start / stretch
      gridTemplate.justifyItems = gcStart
      gridTemplate.alignItems = gcStretch
      itemBox = gridItem.computePosition(gridTemplate, contentSize)
      # print itemBox
      check abs(itemBox.x.float - 40.0) < 1.0e-3
      check abs(itemBox.w.float - 500.0) < 1.0e-3
      check abs(itemBox.y.float - 0.0) < 1.0e-3
      check abs(itemBox.h.float - 350.0) < 1.0e-3
      
    test "compute layout with auto columns":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns gridTemplate, ["a"] 60'ui ["b"] 60'ui
      parseGridTemplateRows gridTemplate, 90'ui 90'ui
      # echo "grid template pre: ", repr gridTemplate
      check gridTemplate.columns.len() == 3
      check gridTemplate.rows.len() == 3
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      # echo "grid template: ", repr gridTemplate

      let contentSize = initPosition(30, 30)

      # item a
      var itema = newGridItem()
      itema.column= 1 // 2
      itema.row= 2 // 3

      let boxa = itema.computePosition(gridTemplate, contentSize)
      # echo "grid template post: ", repr gridTemplate
      # print boxa

      check abs(boxa.x.float - 0.0) < 1.0e-3
      check abs(boxa.w.float - 60.0) < 1.0e-3
      check abs(boxa.y.float - 90.0) < 1.0e-3
      check abs(boxa.h.float - 90.0) < 1.0e-3

      # item b
      var itemb = newGridItem()
      itemb.column= 5 // 6
      itemb.row= 2 // 3

      let boxb = itemb.computePosition(gridTemplate, contentSize)
      # echo "grid template post: ", repr gridTemplate
      # print boxb

      check abs(boxb.x.float - 120.0) < 1.0e-3
      check abs(boxb.w.float - 30.0) < 1.0e-3
      check abs(boxb.y.float - 90.0) < 1.0e-3
      check abs(boxb.h.float - 90.0) < 1.0e-3

    test "compute layout with auto columns with fixed size":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns gridTemplate, ["a"] 60'ui ["b"] 60'ui
      parseGridTemplateRows gridTemplate, 90'ui 90'ui
      gridTemplate.autoColumns = 60.mkFixed()
      gridTemplate.autoRows = 20.mkFixed()
      # echo "grid template pre: ", repr gridTemplate
      check gridTemplate.columns.len() == 3
      check gridTemplate.rows.len() == 3
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      # echo "grid template: ", repr gridTemplate

      let contentSize = initPosition(30, 30)

      # item a
      var itema = newGridItem()
      itema.column= 1 // 2
      itema.row= 2 // 3

      let boxa = itema.computePosition(gridTemplate, contentSize)
      # echo "grid template post: ", repr gridTemplate
      # print boxa

      check abs(boxa.x.float - 0.0) < 1.0e-3
      check abs(boxa.w.float - 60.0) < 1.0e-3
      check abs(boxa.y.float - 90.0) < 1.0e-3
      check abs(boxa.h.float - 90.0) < 1.0e-3

      # item b
      var itemb = newGridItem()
      itemb.column= 5 // 6
      itemb.row= 3 // 4

      let boxb = itemb.computePosition(gridTemplate, contentSize)
      # echo "grid template post: ", repr gridTemplate
      # print boxb

      check abs(boxb.x.float - 240.0) < 1.0e-3
      check abs(boxb.w.float - 60.0) < 1.0e-3
      check abs(boxb.y.float - 180.0) < 1.0e-3
      check abs(boxb.h.float - 30.0) < 1.0e-3

    test "compute layout with auto flow":
      var gridTemplate: GridTemplate

      # grid-template-columns: [first] 40px [line2] 50px [line3] auto [col4-start] 50px [five] 40px [end];
      parseGridTemplateColumns gridTemplate, 60'ui 60'ui 60'ui 60'ui 60'ui
      parseGridTemplateRows gridTemplate, 33'ui 33'ui
      gridTemplate.justifyItems = gcStretch
      # echo "grid template pre: ", repr gridTemplate
      check gridTemplate.columns.len() == 6
      check gridTemplate.rows.len() == 3
      gridTemplate.computeLayout(initBox(0, 0, 1000, 1000))
      # echo "grid template: ", repr gridTemplate
      var parent = GridNode()

      let contentSize = initPosition(30, 30)
      var nodes = newSeq[GridNode](8)

      # item a
      var itema = newGridItem()
      itema.column= 1 // 2
      itema.row= 1 // 3
      # let boxa = itema.computePosition(gridTemplate, contentSize)
      nodes[0] = GridNode(id: "a", gridItem: itema)

      # ==== item e ====
      var iteme = newGridItem()
      iteme.column= 5 // 6
      iteme.row= 1 // 3
      nodes[1] = GridNode(id: "e", gridItem: iteme)

      # ==== item b's ====
      for i in 2 ..< nodes.len():
        nodes[i] = GridNode(id: "b" & $(i-2))

      # ==== process grid ====
      gridTemplate.computeGridLayout(parent, nodes)

      echo "grid template post: ", repr gridTemplate
      # ==== item a ====
      check abs(nodes[0].box.x.float - 0.0) < 1.0e-3
      check abs(nodes[0].box.w.float - 60.0) < 1.0e-3
      check abs(nodes[0].box.y.float - 0.0) < 1.0e-3
      check abs(nodes[0].box.h.float - 66.0) < 1.0e-3

      # ==== item e ====
      print nodes[1].box
      check abs(nodes[1].box.x.float - 240.0) < 1.0e-3
      check abs(nodes[1].box.w.float - 60.0) < 1.0e-3
      check abs(nodes[1].box.y.float - 0.0) < 1.0e-3
      check abs(nodes[1].box.h.float - 66.0) < 1.0e-3

      # ==== item b's ====
      for i in 2 ..< nodes.len():
        echo "auto child:cols: ", nodes[i].id, " :: ", nodes[i].gridItem.span[dcol].repr, " x ", nodes[i].gridItem.span[drow].repr
        echo "auto child:cols: ", nodes[i].gridItem.repr
        echo "auto child:box: ", nodes[i].id, " => ", nodes[i].box

      check abs(nodes[2].box.x.float - 60.0) < 1.0e-3
      check abs(nodes[3].box.x.float - 120.0) < 1.0e-3
      check abs(nodes[4].box.x.float - 180.0) < 1.0e-3

      check abs(nodes[2].box.y.float - 0.0) < 1.0e-3
      check abs(nodes[3].box.y.float - 0.0) < 1.0e-3
      check abs(nodes[4].box.y.float - 0.0) < 1.0e-3

      check abs(nodes[5].box.x.float - 60.0) < 1.0e-3
      check abs(nodes[6].box.x.float - 120.0) < 1.0e-3

      check abs(nodes[5].box.y.float - 33.0) < 1.0e-3
      check abs(nodes[6].box.y.float - 33.0) < 1.0e-3
      check abs(nodes[7].box.y.float - 33.0) < 1.0e-3

      # check abs(nodes[8].box.x.float - 0.0) < 1.0e-3
      # check abs(nodes[8].box.y.float - 0.0) < 1.0e-3

      for i in 2 ..< nodes.len() - 1:
        check abs(nodes[i].box.w.float - 60.0) < 1.0e-3
        check abs(nodes[i].box.h.float - 33.0) < 1.0e-3


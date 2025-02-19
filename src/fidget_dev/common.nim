import sequtils, tables, json, hashes
import strformat
import unicode
import typetraits
import variant, chroma, input
import cssgrid

import commonutils

export sequtils, strformat, tables, hashes
export variant
# export unicode
export commonutils
export cssgrid

import print

when defined(js):
  import dom2, html/ajax
else:
  import typography, asyncfutures
  import patches/textboxes 

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

when defined(js) or defined(StringUID):
  type NodeUID* = string
else:
  type NodeUID* = int64

type
  FidgetConstraint* = enum
    cMin
    cMax
    cScale
    cStretch
    cCenter

  HAlign* = enum
    hLeft
    hCenter
    hRight

  VAlign* = enum
    vTop
    vCenter
    vBottom

  TextAutoResize* = enum
    ## Should text element resize and how.
    tsNone
    tsWidthAndHeight
    tsHeight

  TextStyle* = object
    ## Holder for text styles.
    fontFamily*: string
    fontSize*: UICoord
    fontWeight*: UICoord
    lineHeight*: UICoord
    textAlignHorizontal*: HAlign
    textAlignVertical*: VAlign
    autoResize*: TextAutoResize
    textPadding*: int

  BorderStyle* = object
    ## What kind of border.
    color*: Color
    width*: float32

  LayoutAlign* = enum
    ## Applicable only inside auto-layout frames.
    laMin
    laCenter
    laMax
    laStretch
    laIgnore

  LayoutMode* = enum
    ## The auto-layout mode on a frame.
    lmNone
    lmVertical
    lmHorizontal
    lmGrid

  CounterAxisSizingMode* = enum
    ## How to deal with the opposite side of an auto-layout frame.
    csAuto
    csFixed

  ShadowStyle* = enum
    ## Supports drop and inner shadows.
    DropShadow
    InnerShadow

  ZLevel* = enum
    ## The z-index for widget interactions
    ZLevelBottom
    ZLevelLower
    ZLevelDefault
    ZLevelRaised
    ZLevelOverlay

  Shadow* = object
    kind*: ShadowStyle
    blur*: UICoord
    x*: UICoord
    y*: UICoord
    color*: Color

  Stroke* = object
    weight*: float32 # not uicoord?
    color*: Color

  NodeKind* = enum
    ## Different types of nodes.
    nkRoot
    nkFrame
    nkGroup
    nkImage
    nkText
    nkRectangle
    nkComponent
    nkInstance
    nkDrawable
    nkScrollBar

  ImageStyle* = object
    name*: string
    color*: Color

  Node* = ref object
    id*: string
    uid*: NodeUID
    idPath*: string
    kind*: NodeKind
    text*: seq[Rune]
    code*: string
    cxSize*: array[GridDir, Constraint]
    cxOffset*: array[GridDir, Constraint]
    nodes*: seq[Node]
    box*: Box
    orgBox*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    hasRendered*: bool
    rotation*: float32
    fill*: Color
    transparency*: float32
    stroke*: Stroke
    resizeDone*: bool
    htmlDone*: bool
    textStyle*: TextStyle
    image*: ImageStyle
    cornerRadius*: (UICoord, UICoord, UICoord, UICoord)
    editableText*: bool
    multiline*: bool
    bindingSet*: bool
    drawable*: bool
    cursorColor*: Color
    highlightColor*: Color
    disabledColor*: Color
    shadows*: seq[Shadow]
    constraintsHorizontal*: FidgetConstraint
    constraintsVertical*: FidgetConstraint
    layoutAlign*: LayoutAlign
    layoutMode*: LayoutMode
    counterAxisSizingMode*: CounterAxisSizingMode
    gridTemplate*: GridTemplate
    gridItem*: GridItem
    horizontalPadding*: UICoord
    verticalPadding*: UICoord
    itemSpacing*: UICoord
    clipContent*: bool
    nIndex*: int
    diffIndex*: int
    events*: InputEvents
    listens*: ListenEvents
    zlevel*: ZLevel
    when not defined(js):
      textLayout*: seq[GlyphPosition]
    else:
      element*: Element
      textElement*: Element
      cache*: Node
    textLayoutHeight*: UICoord
    textLayoutWidth*: UICoord
    ## Can the text be selected.
    selectable*: bool
    scrollpane*: bool
    userStates*: Table[int, Variant]
    userEvents*: Events
    points*: seq[Position]

  GenericEvents*[T] = object
    data*: TableRef[TypeId, Variant]

  Events* = GenericEvents[void]
  
  KeyState* = enum
    Empty
    Up
    Down
    Repeat
    Press # Used for text input

  MouseCursorStyle* = enum
    Default
    Pointer
    Grab
    NSResize

  Mouse* = ref object
    pos*: Vec2
    delta*: Vec2
    prevPos*: Vec2
    pixelScale*: float32
    wheelDelta*: float32
    cursorStyle*: MouseCursorStyle ## Sets the mouse cursor icon
    prevCursorStyle*: MouseCursorStyle
    consumed*: bool ## Consumed - need to prevent default action.
    clickedOutside*: bool ## 

  Keyboard* = ref object
    state*: KeyState
    consumed*: bool ## Consumed - need to prevent default action.
    keyString*: string
    altKey*: bool
    ctrlKey*: bool
    shiftKey*: bool
    superKey*: bool
    focusNode*: Node
    onFocusNode*: Node
    onUnFocusNode*: Node
    input*: seq[Rune]
    textCursor*: int ## At which character in the input string are we
    selectionCursor*: int ## To which character are we selecting to
  
  MouseEventType* {.size: sizeof(int16).} = enum
    evClick
    evClickOut
    evHover
    evHoverOut
    evOverlapped
    evPress
    evRelease

  KeyboardEventType* {.size: sizeof(int16).} = enum
    evKeyboardInput
    evKeyboardFocus
    evKeyboardFocusOut

  GestureEventType* {.size: sizeof(int16).} = enum
    evScroll
    evDrag # TODO: implement this!?

  MouseEventFlags* = set[MouseEventType]
  KeyboardEventFlags* = set[KeyboardEventType]
  GestureEventFlags* = set[GestureEventType]

  InputEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags
  ListenEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags

  EventsCapture*[T] = object
    zlvl*: ZLevel
    flags*: T
    target*: Node

  MouseCapture* = EventsCapture[MouseEventFlags] 
  GestureCapture* = EventsCapture[GestureEventFlags] 

  CapturedEvents = object
    mouse*: MouseCapture
    gesture*: GestureCapture

type
  HttpStatus* = enum
    Starting
    Ready
    Loading
    Error

  HttpCall* = ref object
    status*: HttpStatus
    data*: string
    json*: JsonNode
    when defined(js):
      httpRequest*: XMLHttpRequest
    else:
      future*: Future[string]

type
    MouseEvent* = object
      case kind*: MouseEventType
      of evClick: discard
      of evClickOut: discard
      of evHover: discard
      of evHoverOut: discard
      of evOverlapped: discard
      of evPress: discard
      of evRelease: discard

    KeyboardEvent* = object
      case kind*: KeyboardEventType
      of evKeyboardInput: discard
      of evKeyboardFocus: discard
      of evKeyboardFocusOut: discard

    GestureEvent* = object
      case kind*: GestureEventType
      of evScroll: discard
      of evDrag: discard

proc toEvent*(kind: MouseEventType): MouseEvent =
  MouseEvent(kind: kind)
proc toEvent*(kind: KeyboardEventType): KeyboardEvent =
  KeyboardEvent(kind: kind)
proc toEvent*(kind: GestureEventType): GestureEvent =
  GestureEvent(kind: kind)

const
  DataDirPath* {.strdefine.} = "data"

var
  parent*: Node
  root*: Node
  prevRoot*: Node
  nodeStack*: seq[Node]
  gridStack*: seq[GridTemplate]
  current*: Node
  scrollBox*: Box
  scrollBoxMega*: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini*: Box ## Scroll box is smaller by 100px useful for debugging
  mouse* = Mouse()
  keyboard* = Keyboard()
  requestedFrame*: int
  numNodes*: int
  popupActive*: bool
  inPopup*: bool
  popupBox*: Box
  fullscreen* = false
  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2    ## Screen coordinates
  windowFrame*: Vec2   ## Pixel coordinates
  pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32 ## Pixel multiplier user wants on the UI

  # Used to check for duplicate ID paths.
  pathChecker*: Table[string, bool]

  computeTextLayout*: proc(node: Node)

  lastUId: int
  nodeLookup*: Table[string, Node]

  dataDir*: string = DataDirPath

  ## Used for HttpCalls
  httpCalls*: Table[string, HttpCall]

  # UI Scale
  uiScale*: float32 = 1.0
  autoUiScale*: bool = true

  defaultlineHeightRatio* = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* = rgba(137, 137, 137, 162).color

proc defaultLineHeight*(fontSize: UICoord): UICoord =
  result = fontSize * defaultlineHeightRatio
proc defaultLineHeight*(ts: TextStyle): UICoord =
  result = defaultLineHeight(ts.fontSize)

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Image style
  result = ImageStyle(name: name, color: color)

when not defined(js):
  var
    currTextBox*: TextBox[Node]
    fonts*: Table[string, Font]

  func hAlignMode*(align: HAlign): HAlignMode =
    case align:
      of hLeft: HAlignMode.Left
      of hCenter: Center
      of hRight: HAlignMode.Right

  func vAlignMode*(align: VAlign): VAlignMode =
    case align:
      of vTop: Top
      of vCenter: Middle
      of vBottom: Bottom

mouse = Mouse()
mouse.pos = vec2(0, 0)

# proc `$`*(a: Rect): string =
  # fmt"({a.x:6.2f}, {a.y:6.2f}; {a.w:6.2f}x{a.h:6.2f})"

proc x*(mouse: Mouse): UICoord = mouse.pos.descaled.x
proc y*(mouse: Mouse): UICoord = mouse.pos.descaled.x

proc setNodePath*(node: Node) =
  node.idPath = ""
  for i, g in nodeStack:
    if i != 0:
      node.idPath.add "."
    if g.id != "":
      node.idPath.add g.id
    else:
      node.idPath.add $g.diffIndex

proc dumpTree*(node: Node, indent = "") =

  echo indent, "`", node.id, "`", " sb: ", $node.screenBox
  for n in node.nodes:
    dumpTree(n, "  " & indent)

iterator reverse*[T](a: openArray[T]): T {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield a[i]
    dec i

iterator reversePairs*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (a.len - 1 - i, a[i])
    dec i

iterator reverseIndex*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (i, a[i])
    dec i

proc resetToDefault*(node: Node)=
  ## Resets the node to default state.
  # node.id = ""
  # node.uid = ""
  # node.idPath = ""
  # node.kind = nkRoot
  node.text = "".toRunes()
  node.code = ""
  # node.nodes = @[]
  node.box = initBox(0,0,0,0)
  node.orgBox = initBox(0,0,0,0)
  node.rotation = 0
  # node.screenBox = rect(0,0,0,0)
  # node.offset = vec2(0, 0)
  node.fill = clearColor
  node.transparency = 0
  node.stroke = Stroke(weight: 0, color: clearColor)
  node.resizeDone = false
  node.htmlDone = false
  node.textStyle = TextStyle()
  node.image = ImageStyle(name: "", color: whiteColor)
  node.cornerRadius = (0'ui, 0'ui, 0'ui, 0'ui)
  node.editableText = false
  node.multiline = false
  node.bindingSet = false
  node.drawable = false
  node.cursorColor = clearColor
  node.highlightColor = clearColor
  node.shadows = @[]
  node.gridTemplate = nil
  node.gridItem = nil
  node.constraintsHorizontal = cMin
  node.constraintsVertical = cMin
  node.layoutAlign = laMin
  node.layoutMode = lmNone
  node.counterAxisSizingMode = csAuto
  node.horizontalPadding = 0'ui
  node.verticalPadding = 0'ui
  node.itemSpacing = 0'ui
  node.clipContent = false
  node.diffIndex = 0
  node.zlevel = ZLevelDefault
  node.selectable = false
  node.scrollpane = false
  node.hasRendered = false
  node.userStates = initTable[int, Variant]()

proc setupRoot*() =
  if root == nil:
    root = Node()
    root.kind = nkRoot
    root.id = "root"
    root.uid = newUId()
    root.zlevel = ZLevelDefault
    root.cursorColor = rgba(0, 0, 0, 255).color
  nodeStack = @[root]
  current = root
  root.diffIndex = 0

proc emptyFuture*(): Future[void] =
  result = newFuture[void]()
  result.complete()

proc clearInputs*() =

  mouse.wheelDelta = 0
  mouse.consumed = false
  mouse.clickedOutside = false

  # Reset key and mouse press to default state
  for i in 0 ..< buttonPress.len:
    buttonPress[i] = false
    buttonRelease[i] = false

  if any(buttonDown, proc(b: bool): bool = b):
    keyboard.state = KeyState.Down
  else:
    keyboard.state = KeyState.Empty

const
  MouseButtons = [
    MOUSE_LEFT,
    MOUSE_RIGHT,
    MOUSE_MIDDLE,
    MOUSE_BACK,
    MOUSE_FORWARD
  ]

proc click*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if buttonPress[mbtn]:
      return true

proc down*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if buttonDown[mbtn]: return true

proc scrolled*(mouse: Mouse): bool =
  mouse.wheelDelta != 0.0

proc release*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if buttonRelease[mbtn]: return true

proc consume*(keyboard: Keyboard) =
  ## Reset the keyboard state consuming any event information.
  keyboard.state = Empty
  keyboard.keyString = ""
  keyboard.altKey = false
  keyboard.ctrlKey = false
  keyboard.shiftKey = false
  keyboard.superKey = false
  keyboard.consumed = true

proc consume*(mouse: Mouse) =
  ## Reset the mouse state consuming any event information.
  buttonPress[MOUSE_LEFT] = false

proc setMousePos*(item: var Mouse, x, y: float64) =
  item.pos = vec2(x, y)
  item.pos *= pixelRatio / item.pixelScale
  item.delta = item.pos - item.prevPos
  item.prevPos = item.pos

proc mouseOverlapsNode*(node: Node): bool =
  ## Returns true if mouse overlaps the node node.
  let mpos = mouse.pos.descaled + node.totalOffset 
  let act = 
    (not popupActive or inPopup) and
    node.screenBox.w > 0'ui and
    node.screenBox.h > 0'ui 

  result =
    act and
    mpos.overlaps(node.screenBox) and
    (if inPopup: mouse.pos.descaled.overlaps(popupBox) else: true)

const
  MouseOnOutEvents = {evClickOut, evHoverOut, evOverlapped}

proc max[T](a, b: EventsCapture[T]): EventsCapture[T] =
  if b.zlvl >= a.zlvl and b.flags != {}: b else: a

template checkEvent[ET](evt: ET, predicate: typed) =
  when ET is MouseEventType:
    if evt in node.listens.mouse and predicate: result.incl(evt)
  elif ET is GestureEventType:
    if evt in node.listens.gesture and predicate: result.incl(evt)

proc checkMouseEvents*(node: Node): MouseEventFlags =
  ## Compute mouse events
  if node.mouseOverlapsNode():
    checkEvent(evClick, mouse.click())
    checkEvent(evPress, mouse.down())
    checkEvent(evRelease, mouse.release())
    checkEvent(evHover, true)
    checkEvent(evOverlapped, true)
  else:
    checkEvent(evClickOut, mouse.click())
    checkEvent(evHoverOut, true)

proc checkGestureEvents*(node: Node): GestureEventFlags =
  ## Compute gesture events
  if node.mouseOverlapsNode():
    checkEvent(evScroll, mouse.scrolled())

proc computeNodeEvents*(node: Node): CapturedEvents =
  ## Compute mouse events
  for n in node.nodes.reverse:
    let child = computeNodeEvents(n)
    result.mouse = max(result.mouse, child.mouse)
    result.gesture = max(result.gesture, child.gesture)

  let
    allMouseEvts = node.checkMouseEvents()
    mouseOutEvts = allMouseEvts * MouseOnOutEvents
    mouseEvts = allMouseEvts - MouseOnOutEvents
    gestureEvts = node.checkGestureEvents()

  # set on-out events 
  node.events.mouse.incl(mouseOutEvts)

  let
    captured = CapturedEvents(
      mouse: MouseCapture(zlvl: node.zlevel, flags: mouseEvts, target: node),
      gesture: GestureCapture(zlvl: node.zlevel, flags: gestureEvts, target: node)
    )

  if node.clipContent and not node.mouseOverlapsNode():
    # this node clips events, so it must overlap child events, 
    # e.g. ignore child captures if this node isn't also overlapping 
    result = captured
  else:
    result.mouse = max(captured.mouse, result.mouse)
    result.gesture = max(captured.gesture, result.gesture)
  

proc computeEvents*(node: Node) =
  let res = computeNodeEvents(node)
  template handleCapture(name, field, ignore: untyped) =
    ## process event capture
    if not res.`field`.target.isNil:
      let evts = res.`field`
      let target = evts.target
      target.events.`field` = evts.flags
      if target.kind != nkRoot and evts.flags - ignore != {}:
        # echo "EVT: ", target.kind, " => ", evts.flags, " @ ", target.id
        requestedFrame = 2
  ## mouse and gesture are handled separately as they can have separate
  ## node targets
  handleCapture("mouse", mouse, {evHover})
  handleCapture("gesture", gesture, {})

var gridChildren: seq[Node]

template calcBasicConstraintImpl(
    parent, node: Node,
    dir: static GridDir,
    f: untyped
) =
  ## computes basic constraints for box'es when set
  ## this let's the use do things like set 90'pp (90 percent)
  ## of the box width post css grid or auto constraints layout
  template calcBasic(val: untyped): untyped =
    block:
      var res: UICoord
      match val:
        UiFixed(coord):
          res = coord.UICoord
        UiFrac(frac):
          res = frac.UICoord * parent.box.f
        UiPerc(perc):
          let ppval = when astToStr(f) == "x": parent.box.w
                      elif astToStr(f) == "y": parent.box.h
                      else: parent.box.f
          res = perc.UICoord / 100.0.UICoord * ppval
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
  match csValue:
    UiAuto():
      when astToStr(f) in ["w", "h"]:
        node.box.f = parent.box.f
      else:
        discard
    UiSum(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = lv + rv
    UiMin(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = min(lv, rv)
    UiMax(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = max(lv, rv)
    UiValue(value):
      node.box.f = calcBasic(value)
    _:
      discard

proc calcBasicConstraint(parent, node: Node, dir: static GridDir, isXY: static bool) =
  when isXY == true and dir == dcol: 
    calcBasicConstraintImpl(parent, node, dir, x)
  elif isXY == true and dir == drow: 
    calcBasicConstraintImpl(parent, node, dir, y)
  elif isXY == false and dir == dcol: 
    calcBasicConstraintImpl(parent, node, dir, w)
  elif isXY == false and dir == drow: 
    calcBasicConstraintImpl(parent, node, dir, h)

proc computeLayout*(parent, node: Node) =
  ## Computes constraints and auto-layout.
  
  # simple constraints
  if node.gridItem.isNil:
    calcBasicConstraint(parent, node, dcol, true)
    calcBasicConstraint(parent, node, drow, true)
    calcBasicConstraint(parent, node, dcol, false)
    calcBasicConstraint(parent, node, drow, false)

  # css grid impl
  if not node.gridTemplate.isNil:
    
    gridChildren.setLen(0)
    for n in node.nodes:
      if n.layoutAlign != laIgnore:
        gridChildren.add(n)
    node.gridTemplate.computeNodeLayout(node, gridChildren)

    for n in node.nodes:
      computeLayout(node, n)
    
    return

  for n in node.nodes:
    computeLayout(node, n)

  if node.layoutAlign == laIgnore:
    return

  # Constraints code.
  case node.constraintsVertical:
    of cMin: discard
    of cMax:
      let rightSpace = parent.orgBox.w - node.box.x
      # echo "rightSpace : ", rightSpace  
      node.box.x = parent.box.w - rightSpace
    of cScale:
      let xScale = parent.box.w / parent.orgBox.w
      # echo "xScale: ", xScale 
      node.box.x *= xScale
      node.box.w *= xScale
    of cStretch:
      let xDiff = parent.box.w - parent.orgBox.w
      # echo "xDiff: ", xDiff   
      node.box.w += xDiff
    of cCenter:
      let offset = floor((node.orgBox.w - parent.orgBox.w) / 2.0'ui + node.orgBox.x)
      # echo "offset: ", offset   
      node.box.x = floor((parent.box.w - node.box.w) / 2.0'ui) + offset

  case node.constraintsHorizontal:
    of cMin: discard
    of cMax:
      let bottomSpace = parent.orgBox.h - node.box.y
      # echo "bottomSpace  : ", bottomSpace   
      node.box.y = parent.box.h - bottomSpace
    of cScale:
      let yScale = parent.box.h / parent.orgBox.h
      # echo "yScale: ", yScale
      node.box.y *= yScale
      node.box.h *= yScale
    of cStretch:
      let yDiff = parent.box.h - parent.orgBox.h
      # echo "yDiff: ", yDiff 
      node.box.h += yDiff
    of cCenter:
      let offset = floor((node.orgBox.h - parent.orgBox.h) / 2.0'ui + node.orgBox.y)
      node.box.y = floor((parent.box.h - node.box.h) / 2.0'ui) + offset

  # Typeset text
  if node.kind == nkText:
    computeTextLayout(node)
    case node.textStyle.autoResize:
      of tsNone:
        # Fixed sized text node.
        discard
      of tsHeight:
        # Text will grow down.
        node.box.h = node.textLayoutHeight
      of tsWidthAndHeight:
        # Text will grow down and wide.
        node.box.w = node.textLayoutWidth
        node.box.h = node.textLayoutHeight
    # print "layout:nkText: ", node.id, node.box

  template compAutoLayoutNorm(field, fieldSz, padding: untyped;
                              orth, orthSz, orthPadding: untyped) =
    # echo "layoutMode : ", node.layoutMode 
    if node.counterAxisSizingMode == csAuto:
      # Resize to fit elements tightly.
      var maxOrth = 0.0'ui
      for n in node.nodes:
        if n.layoutAlign != laStretch:
          maxOrth = max(maxOrth, n.box.`orthSz`)
      node.box.`orthSz` = maxOrth  + node.`orthPadding` * 2'ui

    var at = 0.0'ui
    at += node.`padding`
    for i, n in node.nodes.pairs:
      if n.layoutAlign == laIgnore:
        continue
      if i > 0:
        at += node.itemSpacing

      n.box.`field` = at

      case n.layoutAlign:
        of laMin:
          n.box.`orth` = node.`orthPadding`
        of laCenter:
          n.box.`orth` = node.box.`orthSz`/2'ui - n.box.`orthSz`/2'ui
        of laMax:
          n.box.`orth` = node.box.`orthSz` - n.box.`orthSz` - node.`orthPadding`
        of laStretch:
          n.box.`orth` = node.`orthPadding`
          n.box.`orthSz` = node.box.`orthSz` - node.`orthPadding` * 2'ui
          # Redo the layout for child node.
          computeLayout(node, n)
        of laIgnore:
          continue
      at += n.box.`fieldSz`
    at += node.`padding`
    node.box.`fieldSz` = at

  # Auto-layout code.
  if node.layoutMode == lmVertical:
    compAutoLayoutNorm(y, h, verticalPadding, x, w, horizontalPadding)

  if node.layoutMode == lmHorizontal:
    # echo "layoutMode : ", node.layoutMode 
    compAutoLayoutNorm(x, w, horizontalPadding, y, h, verticalPadding)

proc computeScreenBox*(parent, node: Node) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset
  for n in node.nodes:
    computeScreenBox(node, n)

proc atXY*[T: Box](rect: T, x, y: int | float32 | UICoord): T =
  result = rect
  result.x = UICoord(x)
  result.y = UICoord(y)
proc atXY*[T: Rect](rect: T, x, y: int | float32): T =
  result = rect
  result.x = x
  result.y = y

proc `+`*(rect: Rect, xy: Vec2): Rect =
  ## offset rect with xy vec2 
  result = rect
  result.x += xy.x
  result.y += xy.y

proc `~=`*(rect: Vec2, val: float32): bool =
  result = rect.x ~= val and rect.y ~= val

proc add*[T](events: var Events, evt: T) =
  if events.data.isNil:
    events.data = newTable[TypeId, Variant]()
  let key = T.getTypeId()
  let res = events.data.mgetOrPut(key, newVariant(new seq[T])).get(ref seq[T])
  res[].add(evt)

proc `[]`*[T](events: Events, tp: typedesc[T]): seq[T] =
  if events.data.isNil:
    return @[]
  let key = T.getTypeId()
  result = events.data.pop(key)

import std/monotimes, std/times

proc popEvents*[T](events: Events, vals: var seq[T]): bool =
  # let a = getMonoTime()
  if events.data.isNil:
    return false
  var res: Variant
  result = events.data.pop(T.getTypeId(), res)
  if result:
    vals = res.get(ref seq[T])[]
  # let b = getMonoTime()
  # echo "popEvents: ", $inNanoseconds(b-a), "ns"

template dispatchEvent*(evt: typed) =
  result.add(evt)

import std/macrocache
const mcStateCounter = CacheCounter"stateCounter"

template useState*[T: ref](vname: untyped) =
  ## creates and caches a new state ref object
  const id = static:
    mcStateCounter.inc(1)
    value(mcStateCounter)
  if not current.userStates.hasKey(id):
    current.userStates[id] = newVariant(T.new())
  var `vname` {.inject.} = current.userStates[id].get(typeof T)

template withState*[T: ref](tp: typedesc[T]): untyped =
  ## creates and caches a new state ref object
  block:
    const id = 
      static:
        mcStateCounter.inc(1)
        value(mcStateCounter)

    if not current.userStates.hasKey(id):
      current.userStates[id] = newVariant(tp.new())
    current.userStates[id].get(tp)

template toRunes*(item: Node): seq[Rune] =
  item.text

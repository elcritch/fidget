import sequtils, tables, json, hashes
import chroma, input
import strutils, strformat
import unicode
import typetraits

import variant
import commonutils

export sequtils, strformat, tables, hashes
export variant
export unicode
export commonutils

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
  Constraint* = enum
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
    nodes*: seq[Node]
    box*: Box
    orgBox: Box
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
    constraintsHorizontal*: Constraint
    constraintsVertical*: Constraint
    layoutAlign*: LayoutAlign
    layoutMode*: LayoutMode
    counterAxisSizingMode*: CounterAxisSizingMode
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
    scrollBars*: bool 
    hookName*: string
    hookStates*: Variant
    hookEvents*: GeneralEvents
    points*: seq[Position]

  GeneralEvents* = object
    data*: TableRef[string, seq[Variant]]

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

const
  DataDirPath* {.strdefine.} = "data"

var
  parent*: Node
  root*: Node
  prevRoot*: Node
  nodeStack*: seq[Node]
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
  defaultlineHeightRatio* = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarWidth* = 14'f32
  scrollBarFill* = rgba(92, 143, 156, 102).color
  scrollBarHighlight* = rgba(92, 143, 156, 230).color 

proc defaultLineHeight*(fontSize: UICoord): UICoord =
  result = fontSize * defaultlineHeightRatio + 2.0.UICoord
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

  echo indent, "`", node.id, "`", " sb: ", $node.screenBox, " org: ", $node.orgBox
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
  node.scrollBars = false
  node.hasRendered = false
  node.hookStates = newVariant()
  node.hookEvents = GeneralEvents(data: nil)

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
  MouseOnOutEvents = {evClickOut, evHoverOut}

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
  else:
    checkEvent(evHoverOut, true)
    checkEvent(evClickOut, mouse.click())

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

proc computeLayout*(parent, node: Node) =
  ## Computes constraints and auto-layout.
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

proc box*(node: Node): Box = node.box

proc atXY*[T: Box](rect: T, x, y: int | float32 | UICoord): T =
  result = rect
  result.x = UICoord(x)
  result.y = UICoord(y)
proc atXY*[T: Rect](rect: T, x, y: int | float32): T =
  result = rect
  result.x = x
  result.y = y


proc `*`*(color: Color, alpha: float32): Color =
  ## update alpha on color
  result = color
  result.a *= alpha

proc `+`*(rect: Rect, xy: Vec2): Rect =
  ## offset rect with xy vec2 
  result = rect
  result.x += xy.x
  result.y += xy.y

proc `~=`*(rect: Vec2, val: float32): bool =
  result = rect.x ~= val and rect.y ~= val

proc `[]=`*[T](events: GeneralEvents, key: string, evt: T) =
  events.data.mgetOrPut(key, newSeq[Variant]()).add newVariant(evt)

proc pop*(events: GeneralEvents, key: string, vals: var seq[Variant]): bool =
  result = events.data.pop(key, vals)

proc hasKey*(events: GeneralEvents, key: string): bool =
  result = events.data.hasKey(key) and events.data[key].len() > 0

proc getAs*[T](events: GeneralEvents, key: string, default: typedesc[T]): T =
  events.data[key][0].get(T)

proc currentEvents*(node: Node): GeneralEvents =
  if node.hookEvents.data.isNil:
    node.hookEvents.data = newTable[string, seq[Variant]]()
  result = node.hookEvents

proc mgetOrPut*[T](events: GeneralEvents, key: string, default: typedesc[T]): T =
  if not events.data.hasKey(key):
    let x = T()
    events.data[key] = @[newVariant(x)]
  events.data[key][0].get(T)

template mgetOrPut*(events: GeneralEvents, key: string, default: untyped): auto =
  if not events.data.hasKey(key):
    let x = default
    events.data[key] = @[newVariant(x)]
  events.data[key][0].get(typeof default)

template toRunes*(item: Node): seq[Rune] =
  item.text

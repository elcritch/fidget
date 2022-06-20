import sequtils, tables, json, hashes
import chroma, input
import strutils, strformat
import unicode

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
    weight*: UICoord
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
    zLevel*: ZLevel
    zLevelMousePrecedent*: ZLevel
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
    postHooks*: seq[proc() {.closure.}]
    hookName*: string
    hookStates*: Variant
    hookEvents*: GeneralEvents

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

  EventType* = enum
    evClick,
    evClickOut,
    evHovered,
    evDown

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
  requestedFrame*: bool
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
  zLevelMousePrecedent*: ZLevel
  zLevelMouse*: ZLevel

  # Used to check for duplicate ID paths.
  pathChecker*: Table[string, bool]

  computeTextLayout*: proc(node: Node)
  computeHooks*: proc(parent, node: Node)

  lastUId: int
  nodeLookup*: Table[string, Node]

  dataDir*: string = DataDirPath

  ## Used for HttpCalls
  httpCalls*: Table[string, HttpCall]

  # UI Scale
  uiScale*: float32 = 1.0

  ## Whether event is overshadowed by a higher precedent ZLevel
  eventsOvershadowed*: bool

  # global scroll bar settings
  scrollBarWidth* = 14'f32
  scrollBarFill* = rgba(92, 143, 156, 102).color
  scrollBarHighlight* = rgba(92, 143, 156, 230).color 

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
    textBox*: TextBox[Node]
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
  node.stroke = Stroke(weight: 0'ui, color: clearColor)
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
  node.zLevel = ZLevelDefault
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
    # root.highlightColor = parseHtmlColor("#3297FD")
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
  zLevelMousePrecedent = zLevelMouse
  zLevelMouse = ZLevelBottom

  # Reset key and mouse press to default state
  for i in 0 ..< buttonPress.len:
    buttonPress[i] = false
    buttonRelease[i] = false

  if any(buttonDown, proc(b: bool): bool = b):
    keyboard.state = KeyState.Down
  else:
    keyboard.state = KeyState.Empty

proc click*(mouse: Mouse): bool =
  result = buttonPress[MOUSE_LEFT]

proc down*(mouse: Mouse): bool =
  buttonDown[MOUSE_LEFT]

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
      node.box.x = parent.box.w - rightSpace
    of cScale:
      let xScale = parent.box.w / parent.orgBox.w
      node.box.x *= xScale
      node.box.w *= xScale
    of cStretch:
      let xDiff = parent.box.w - parent.orgBox.w
      node.box.w += xDiff
    of cCenter:
      let offset = floor((node.orgBox.w - parent.orgBox.w) / 2.0'ui + node.orgBox.x)
      node.box.x = floor((parent.box.w - node.box.w) / 2.0'ui) + offset

  case node.constraintsHorizontal:
    of cMin: discard
    of cMax:
      let bottomSpace = parent.orgBox.h - node.box.y
      node.box.y = parent.box.h - bottomSpace
    of cScale:
      let yScale = parent.box.h / parent.orgBox.h
      node.box.y *= yScale
      node.box.h *= yScale
    of cStretch:
      let yDiff = parent.box.h - parent.orgBox.h
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

  # Auto-layout code.
  if node.layoutMode == lmVertical:
    if node.counterAxisSizingMode == csAuto:
      # Resize to fit elements tightly.
      var maxW = 0.0'ui
      for n in node.nodes:
        if n.layoutAlign != laStretch:
          maxW = max(maxW, n.box.w)
      node.box.w = maxW + node.horizontalPadding * 2'ui

    var at = 0.0'ui
    at += node.verticalPadding
    for i, n in node.nodes.pairs:
      if n.layoutAlign == laIgnore:
        continue
      if i > 0: at += node.itemSpacing
      n.box.y = at
      case n.layoutAlign:
        of laMin:
          n.box.x = node.horizontalPadding
        of laCenter:
          n.box.x = node.box.w/2'ui - n.box.w/2'ui
        of laMax:
          n.box.x = node.box.w - n.box.w - node.horizontalPadding
        of laStretch:
          n.box.x = node.horizontalPadding
          n.box.w = node.box.w - node.horizontalPadding * 2'ui
          # Redo the layout for child node.
          computeLayout(node, n)
        of laIgnore:
          continue
      at += n.box.h
    at += node.verticalPadding
    node.box.h = at

  if node.layoutMode == lmHorizontal:
    if node.counterAxisSizingMode == csAuto:
      # Resize to fit elements tightly.
      var maxH = 0.0'ui
      for n in node.nodes:
        if n.layoutAlign != laStretch:
          maxH = max(maxH, n.box.h)
      node.box.h = maxH + node.verticalPadding * 2'ui

    var at = 0.0'ui
    at += node.horizontalPadding
    for i, n in node.nodes.pairs:
      if n.layoutAlign == laIgnore:
        continue
      if i > 0:
        at += node.itemSpacing
      n.box.x = at
      case n.layoutAlign:
        of laMin:
          n.box.y = node.verticalPadding
        of laCenter:
          n.box.y = node.box.h/2'ui - n.box.h/2'ui
        of laMax:
          n.box.y = node.box.h - n.box.h - node.verticalPadding
        of laStretch:
          n.box.y = node.verticalPadding
          n.box.h = node.box.h - node.verticalPadding * 2'ui
          # Redo the layout for child node.
          computeLayout(node, n)
        of laIgnore:
          continue
      at += n.box.w
    at += node.horizontalPadding
    node.box.w = at

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


proc setMousePos*(item: var Mouse, x, y: float64) =
  item.pos = vec2(x, y)
  item.pos *= pixelRatio / item.pixelScale
  item.delta = item.pos - item.prevPos
  item.prevPos = item.pos

proc atXY*[T](rect: T, x, y: float32 | UICoord): T =
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

import sequtils, tables, json, hashes
import chroma, input, vmath, bumpy
import strutils, strformat

import variant

export sequtils, strutils, strformat, tables, hashes
export variant

when defined(js):
  import dom2, html/ajax
else:
  import typography, typography/textboxes, asyncfutures

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
    fontSize*: float32
    fontWeight*: float32
    lineHeight*: float32
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
    blur*: float32
    x*: float32
    y*: float32
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

  Node* = ref object
    id*: string
    uid*: NodeUID
    idPath*: string
    kind*: NodeKind
    text*: string
    code*: string
    nodes*: seq[Node]
    box: Rect
    orgBox: Rect
    rotation*: float32
    screenBox*: Rect
    offset*: Vec2
    totalOffset*: Vec2
    mouseBase*: Vec2
    fill*: Color
    transparency*: float32
    strokeWeight*: float32
    stroke*: Color
    resizeDone*: bool
    htmlDone*: bool
    textStyle*: TextStyle
    imageName*: string
    imageColor*: Color
    cornerRadius*: (float32, float32, float32, float32)
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
    horizontalPadding*: float32
    verticalPadding*: float32
    itemSpacing*: float32
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
    textLayoutHeight*: float32
    textLayoutWidth*: float32
    ## Can the text be selected.
    selectable*: bool
    scrollBars*: bool ## Should it have scroll bars if children are clipped.
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
    pos*, delta*, prevPos*: Vec2
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
    input*: string
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
  theme*: Node
  textTheme*: Node
  scrollBox*: Rect
  scrollBoxMega*: Rect ## Scroll box is 500px bigger in y direction
  scrollBoxMini*: Rect ## Scroll box is smaller by 100px useful for debugging
  mouse* = Mouse()
  keyboard* = Keyboard()
  requestedFrame*: bool
  numNodes*: int
  popupActive*: bool
  inPopup*: bool
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

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

when not defined(js):
  var
    textBox*: TextBox
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
mouse.pos = vec2(0)

proc dumpTree*(node: Node, indent = "") =
  # node.idPath = ""
  # when defined(StringUID):
  #   node.idPath = ""
  #   for i, g in nodeStack:
  #     if i != 0:
  #       node.idPath.add "."
  #     if g.id != "":
  #       node.idPath.add g.id
  #     else:
  #       node.idPath.add $g.diffIndex

  echo indent, "`", node.id, "`", " sb: ", node.screenBox, " org: ", node.orgBox
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
  node.text = ""
  node.code = ""
  # node.nodes = @[]
  node.box = rect(0,0,0,0)
  node.orgBox = rect(0,0,0,0)
  node.rotation = 0
  # node.screenBox = rect(0,0,0,0)
  # node.offset = vec2(0, 0)
  node.fill = clearColor
  node.transparency = 0
  node.strokeWeight = 0
  node.stroke = clearColor
  node.resizeDone = false
  node.htmlDone = false
  node.textStyle = TextStyle()
  node.imageName = ""
  node.imageColor = whiteColor
  node.cornerRadius = (0'f32, 0'f32, 0'f32, 0'f32)
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
  node.horizontalPadding = 0
  node.verticalPadding = 0
  node.itemSpacing = 0
  node.clipContent = false
  node.diffIndex = 0
  node.zLevel = ZLevelDefault
  node.selectable = false
  node.scrollBars = false
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
  buttonPress[MOUSE_LEFT]

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
      let offset = floor((node.orgBox.w - parent.orgBox.w) / 2.0 + node.orgBox.x)
      node.box.x = floor((parent.box.w - node.box.w) / 2.0) + offset

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
      let offset = floor((node.orgBox.h - parent.orgBox.h) / 2.0 + node.orgBox.y)
      node.box.y = floor((parent.box.h - node.box.h) / 2.0) + offset

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
      var maxW = 0.0
      for n in node.nodes:
        if n.layoutAlign != laStretch:
          maxW = max(maxW, n.box.w)
      node.box.w = maxW + node.horizontalPadding * 2

    var at = 0.0
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
          n.box.x = node.box.w/2 - n.box.w/2
        of laMax:
          n.box.x = node.box.w - n.box.w - node.horizontalPadding
        of laStretch:
          n.box.x = node.horizontalPadding
          n.box.w = node.box.w - node.horizontalPadding * 2
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
      var maxH = 0.0
      for n in node.nodes:
        if n.layoutAlign != laStretch:
          maxH = max(maxH, n.box.h)
      node.box.h = maxH + node.verticalPadding * 2

    var at = 0.0
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
          n.box.y = node.box.h/2 - n.box.h/2
        of laMax:
          n.box.y = node.box.h - n.box.h - node.verticalPadding
        of laStretch:
          n.box.y = node.verticalPadding
          n.box.h = node.box.h - node.verticalPadding * 2
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
    # echo "compScreenBox: ", node.idPath, " bx: ", node.box
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    # echo "compScreenBox: ", node.idPath, " bx: ", node.box, " parent:sb: ", parent.screenBox
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset
  for n in node.nodes:
    computeScreenBox(node, n)

proc setBox*(node: var Node, rect: Rect, raw: static[bool] = false) =
  when raw: node.box = rect
  else: node.box = rect * uiScale

proc setBox*(node: var Node, x, y, w, h: float32, raw: static[bool]) =
  node.setBox(Rect(x: x, y: y, w: w, h: h), raw)

proc getBox*(node: Node, raw: static[bool] = false): Rect =
  when raw: result = node.box
  else: result = node.box / uiScale

proc box*(node: Node, raw: static[bool] = false): Rect =
  when raw: result = node.box
  else: result = node.box / uiScale

proc setOrgBox*(node: Node, rect: Rect, raw: static[bool] = false) =
  when raw: node.orgBox = rect
  else: node.orgBox = rect * common.uiScale

proc setOrgBox*(node: Node, x, y, w, h: float32, raw: static[bool]) =
  node.setOrgBox(Rect(x: x, y: y, w: w, h: h), raw)

proc getOrgBox*(node: Node, raw: static[bool] = false): Rect =
  when raw: result = node.orgBox
  else: result = node.orgBox / common.uiScale

template descaled*(node, box: untyped): untyped =
  node.`box`/uiScale

proc `~=`*(rect: Vec2, val: float32): bool =
  result = rect.x ~= val and rect.y ~= val

proc `[]=`*[T](events: GeneralEvents, key: string, evt: T) =
  events.data.mgetOrPut(key, newSeq[Variant]()).add newVariant(evt)

template setupWidgetTheme*(blk) =
  block:
    common.theme = Node()
    common.theme.resetToDefault()
    common.current = common.theme
    `blk`
  common.current = nil

template setupTextTheme*(blk) =
  block:
    common.textTheme = Node()
    common.textTheme.resetToDefault()
    common.current = common.textTheme
    `blk`
  common.current = nil

proc emptyTheme*() =
  setupWidgetTheme:
    current.fill = Color(r: 157/255, g: 157/255, b: 157/255, a: 1)
  setupTextTheme:
    # rgba(114, 189, 208, 1)
    current.cursorColor = Color(r: 114/255, g: 189/255, b: 208/255, a: 0.33)
    current.highlightColor = Color(r: 114/255, g: 189/255, b: 208/255, a: 0.77)
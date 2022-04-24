import algorithm, chroma, fidget/common, fidget/input, json, macros, strutils,
    tables, vmath, bumpy
import math, strformat

export chroma, common, input, vmath, bumpy

when defined(js):
  import fidget/htmlbackend
  export htmlbackend
elif defined(nullbackend):
  import fidget/nullbackend
  export nullbackend
else:
  import fidget/openglbackend
  export openglbackend


proc preNode(kind: NodeKind, id: string) =
  ## Process the start of the node.

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?
  if parent.nodes.len <= parent.diffIndex:
    # Create Node.
    current = Node()
    current.id = id
    current.uid = newUId()
    parent.nodes.add(current)
    refresh()
  else:
    # Reuse Node.
    current = parent.nodes[parent.diffIndex]
    if current.id == id and
        current.nIndex == parent.diffIndex:
      # Same node.
      discard
    else:
      # Big change.
      current.id = id
      current.nIndex = parent.diffIndex
      current.resetToDefault()
      refresh()

  current.kind = kind
  current.textStyle = parent.textStyle
  current.cursorColor = parent.cursorColor
  current.highlightColor = parent.highlightColor
  current.transparency = parent.transparency
  current.zLevel = parent.zLevel
  nodeStack.add(current)
  inc parent.diffIndex

  current.diffIndex = 0
  common.eventsOvershadowed = current.zLevel.ord() < zLevelMousePrecedent.ord()

proc postNode() =
  ## Node drawing is done.
  
  # run after inner hooks
  for hook in current.postHooks:
    hook()
  current.postHooks = @[]

  current.removeExtraChildren()

  let mpos = mouse.pos + current.totalOffset 
  if not common.eventsOvershadowed and
      not mouse.consumed and
      mpos.overlaps(current.screenBox):
    if mouse.wheelDelta != 0:
      if current.scrollBars:
        let
          yoffset = mouse.wheelDelta * 2*common.uiScale
          ph = parent.screenBox.h
          ch = (current.screenBox.h - ph).clamp(0, current.screenBox.h)
        # echo "postNode offset:pre: ", current.offset
        current.offset.y -= yoffset
        current.offset.y = current.offset.y.clamp(0, ch)
        mouse.consumed = true
        # echo "postNode offset:after: ", current.offset

  zLevelMouse = ZLevel(max(zLevelMouse.ord, current.zLevel.ord))
  # Pop the stack.
  discard nodeStack.pop()
  if nodeStack.len > 1:
    current = nodeStack[^1]
  else:
    current = nil
  if nodeStack.len > 2:
    parent = nodeStack[^2]
  else:
    parent = nil

template node(kind: NodeKind, id: string, inner, setup: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, id)
  setup
  inner
  postNode()

template node(kind: NodeKind, id: string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, id)
  inner
  postNode()

template withDefaultName(name: untyped): untyped =
  template `name`*(inner: untyped): untyped =
    `name`("", inner)

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

template frame*(id: string, inner: untyped): untyped =
  ## Starts a new frame.
  node(nkFrame, id, inner):
    boxOf root

template group*(id: string, inner: untyped): untyped =
  ## Starts a new node.
  node(nkGroup, id, inner):
    boxOf parent

template component*(id: string, inner: untyped): untyped =
  ## Starts a new component.
  node(nkComponent, id, inner):
    boxOf parent

template rectangle*(id: string, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, id, inner)

template text*(id: string, inner: untyped): untyped =
  ## Starts a new text element.
  node(nkText, id, inner)

template instance*(id: string, inner: untyped): untyped =
  ## Starts a new instance of a component.
  node(nkInstance, id, inner)

template drawable*(id: string, inner: untyped): untyped =
  ## Starts a new instance of a component.
  node(nkDrawable, id, inner)

template blank*(id, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkComponent, id, inner)

## Overloaded Nodes 
## ^^^^^^^^^^^^^^^^
## 
## Various overloaded node APIs

withDefaultName(group)
withDefaultName(frame)
withDefaultName(rectangle)
withDefaultName(text)
withDefaultName(component)
withDefaultName(instance)
withDefaultName(drawable)
withDefaultName(blank)

template rectangle*(color: string|Color) =
  ## Shorthand for rectangle with fill.
  rectangle "":
    box 0, 0, parent.getBox().w, parent.getBox().h
    fill color

template blank*(): untyped =
  ## Starts a new rectangle.
  node(nkComponent, ""):
    discard

## ---------------------------------------------
##             Fidget Node APIs
## ---------------------------------------------
## 
## These APIs provide the APIs for Fidget nodes.
## 

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node User Interactions
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## interacting with user interactions. 
## 

proc mouseOverlapLogic*(): bool =
  ## Returns true if mouse overlaps the current node.
  if common.eventsOvershadowed:
    return

  let mpos = mouse.pos + current.totalOffset 
  let act = 
    (not popupActive or inPopup) and
    current.screenBox.w > 0 and
    current.screenBox.h > 0 
  # if mpos.overlaps(current.screenBox):
    # echo fmt"mouseOverlap: {mpos=} {current.screenBox=}"
  act and mpos.overlaps(current.screenBox)

template bindEvents*(name: string, events: GeneralEvents) =
  ## On click event handler.
  current.code = name
  current.hookEvents = events

template onClick*(inner: untyped) =
  ## On click event handler.
  if mouse.click and mouseOverlapLogic():
    mouse.consume()
    inner

template onClickOutside*(inner: untyped) =
  ## On click outside event handler. Useful for deselecting things.
  if mouse.click and not mouseOverlapLogic():
    # mark as consumed but don't block other onClickOutside's
    inner

template onRightClick*(inner: untyped) =
  ## On right click event handler.
  if buttonPress[MOUSE_RIGHT] and mouseOverlapLogic():
    inner

template onMouseDown*(inner: untyped) =
  ## On when mouse is down and overlapping the element.
  if buttonDown[MOUSE_LEFT] and mouseOverlapLogic():
    inner

template onKey*(inner: untyped) =
  ## This is called when key is pressed.
  if keyboard.state == Press:
    inner

template onKeyUp*(inner: untyped) =
  ## This is called when key is pressed.
  if keyboard.state == Up:
    inner

template onKeyDown*(inner: untyped) =
  ## This is called when key is held down.
  if keyboard.state == Down:
    inner

proc hasKeyboardFocus*(node: Node): bool =
  ## Does a node have keyboard input focus.
  return keyboard.focusNode == node

template onInput*(inner: untyped) =
  ## This is called when key is pressed and this element has focus.
  if keyboard.state == Press and current.hasKeyboardFocus():
    inner

template onHover*(inner: untyped) =
  ## Code in the block will run when this box is hovered.
  if mouseOverlapLogic():
    inner

template onScroll*(inner: untyped) =
  ## Code in the block will run when mouse scrolls
  if mouse.wheelDelta != 0.0 and mouseOverlapLogic():
    mouse.consumed = true
    inner

template onHoverOut*(inner: untyped) =
  ## Code in the block will run when hovering outside the box.
  if not mouseOverlapLogic():
    inner

template onDown*(inner: untyped) =
  ## Code in the block will run when this mouse is dragging.
  if mouse.down and mouseOverlapLogic():
    inner

template onFocus*(inner: untyped) =
  ## On focusing an input element.
  if keyboard.onFocusNode == current:
    keyboard.onFocusNode = nil
    inner

template onUnFocus*(inner: untyped) =
  ## On loosing focus on an input element.
  if keyboard.onUnFocusNode == current:
    keyboard.onUnFocusNode = nil
    inner

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

template Em*(size: float32): float32 =
  ## unit size relative to current font size
  current.textStyle.fontSize * size / common.uiScale

proc `'em`*(n: string): float32 =
  ## numeric literal em unit
  result = Em(parseFloat(n))

template Vw*(size: float32): float32 =
  ## percentage of Viewport width
  root.box().w * size / 100.0

proc `'vw`*(n: string): float32 =
  ## numeric literal view width unit
  result = Vw(parseFloat(n))

template Vh*(size: float32): float32 =
  ## percentage of Viewport height
  root.box().h * size / 100.0

proc `'vh`*(n: string): float32 =
  ## numeric literal view height unit
  result = Vh(parseFloat(n))

template WPerc*(size: float32): float32 =
  ## numeric literal percent of parent width
  max(0'f32, parent.box().w * size / 100.0)

proc `'pw`*(n: string): float32 =
  ## numeric literal percent of parent width
  result = WPerc(parseFloat(n))

template HPerc*(size: float32): float32 =
  ## percentage of parent height
  max(0'f32, parent.box().h * size / 100.0)

proc `'ph`*(n: string): float32 =
  ## numeric literal percent of parent height
  result = HPerc(parseFloat(n))

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Content and Settings
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## using Nodes like setting their colors, positions,
## sizes, and text. 
## 
## These are the primary API for drawing UI objects. 
## 

proc id*(id: string) =
  ## Sets ID.
  current.id = id

proc id*(): string =
  ## Get current node ID.
  return current.id

proc getId*(): string =
  ## Get current node ID.
  return current.id

proc orgBox*(x, y, w, h: int|float32|float64) =
  ## Sets the box dimensions of the original element for constraints.
  let b = Rect(x: float32 x, y: float32 y, w: float32 w, h: float32 h)
  current.setOrgBox(b, raw=false)

proc orgBox*(rect: Rect) =
  ## Sets the box dimensions with integers
  orgBox(rect.x, rect.y, rect.w, rect.h)

proc boxFrom(x, y, w, h: float32) =
  ## Sets the box dimensions.
  let b = Rect(x: x, y: y, w: w, h: h)
  current.setBox(b, raw=false)

proc box*(
  x: int|float32|float64,
  y: int|float32|float64,
  w: int|float32|float64,
  h: int|float32|float64
) =
  ## Sets the box dimensions with integers
  ## Always set box before orgBox when doing constraints.
  boxFrom(float32 x, float32 y, float32 w, float32 h)
  orgBox(float32 x, float32 y, float32 w, float32 h)

proc box*(rect: Rect) =
  ## Sets the box dimensions with integers
  box(rect.x, rect.y, rect.w, rect.h)

proc size*(
  w: int|float32|float64,
  h: int|float32|float64
) =
  ## Sets the box dimension width and height
  let cb = current.box()
  box(cb.x, cb.y, float32 w, float32 h)
  # orgBox(cb.x, cb.y, float32 w, float32 h)

proc width*(w: int|float32|float64) =
  ## Sets the width of current node
  let cb = current.box()
  box(cb.x, cb.y, float32 w, float32 cb.h)

proc height*(h: int|float32|float64) =
  ## Sets the height of current node
  let cb = current.box()
  box(cb.x, cb.y, float32 cb.w, float32 h)

proc offset*(
  x: int|float32|float64,
  y: int|float32|float64
) =
  ## Sets the box dimension width and height
  let cb = current.box()
  box(float32 x, float32 y, cb.w, cb.h)
  orgBox(float32 x, float32 y, cb.w, cb.h)

template boxOf*(node: Node) =
  if not node.isNil:
    box(node.box())

proc rotation*(rotationInDeg: float32) =
  ## Sets rotation in degrees.
  current.rotation = rotationInDeg

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Text and Fonts 
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 

proc font*(
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  ## Sets the font.
  current.textStyle = TextStyle()
  current.textStyle.fontFamily = fontFamily
  current.textStyle.fontSize = common.uiScale*fontSize
  current.textStyle.fontWeight = common.uiScale*fontWeight
  current.textStyle.lineHeight =
      if lineHeight != 0.0: common.uiScale*lineHeight
      else: common.uiScale*fontSize
  current.textStyle.textAlignHorizontal = textAlignHorizontal
  current.textStyle.textAlignVertical = textAlignVertical

proc fontFamily*(fontFamily: string) =
  ## Sets the font family.
  current.textStyle.fontFamily = fontFamily

proc fontSize*(fontSize: float32) =
  ## Sets the font size in pixels.
  current.textStyle.fontSize = fontSize * common.uiScale

proc fontWeight*(fontWeight: float32) =
  ## Sets the font weight.
  current.textStyle.fontWeight = fontWeight * common.uiScale

proc lineHeight*(lineHeight: float32) =
  ## Sets the font size.
  current.textStyle.lineHeight = lineHeight * common.uiScale

proc textStyle*(style: TextStyle) =
  ## Sets the font size.
  current.textStyle = style

proc textAlign*(textAlignHorizontal: HAlign, textAlignVertical: VAlign) =
  ## Sets the horizontal and vertical alignment.
  current.textStyle.textAlignHorizontal = textAlignHorizontal
  current.textStyle.textAlignVertical = textAlignVertical

proc textPadding*(textPadding: int) =
  ## Sets the text padding on editable multiline text areas.
  current.textStyle.textPadding = textPadding

proc textAutoResize*(textAutoResize: TextAutoResize) =
  ## Set the text auto resize mode.
  current.textStyle.autoResize = textAutoResize

proc characters*(text: string) =
  ## Sets text.
  if current.text != text:
    current.text = text

proc selectable*(v: bool) =
  ## Set text selectable flag.
  current.selectable = v

template binding*(stringVariable: untyped) =
  ## Makes the current object text-editable and binds it to the stringVariable.
  current.bindingSet = true
  selectable true
  editableText true
  if not current.hasKeyboardFocus():
    characters stringVariable
  if not defined(js):
    onClick:
      keyboard.focus(current)
    onClickOutside:
      keyboard.unFocus(current)
  onInput:
    if stringVariable != keyboard.input:
      stringVariable = keyboard.input

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Styling and Content
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 

proc image*(imageName: string) =
  ## Sets image fill.
  current.imageName = imageName

proc fill*(color: Color) =
  ## Sets background color.
  current.fill = color

proc fill*(color: Color, alpha: float32) =
  ## Sets background color.
  current.fill = color
  current.fill.a = alpha

proc fill*(color: string, alpha: float32 = 1.0) =
  ## Sets background color.
  current.fill = parseHtmlColor(color)
  current.fill.a = alpha

proc transparency*(transparency: float32) =
  ## Sets transparency.
  current.transparency = transparency

proc stroke*(color: Color) =
  ## Sets stroke/border color.
  current.stroke = color

proc stroke*(color: Color, alpha: float32) =
  ## Sets stroke/border color.
  current.stroke = color
  current.stroke.a = alpha

proc stroke*(color: string, alpha = 1.0) =
  ## Sets stroke/border color.
  current.stroke = parseHtmlColor(color)
  current.stroke.a = alpha

proc strokeWeight*(weight: float32) =
  ## Sets stroke/border weight.
  current.strokeWeight = weight * common.uiScale

proc strokeLine*(weight: float32, color: string, alpha = 1.0) =
  ## Sets stroke/border color.
  current.stroke = parseHtmlColor(color)
  current.stroke.a = alpha
  current.strokeWeight = weight * common.uiScale

proc cornerRadius*(a, b, c, d: float32) =
  ## Sets all radius of all 4 corners.
  let s = common.uiScale * 3
  current.cornerRadius =  (s*a, s*b, s*c, s*d)

proc cornerRadius*(radius: float32) =
  ## Sets all radius of all 4 corners.
  cornerRadius(radius, radius, radius, radius)

proc cornerRadius*(radius: (float32, float32, float32, float32)) =
  ## Sets all radius of all 4 corners.
  cornerRadius(radius[0], radius[1], radius[2], radius[3] )

proc editableText*(editableText: bool) =
  ## Sets the code for this node.
  current.editableText = editableText

proc multiline*(multiline: bool) =
  ## Sets if editable text is multiline (textarea) or single line.
  current.multiline = multiline

proc clipContent*(clipContent: bool) =
  ## Causes the parent to clip the children.
  current.clipContent = clipContent

proc cursorColor*(color: Color) =
  ## Sets the color of the text cursor.
  current.cursorColor = color

proc cursorColor*(color: string, alpha = 1.0) =
  ## Sets the color of the text cursor.
  current.cursorColor = parseHtmlColor(color)
  current.cursorColor.a = alpha

proc highlightColor*(color: Color) =
  ## Sets the color of text selection.
  current.highlightColor = color

proc highlightColor*(color: string, alpha = 1.0) =
  ## Sets the color of text selection.
  current.highlightColor = parseHtmlColor(color)
  current.highlightColor.a = alpha

proc dropShadow*(blur, x, y: float32, color: string, alpha: float32) =
  ## Sets drop shadow on an element
  var c = parseHtmlColor(color)
  c.a = alpha
  current.shadows.add Shadow(kind: DropShadow, blur: blur, x: x, y: y, color: c)

proc innerShadow*(blur, x, y: float32, color: string, alpha: float32) =
  ## Sets an inner shadow
  var c = parseHtmlColor(color)
  c.a = alpha
  current.shadows.add(Shadow(
    kind: InnerShadow,
    blur: blur,
    x: x,
    y: y,
    color: c
  ))

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

proc constraints*(vCon: Constraint, hCon: Constraint) =
  ## Sets vertical or horizontal constraint.
  current.constraintsVertical = vCon
  current.constraintsHorizontal = hCon

proc layoutAlign*(mode: LayoutAlign) =
  ## Set the layout alignment mode.
  current.layoutAlign = mode

proc layout*(mode: LayoutMode) =
  ## Set the layout mode.
  current.layoutMode = mode

proc counterAxisSizingMode*(mode: CounterAxisSizingMode) =
  ## Set the counter axis sizing mode.
  current.counterAxisSizingMode = mode

proc horizontalPadding*(v: float32) =
  ## Set the horizontal padding for auto layout.
  current.horizontalPadding = v * common.uiScale

proc verticalPadding*(v: float32) =
  ## Set the vertical padding for auto layout.
  current.verticalPadding = v * common.uiScale

proc itemSpacing*(v: float32) =
  ## Set the item spacing for auto layout.
  current.itemSpacing = v * common.uiScale

proc zlevel*(zidx: ZLevel) =
  ## Sets zLevel.
  current.zLevel = zidx


# TODO: fixme?
var
  pipDrag = false
  pipHPosLast = 0'f32
  pipHPos = 0'f32
  pipOffLast = 0'f32

proc scrollBars*(scrollBars: bool, hAlign = hRight) =
  ## Causes the parent to clip the children and draw scroll bars.
  current.scrollBars = scrollBars
  if scrollBars == true:
    current.clipContent = scrollBars

  # define basics of scrollbar
  rectangle "$scrollbar":
    box 0, 0, 0, 0
    layoutAlign laIgnore
    fill "#5C8F9C", 0.4
    onHover:
      fill "#5C8F9C", 0.9
    onClick:
      pipDrag = true
      pipHPosLast = mouse.descaled(pos).y 
      pipOffLast = -current.descaled(offset).y

  current.postHooks.add proc() =
    ## add post inner callback to calculate the scrollbar box
    ## not sure this is the best way to handle this, but it's
    ## easier to calculate some things after the node has been
    ## called and computed. 
    let
      halign: HAlign = hAlign
      cr = 4.0'f32
      width = 14'f32

      ph = parent.descaled(screenBox).h
      nw = current.descaled(screenBox).w
      ch = max(current.descaled(screenBox).h - ph, 0)
      rh = current.descaled(screenBox).h
      perc = (ph/rh).clamp(0.0, 1.0)
      sh = perc*ph

    if pipDrag:
      pipHPos = mouse.descaled(pos).y 
      pipDrag = buttonDown[MOUSE_LEFT]
      let pipDelta =  (pipHPos - pipHPosLast)
      # echo fmt"pipPerc: pd: {pipDelta:6.4f} pl: {pipOffLast:6.4f} ch: {ch:6.4f}"
      current.offset.y = uiScale*(pipOffLast + pipDelta * 1/perc)
      current.offset.y = current.offset.y.clamp(0, uiScale*ch)

    let
      nh = current.descaled(screenBox).h - ph
      yo = current.descaled(offset).y()
      hPerc = (yo/nh).clamp(0.0, 1.0)
      xx = if halign == hLeft: 0'f32 else: nw - width
      bx = Rect(x: xx, y: hPerc*(ph - sh), w: width, h: sh)

    var idx = -1
    for i, child in current.nodes:
      if child.id == "$scrollbar":
        idx = i
        break
    
    if idx >= 0:
      var sb = current.nodes[idx]
      sb.setBox(bx)
      sb.offset = current.offset * -1'f32
    else:
      raise newException(Exception, "scrollbar defined but node is missing")


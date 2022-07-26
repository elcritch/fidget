import algorithm, chroma, fidget/common, fidget/input, json, macros, strutils,
    sequtils, tables, bumpy
import math, strformat
import unicode
import fidget/commonutils

export chroma, common, input
export commonutils

import print

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
  current.zlevel = parent.zlevel
  current.listens.mouse = {}
  current.listens.gesture = {}
  nodeStack.add(current)
  inc parent.diffIndex

  current.diffIndex = 0
  when defined(fidgetNodePath):
    current.setNodePath()

proc postNode() =
  current.removeExtraChildren()
  current.events.mouse = {}
  current.events.gesture = {}

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
    boxSizeOf parent

template group*(id: string, inner: untyped): untyped =
  ## Starts a new node.
  node(nkGroup, id, inner):
    boxSizeOf parent

template component*(id: string, inner: untyped): untyped =
  ## Starts a new component.
  node(nkComponent, id, inner):
    boxSizeOf parent

template rectangle*(id: string, inner: untyped): untyped =
  ## Starts a new text element.
  node(nkRectangle, id, inner)

template element*(id: string, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, id, inner):
    boxSizeOf parent

template text*(id: string, inner: untyped): untyped =
  ## Starts a new text element.
  node(nkText, id, inner):
    boxSizeOf parent

template instance*(id: string, inner: untyped): untyped =
  ## Starts a new instance of a component.
  node(nkInstance, id, inner)

template drawable*(id: string, inner: untyped): untyped =
  ## Starts a drawable node. These don't draw a normal rectangle.
  ## Instead they draw a list of points set in `current.points`
  ## using the nodes fill/stroke. The size of the drawable node
  ## is used for the point sizes, etc. 
  ## 
  ## Note: Experimental!
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
  result = mouseOverlapsNode(current)

proc isCovered*(screenBox: Box): bool =
  ## Returns true if mouse overlaps the current node.
  let off = current.totalOffset * -1'ui
  let sb = screenBox
  let cb = current.screenBox
  result = sb.overlaps(cb + off)

template bindEvents*(name: string, events: GeneralEvents) =
  ## On click event handler.
  current.code = name
  current.hookEvents = events

template useEvents*(): GeneralEvents =
  if current.hookEvents.data.isNil:
    current.hookEvents.data = newTable[string, seq[Variant]]()
  current.hookEvents

template onClick*(inner: untyped, button = MOUSE_LEFT) =
  ## On click event handler.
  current.listens.mouse.incl(evClick)
  if evClick in current.events.mouse and buttonPress[button]:
    inner

template onClickOutside*(inner: untyped, button = MOUSE_LEFT) =
  ## On click outside event handler. Useful for deselecting things.
  ## 
  current.listens.mouse.incl(evClickOut)
  if evClickOut in current.events.mouse and buttonPress[button]:
    # mark as consumed but don't block other onClickOutside's
    inner

template onRightClick*(inner: untyped) =
  ## On right click event handler.
  current.listens.mouse.incl(evPress)
  if evPress in current.events.mouse and buttonDown[MOUSE_RIGHT]:
    inner

template onMouseDown*(inner: untyped, button = MOUSE_LEFT) =
  ## On when mouse is down and overlapping the element.
  current.listens.mouse.incl(evDown)
  if evDown in current.events.mouse and buttonDown[button]:
    inner

template onHover*(inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.mouse.incl(evHover)
  if evHover in current.events.mouse:
    inner

template onHoverOut*(inner: untyped) =
  ## Code in the block will run when hovering outside the box.
  current.listens.mouse.incl(evHoverOut)
  if evHoverOut in current.events.mouse:
    inner

template onDown*(inner: untyped, button = MOUSE_LEFT) =
  ## Code in the block will run when this mouse is dragging.
  current.listens.mouse.incl(evPress)
  if evPress in current.events.mouse and buttonPress[button]:
    inner

template onScroll*(inner: untyped) =
  ## Code in the block will run when mouse scrolls
  current.listens.gesture.incl(evScroll)
  if evScroll in current.events.gesture:
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

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

template Em*(size: float32): UICoord =
  ## unit size relative to current font size
  current.textStyle.fontSize * size.UICoord

proc `'em`*(n: string): UICoord =
  ## numeric literal em unit
  result = Em(parseFloat(n))

template Vw*(size: float32): UICoord =
  ## percentage of Viewport width
  root.box.w * size.UICoord / 100.0

proc `'vw`*(n: string): UICoord =
  ## numeric literal view width unit
  result = Vw(parseFloat(n))

template Vh*(size: float32): UICoord =
  ## percentage of Viewport height
  root.box.h * size.UICoord / 100.0

proc `'vh`*(n: string): UICoord =
  ## numeric literal view height unit
  result = Vh(parseFloat(n))

template WPerc*(size: float32): UICoord =
  ## numeric literal percent of parent width
  UICoord(max(0'f32, parent.box.w.float32 * size / 100.0))

proc `'pw`*(n: string): UICoord =
  ## numeric literal percent of parent width
  result = WPerc(parseFloat(n))

template HPerc*(size: float32): UICoord =
  ## percentage of parent height
  UICoord(max(0'f32, parent.box.h.float32 * size / 100.0))

proc `'ph`*(n: string): UICoord =
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

proc orgBox*(x, y, w, h: int|float32|float64|UICoord) =
  ## Sets the box dimensions of the original element for constraints.
  current.box = initBox(float32 x, float32 y, float32 w, float32 h)

proc orgBox*(rect: Box) =
  ## Sets the box dimensions with integers
  orgBox(rect.x, rect.y, rect.w, rect.h)

proc autoOrg*(x, y, w, h: int|float32|float64|UICoord) =
  if current.hasRendered == false:
    let b = Box(x: float32 x, y: float32 y, w: float32 w, h: float32 h)
    orgBox b

proc autoOrg*() =
  if current.hasRendered == false:
    orgBox current.box

proc boxFrom(x, y, w, h: float32) =
  ## Sets the box dimensions.
  current.box = initBox(x, y, w, h)

proc box*(
  x: int|float32|float64|UICoord,
  y: int|float32|float64|UICoord,
  w: int|float32|float64|UICoord,
  h: int|float32|float64|UICoord
) =
  ## Sets the box dimensions with integers
  ## Always set box before orgBox when doing constraints.
  boxFrom(float32 x, float32 y, float32 w, float32 h)
  # autoOrg()
  # orgBox(float32 x, float32 y, float32 w, float32 h)

proc box*(rect: Box) =
  ## Sets the box dimensions with integers
  box(rect.x, rect.y, rect.w, rect.h)

proc size*(
  w: int|float32|float64|UICoord,
  h: int|float32|float64|UICoord
) =
  ## Sets the box dimension width and height
  let cb = current.box
  box(cb.x, cb.y, w, h)
  # orgBox(cb.x, cb.y, float32 w, float32 h)

proc width*(w: int|float32|float64|UICoord) =
  ## Sets the width of current node
  let cb = current.box
  box(cb.x, cb.y, float32 w, float32 cb.h)

proc height*(h: int|float32|float64|UICoord) =
  ## Sets the height of current node
  let cb = current.box
  box(cb.x, cb.y, float32 cb.w, float32 h)

proc offset*(
  x: int|float32|float64|UICoord,
  y: int|float32|float64|UICoord
) =
  ## Sets the box dimension offset
  let cb = current.box
  box(float32 x, float32 y, cb.w, cb.h)
  # orgBox(float32 x, float32 y, cb.w, cb.h)

proc xy*(
  x: int|float32|float64|UICoord,
  y: int|float32|float64|UICoord
) =
  ## Sets the box dimension XY position
  offset(x, y)

proc paddingX*(
  width: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Sets X padding based on `width`. By default
  ## it uses the parent's width. You can use
  ## the `absolute` argument to use the view's
  ## width instead. 
  ## 
  let
    cb = current.box
    tw = if absolute: 100'vw else: 100'pw
  box(cb.x + width.UICoord, cb.y, tw - 2.0*width, cb.h)

proc paddingY*(
  height: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Sets Y padding based on `height`. By default
  ## it uses the parent's height. You can use
  ## the `absolute` argument to use the view's
  ## height instead. 
  ## 
  let
    cb = current.box
    th = if absolute: 100'vh else: 100'ph
  box(cb.x, cb.y + height.UICoord, cb.w, th - 2.0*height)

proc paddingXY*(
  width: int|float32|float64|UICoord,
  height: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Combination of `paddingX` and `paddingY`. 
  paddingX(width, absolute)
  paddingY(height, absolute)

proc paddingXY*(
  padding: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Combination of `paddingX` and `paddingY`. 
  paddingX(padding, absolute)
  paddingY(padding, absolute)


proc centeredX*(
  width: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Center box based on `width`. By default
  ## it uses the parent's width. You can use
  ## the `absolute` argument to use the view's
  ## width instead. 
  ## 
  let
    cb = current.box
    tw = if absolute: 100'vw else: 100'pw
    wpad = (tw - width)/2.0
  box(wpad, cb.y, width, cb.h)

proc centeredY*(
  height: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Center box based on `height`. By default
  ## it uses the parent's height. You can use
  ## the `absolute` argument to use the view's
  ## height instead. 
  ## 
  let
    cb = current.box
    th = if absolute: 100'vh else: 100'ph
    hpad = (th - height)/2.0
  box(cb.x, hpad, cb.w, height)

proc centeredXY*(
  width: int|float32|float64|UICoord,
  height: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Combination of `centerX` and `centerY`. 
  centeredX(width, absolute)
  centeredY(height, absolute)

proc centerXY*(
  padding: int|float32|float64|UICoord,
  absolute = false,
) =
  ## Combination of `centerX` and `centerY`. 
  centeredX(padding, absolute)
  centeredY(padding, absolute)

proc centerAt*(
  x: UICoord,
  y: UICoord,
  absolute = false,
) =
  ## Center box based on `width`. By default
  ## it uses the parent's width. 
  ## 
  let cb = current.box
  box(x - cb.w/2.0, y - cb.h/2.0, cb.w, cb.h)


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Box Stuff
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 

template boxOf*(node: Node) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.box = node.box

template boxSizeOf*(node: Node) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.box = node.box.atXY(0, 0)

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
  current.textStyle.fontSize = fontSize.UICoord
  current.textStyle.fontWeight = fontWeight.UICoord
  current.textStyle.lineHeight =
      if lineHeight != 0.0: lineHeight.UICoord
      else: defaultLineHeight(current.textStyle)
  current.textStyle.textAlignHorizontal = textAlignHorizontal
  current.textStyle.textAlignVertical = textAlignVertical

proc setFontStyle*(
  node: Node,
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  ## Sets the font.
  node.textStyle = TextStyle()
  node.textStyle.fontFamily = fontFamily
  node.textStyle.fontSize = fontSize.UICoord
  node.textStyle.fontWeight = fontWeight.UICoord
  node.textStyle.lineHeight =
      if lineHeight != 0.0: lineHeight.UICoord
      else: defaultLineHeight(node.textStyle)
  node.textStyle.textAlignHorizontal = textAlignHorizontal
  node.textStyle.textAlignVertical = textAlignVertical

proc font*(
  node: Node,
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  node.setFontStyle(
    fontFamily,
    fontSize,
    fontWeight,
    lineHeight,
    textAlignHorizontal,
    textAlignVertical)

proc fontOf*(node: Node) =
  ## Sets the font family.
  current.textStyle = node.textStyle

proc fontFamily*(fontFamily: string) =
  ## Sets the font family.
  current.textStyle.fontFamily = fontFamily

proc fontSize*(fontSize: float32) =
  ## Sets the font size in pixels.
  current.textStyle.fontSize = fontSize.UICoord

proc fontSize*(): float32 =
  ## Sets the font size in pixels.
  result = current.textStyle.fontSize.float32

proc fontWeight*(fontWeight: float32) =
  ## Sets the font weight.
  current.textStyle.fontWeight = fontWeight.UICoord

proc lineHeight*(lineHeight: float32) =
  ## Sets the font size.
  current.textStyle.lineHeight = lineHeight.UICoord

proc textStyle*(style: TextStyle) =
  ## Sets the font size.
  current.textStyle = style

proc textStyle*(node: Node) =
  ## Sets the font size.
  current.textStyle = node.textStyle

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
  let rtext = text.toRunes()
  if current.text != rtext:
    current.text = rtext

proc selectable*(v: bool) =
  ## Set text selectable flag.
  current.selectable = v

template binding*(stringVariable, textBox, handler: untyped) =
  ## Makes the current object text-editable and binds it to the stringVariable.
  # echo "binding impl"
  current.bindingSet = true
  selectable true
  editableText true
  if not current.hasKeyboardFocus():
    characters stringVariable
  when not defined(js):
    onClick:
      # echo "binding impl: onclick"
      keyboard.focus(current, textBox)
    onClickOutside:
      # echo "binding impl: onclick outside"
      keyboard.unFocus(current)
  onInput:
    # echo "binding impl: oninput"
    handler
  # echo "binding impl: done\n"

template binding*(stringVariable, textBox, handler: untyped) =
  binding(stringVariable, nil, handler)

template binding*(stringVariable: untyped) =
  binding(stringVariable, nil) do:
    let input = $keyboard.input
    if stringVariable != input:
      stringVariable = input

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Styling and Content
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 

proc image*(imageName: string) =
  ## Sets image fill.
  current.image.name = imageName

proc imageColor*(color: Color) =
  ## Sets image color.
  current.image.color = color

proc imageColor*(color: string, alpha: float32 = 1.0) =
  current.image.color = parseHtmlColor(color)
  current.image.color.a = alpha

proc image*(name: string, color: Color) =
  ## Sets image fill.
  current.image.name = name
  current.image.color = color

proc imageOf*(item: Node) =
  ## Sets image fill.
  current.image = item.image

proc imageTransparency*(alpha: float32) =
  ## Sets image fill.
  current.image.color.a *= alpha

proc imageOf*(item: ImageStyle, transparency: float32) =
  ## Sets image fill.
  current.image = item
  current.image.color.a *= transparency

proc imageOf*(item: ImageStyle) =
  ## Sets image fill.
  current.image = item

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

proc fill*(node: Node) =
  ## Sets background color.
  current.fill = node.fill

proc transparency*(transparency: float32) =
  ## Sets transparency.
  current.transparency = transparency

proc stroke*(color: Color) =
  ## Sets stroke/border color.
  current.stroke.color = color

proc stroke*(color: Color, alpha: float32) =
  ## Sets stroke/border color.
  current.stroke.color = color
  current.stroke.color.a = alpha

proc stroke*(color: string, alpha = 1.0) =
  ## Sets stroke/border color.
  current.stroke.color = parseHtmlColor(color)
  current.stroke.color.a = alpha

proc stroke*(stroke: Stroke) =
  ## Sets stroke/border color.
  current.stroke = stroke

proc strokeWeight*(weight: float32|UICoord) =
  ## Sets stroke/border weight.
  current.stroke.weight = weight.float32

proc stroke*(weight: float32|UICoord, color: string, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = parseHtmlColor(color)
  result.color.a = alpha
  result.weight = weight.float32

proc stroke*(weight: float32|UICoord, color: Color, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = color
  result.color.a = alpha
  result.weight = weight.float32

proc strokeLine*(item: Node, weight: float32|UICoord, color: string, alpha = 1.0) =
  ## Sets stroke/border color.
  current.stroke.color = parseHtmlColor(color)
  current.stroke.color.a = alpha
  current.stroke.weight = weight.float32

proc strokeLine*(weight: float32, color: string, alpha = 1.0'f32) =
  ## Sets stroke/border color.
  current.strokeLine(weight, color, alpha)

proc strokeLine*(node: Node) =
  ## Sets stroke/border color.
  current.stroke.color = node.stroke.color
  current.stroke.weight = node.stroke.weight

proc cornerRadius*(a, b, c, d: UICoord) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = (a.UICoord, b.UICoord, c.UICoord, d.UICoord)

proc cornerRadius*(radius: UICoord) =
  ## Sets all radius of all 4 corners.
  cornerRadius(radius, radius, radius, radius)

proc cornerRadius*(radius: (UICoord, UICoord, UICoord, UICoord)) =
  ## Sets all radius of all 4 corners.
  cornerRadius(radius[0], radius[1], radius[2], radius[3] )

proc cornerRadius*(): UICoord =
  result = current.cornerRadius[0]

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

proc highlight*(color: Color) =
  ## Sets the color of text selection.
  current.highlightColor = color

proc highlight*(color: string, alpha = 1.0) =
  ## Sets the color of text selection.
  current.highlightColor = parseHtmlColor(color)
  current.highlightColor.a = alpha

proc highlight*(node: Node) =
  ## Sets the color of text selection.
  current.highlightColor = node.highlightColor

proc parseHtml*(color: string, alpha = 1.0): Color =
  ## Sets the color of text selection.
  result = parseHtmlColor(color)

proc disabledColor*(color: Color) =
  ## Sets the color of text selection.
  current.disabledColor = color

proc disabledColor*(color: string, alpha = 1.0) =
  ## Sets the color of text selection.
  current.disabledColor = parseHtmlColor(color)
  current.disabledColor.a = alpha

proc disabledColor*(node: Node) =
  ## Sets the color of text selection.
  current.disabledColor = node.highlightColor

proc clearShadows*() =
  ## Clear shadow
  current.shadows.setLen(0)

proc shadows*(node: Node) =
  current.shadows = node.shadows

proc dropShadow*(item: Node; blur, x, y: float32, color: string, alpha: float32) =
  ## Sets drop shadow on an element
  var c = parseHtmlColor(color)
  c.a = alpha
  let sh: Shadow =  Shadow(kind: DropShadow,
                           blur: blur.UICoord,
                           x: x.UICoord,
                           y: y.UICoord,
                           color: c)
  item.shadows.add(sh)

proc dropShadow*(blur, x, y: float32, color: string, alpha: float32) =
  ## Sets drop shadow on an element
  current.dropShadow(blur, x, y, color, alpha)

proc innerShadow*(blur, x, y: float32, color: string, alpha: float32) =
  ## Sets an inner shadow
  var c = parseHtmlColor(color)
  c.a = alpha
  current.shadows.add Shadow(
    kind: InnerShadow,
    blur: blur.UICoord,
    x: x.UICoord,
    y: y.UICoord,
    color: c
  )

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

proc horizontalPadding*(v: UICoord) =
  ## Set the horizontal padding for auto layout.
  current.horizontalPadding = v.UICoord

proc verticalPadding*(v: UICoord) =
  ## Set the vertical padding for auto layout.
  current.verticalPadding = v.UICoord

proc itemSpacing*(v: UICoord) =
  ## Set the item spacing for auto layout.
  current.itemSpacing = v.UICoord

proc zlevel*(zidx: ZLevel) =
  ## Sets zLevel.
  current.zLevel = zidx

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Scrolling support
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 

# TODO: fixme?
type
  ScrollPip* = ref object
    drag*: bool
    hPosLast: UICoord
    hPos: UICoord
    offLast: UICoord

variants ScrollEvent:
  ## variant case types for scroll events
  ScrollTo(perc: float32)
  ScrollPage(amount: float32)

# {.push hint[Name]: off.}
# variantp ScrollEvent:
#   ScrollTo(perc: float32)
#   ScrollPage(amount: float32)
# {.pop.}

proc scrollEvent*(events: GeneralEvents, evt: ScrollEvent) =
  events["$scrollbar.event"] = evt

proc scrollBars*(scrollBars: bool, hAlign = hRight, setup: proc() = nil) =
  ## Causes the parent to clip the children and draw scroll bars.
  current.scrollBars = scrollBars
  if scrollBars == true:
    current.clipContent = true

    onScroll:
      let
        yoffset = mouse.wheelDelta.UICoord
        ph = parent.screenBox.h
        ch = (current.screenBox.h - ph).clamp(0'ui, current.screenBox.h)
      current.offset.y -= yoffset
      current.offset.y = current.offset.y.clamp(0'ui, ch)

  # todo? make useData?
  let evts = useEvents()
  let pip = evts.mgetOrPut("$scrollbar", ScrollPip)

  let
    halign: HAlign = hAlign
    width = 14'ui

  let
    ## Compute various scroll bar items
    parentBox = parent.screenBox
    currBox = current.screenBox
    boxRatio = (parentBox.h/currBox.h).clamp(0.0'ui, 1.0'ui)
    scrollBoxH = boxRatio * parentBox.h

  if pip.drag:
    ## Calculate drag of scroll bar
    pip.hPos = mouse.pos.descaled.y 
    pip.drag = buttonDown[MOUSE_LEFT]

    let
      delta = (pip.hPos - pip.hPosLast)
      topOffsetY = max(currBox.h - parentBox.h, 0'ui)
    
    current.offset.y = (pip.offLast + delta / boxRatio)
    current.offset.y = current.offset.y.clamp(0'ui, topOffsetY)

  let
    xx = if halign == hLeft: 0'ui else: currBox.w - width
    currOffset = current.offset.y
    hPerc = clamp(currOffset/(currBox.h - parentBox.h), 0'ui, 1'ui)
    bx = initBox(x= xx,
                  y= hPerc*(parentBox.h - scrollBoxH),
                  w= width,
                  h= scrollBoxH)
  
  # define basics of scrollbar
  rectangle "$scrollbar":
    current.kind = nkScrollBar
    box bx
    current.offset = parent.offset * -1'ui
    layoutAlign laIgnore
    fill scrollBarFill
    onHover:
      fill scrollBarHighlight
    if not setup.isNil:
      setup()
    onClick:
      pip.drag = true
      pip.hPosLast = mouse.pos.descaled.y 
      pip.offLast = -current.offset.y


proc defaultTheme*() =
  fill "#9D9D9D"
  cursorColor  "#77D3FF", 0.33
  highlight "#77D3FF", 0.77
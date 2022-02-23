import algorithm, chroma, fidget/common, fidget/input, json, macros, strutils,
    tables, vmath, bumpy

export chroma, common, input, vmath

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
  # Process the start of the node.

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?

  if parent.nodes.len <= parent.diffIndex:
    # Create Node.
    current = Node()
    current.id = id
    current.uid = newUId()
    parent.nodes.add(current)
  else:
    # Reuse Node.
    current = parent.nodes[parent.diffIndex]
    if current.id == id:
      # Same node.
      discard
    else:
      # Big change.
      current.id = id
    current.resetToDefault()

  current.kind = kind
  current.textStyle = parent.textStyle
  current.cursorColor = parent.cursorColor
  current.highlightColor = parent.highlightColor
  current.transparency = parent.transparency
  nodeStack.add(current)
  inc parent.diffIndex

  current.idPath = ""
  for i, g in nodeStack:
    if i != 0:
      current.idPath.add "."
    if g.id != "":
      current.idPath.add g.id
    else:
      current.idPath.add $g.diffIndex

  current.diffIndex = 0

proc postNode() =
  ## Node drawing is done.
  
  # run after inner hooks
  for hook in current.postHooks:
    hook()
  current.postHooks = @[]

  current.removeExtraChildren()

  let mpos = mouse.pos + current.totalOffset 
  if not mouse.consumed and mpos.overlaps(current.screenBox):
    if mouse.wheelDelta != 0:
      if current.scrollBars:
        let
          yoffset = mouse.wheelDelta * 2*common.uiScale
          ph = parent.screenBox.h
          ch = current.screenBox.h - ph
          perc = ph/ch
          hPerc = yoffset/ch
        current.offset.y -= yoffset
        current.offset.y = current.offset.y.clamp(0, ch)
        mouse.consumed = true

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

template node(kind: NodeKind, id: string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, id)
  inner
  postNode()

template group*(id: string, inner: untyped): untyped =
  ## Starts a new node.
  node(nkGroup, id, inner)

template frame*(id: string, inner: untyped): untyped =
  ## Starts a new frame.
  node(nkFrame, id, inner)

template rectangle*(id: string, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, id, inner)

template text*(id: string, inner: untyped): untyped =
  ## Starts a new text element.
  node(nkText, id, inner)

template component*(id: string, inner: untyped): untyped =
  ## Starts a new component.
  node(nkComponent, id, inner)

template instance*(id: string, inner: untyped): untyped =
  ## Starts a new instance of a component.
  node(nkInstance, id, inner)

template group*(inner: untyped): untyped =
  ## Starts a new node.
  node(nkGroup, "", inner)

template frame*(inner: untyped): untyped =
  ## Starts a new frame.
  node(nkFrame, "", inner)

template rectangle*(inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, "", inner)

template text*(inner: untyped): untyped =
  ## Starts a new text element.
  node(nkText, "", inner)

template component*(inner: untyped): untyped =
  ## Starts a new component.
  node(nkComponent, "", inner)

template instance*(inner: untyped): untyped =
  ## Starts a new instance of a component.
  node(nkInstance, "", inner)

template rectangle*(color: string|Color) =
  ## Shorthand for rectangle with fill.
  rectangle "":
    box 0, 0, parent.getBox().w, parent.getBox().h
    fill color

proc mouseOverlapLogic*(): bool =
  ## Returns true if mouse overlaps the current node.
  let mpos = mouse.pos + current.totalOffset 
  let act = 
    (not popupActive or inPopup) and
    current.screenBox.w > 0 and
    current.screenBox.h > 0 
  # if act:
    # echo "mouseOverlap: ", $mpos, " morig: ", $mouse.pos
  act and mpos.overlaps(current.screenBox)

template onClick*(inner: untyped) =
  ## On click event handler.
  if mouse.click and mouseOverlapLogic():
    inner

template onClickOutside*(inner: untyped) =
  ## On click outside event handler. Useful for deselecting things.
  if mouse.click and not mouseOverlapLogic():
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

template Em*(size: float32): float32 =
  ## Code in the block will run when this box is hovered.
  current.textStyle.fontSize * 0.5 * size

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

proc id*(id: string) =
  ## Sets ID.
  current.id = id

proc font*(
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  ## Sets the font.
  current.textStyle.fontFamily = fontFamily
  current.textStyle.fontSize = common.uiScale*fontSize
  current.textStyle.fontWeight = common.uiScale*fontWeight
  current.textStyle.lineHeight = if lineHeight != 0.0: common.uiScale*lineHeight else: common.uiScale*fontSize
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

proc textAlign*(textAlignHorizontal: HAlign, textAlignVertical: VAlign) =
  ## Sets the horizontal and vertical alignment.
  current.textStyle.textAlignHorizontal = textAlignHorizontal
  current.textStyle.textAlignVertical = textAlignVertical

proc textPadding*(textPadding: int) =
  ## Sets the text padding on editable multiline text areas.
  current.textPadding = textPadding

proc textAutoResize*(textAutoResize: TextAutoResize) =
  ## Set the text auto resize mode.
  current.textStyle.autoResize = textAutoResize

proc characters*(text: string) =
  ## Sets text.
  if current.text != text:
    current.text = text

proc image*(imageName: string) =
  ## Sets image fill.
  current.imageName = imageName

proc orgBox*(x, y, w, h: int|float32|float32) =
  ## Sets the box dimensions of the original element for constraints.
  let b = Rect(x: float32 x, y: float32 y, w: float32 w, h: float32 h)
  current.setOrgBox(b, raw=false)

proc box*(x, y, w, h: float32) =
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
  box(float32 x, float32 y, float32 w, float32 h)
  orgBox(float32 x, float32 y, float32 w, float32 h)

proc box*(rect: Rect) =
  ## Sets the box dimensions with integers
  box(rect.x, rect.y, rect.w, rect.h)

proc rotation*(rotationInDeg: float32) =
  ## Sets rotation in degrees.
  current.rotation = rotationInDeg

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
  current.strokeWeight = weight

proc zLevel*(zLevel: int) =
  ## Sets zLevel.
  current.zLevel = zLevel

proc cornerRadius*(a, b, c, d: float32) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = (3*a, 3*b, 3*c, 3*d)

proc cornerRadius*(radius: float32) =
  ## Sets all radius of all 4 corners.
  cornerRadius(radius, radius, radius, radius)

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
  ## Sets drawable, drawable in HTML creates a canvas.
  var c = parseHtmlColor(color)
  c.a = alpha
  current.shadows.add Shadow(kind: DropShadow, blur: blur, x: x, y: y, color: c)

proc innerShadow*(blur, x, y: float32, color: string, alpha: float32) =
  ## Sets drawable, drawable in HTML creates a canvas.
  var c = parseHtmlColor(color)
  c.a = alpha
  current.shadows.add(Shadow(
    kind: InnerShadow,
    blur: blur,
    x: x,
    y: y,
    color: c
  ))

proc drawable*(drawable: bool) =
  ## Sets drawable, drawable in HTML creates a canvas.
  current.drawable = drawable

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

proc parseParams*(): Table[string, string] =
  ## Parses the params of the main URL.
  let splitSearch = getUrl().split('?')
  if len(splitSearch) == 1:
    return

  let noHash = splitSearch[1].split('#')[0]
  for pair in noHash[0..^1].split("&"):
    let
      arr = pair.split("=")
      key = arr[0]
      val = arr[1]
    result[key] = val

var
  pipDrag = true
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
    fill "#5C8F9C", 0.4
    onHover:
      fill "#5C8F9C", 0.9
    onClick:
      pipDrag = true
      pipHPosLast = mouse.descaled(pos).y 
      pipOffLast = -current.descaled(offset).y

  # echo "pipOffLast : ", pipOffLast, " curr: ", current.descaled(offset).y
  ## add post inner callback to calculate the scrollbar box
  current.postHooks.add proc() =
    let
      halign: HAlign = hAlign
      cr = 4.0'f32
      width = 14'f32

      ph = parent.descaled(screenBox).h
      nh = current.descaled(screenBox).h - ph
      nw = current.descaled(screenBox).w
      ch = current.descaled(screenBox).h - ph
      perc = ph/nh/2
      sh = perc*ph

    if pipDrag:
      pipHPos = mouse.descaled(pos).y 
      pipDrag = buttonDown[MOUSE_LEFT]
      let pipDelta = (pipHPos - pipHPosLast)
      ## ick, this is slightly off, not sure how to fix 
      current.offset.y = 4*uiScale*pipDelta + uiScale*(pipOffLast)
      current.offset.y = current.offset.y.clamp(0, uiScale*ch)

    let
      yo = current.descaled(offset).y()
      hPerc = yo/nh
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
      if (bx.w + bx.h) > 0.0:
        sb.cornerRadius = (3*cr, 3*cr, 3*cr, 3*cr)
      current.nodes.delete(idx)
      current.nodes.insert(sb, 0)
    else:
      raise newException(Exception, "scrollbar defined but node is missing")


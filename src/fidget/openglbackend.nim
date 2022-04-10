import chroma, common, hashes, input, internal, opengl/base,
    opengl/context, os, strformat, strutils, tables, times, typography,
    typography/textboxes, unicode, vmath, opengl/formatflippy, bumpy,
    typography/svgfont, pixie

when not defined(emscripten) and not defined(fidgetNoAsync):
  import httpClient, asyncdispatch, asyncfutures, json

export input

import sugar

type
  Context = context.Context

var
  ctx*: Context
  glyphOffsets: Table[Hash, Vec2]
  windowTitle, windowUrl: string

  # Used for double-clicking
  multiClick: int
  lastClickTime: float
  currLevel: ZLevel

computeTextLayout = proc(node: Node) =
  var font = fonts[node.textStyle.fontFamily]
  font.size = node.textStyle.fontSize
  font.lineHeight = node.textStyle.lineHeight
  if font.lineHeight == 0:
    font.lineHeight = font.size
  var
    boundsMin: Vec2
    boundsMax: Vec2
    size = node.getBox(raw=true).wh
  if node.textStyle.autoResize == tsWidthAndHeight:
    size.x = 0
  node.textLayout = font.typeset(
    node.text.toRunes(),
    pos = vec2(0, 0),
    size = size,
    hAlignMode(node.textStyle.textAlignHorizontal),
    vAlignMode(node.textStyle.textAlignVertical),
    clip = false,
    boundsMin = boundsMin,
    boundsMax = boundsMax
  )
  node.textLayoutWidth = boundsMax.x - boundsMin.x
  node.textLayoutHeight = boundsMax.y - boundsMin.y


proc processHooks(parent, node: Node) =
  ## compute hooks
  # if node.id == "dropdown":
    # echo "draw:scroll:id: ", node.idPath,
        #  " ph: ", parent.descaled(screenBox),
        #  " curr: ", node.descaled(screenBox)

  for child in node.nodes:
    processHooks(node, child)

proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = true

proc focus*(keyboard: Keyboard, node: Node) =
  if keyboard.focusNode != node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = node
    keyboard.focusNode = node

    var font = fonts[node.textStyle.fontFamily]
    font.size = node.textStyle.fontSize
    font.lineHeight = node.textStyle.lineHeight
    # if font.lineHeight == 0:
      # font.lineHeight = font.size
    keyboard.input = node.text
    textBox = newTextBox(
      font,
      int node.screenBox.w,
      int node.screenBox.h,
      node.text,
      hAlignMode(node.textStyle.textAlignHorizontal),
      vAlignMode(node.textStyle.textAlignVertical),
      node.multiline,
      worldWrap = true,
    )
    textBox.editable = node.editableText
    textBox.scrollable = true

    refresh()

proc unFocus*(keyboard: Keyboard, node: Node) =
  if keyboard.focusNode == node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = nil
    keyboard.focusNode = nil

proc drawText(node: Node) =
  if node.textStyle.fontFamily notin fonts:
    quit &"font not found: {node.textStyle.fontFamily}"

  var font = fonts[node.textStyle.fontFamily]
  font.size = node.textStyle.fontSize
  font.lineHeight = node.textStyle.lineHeight
  if font.lineHeight == 0:
    font.lineHeight = font.size

  let mousePos = mouse.pos - node.screenBox.xy

  if mouse.pos.overlaps(node.screenBox):
    if node.selectable and mouse.wheelDelta != 0:
      keyboard.focus(node)
    elif node.selectable and mouse.down:
      # mouse actions click, drag, double clicking
      keyboard.focus(node)
      if mouse.click:
        if epochTime() - lastClickTime < 0.5:
          inc multiClick
        else:
          multiClick = 0
        lastClickTime = epochTime()
        if multiClick == 1:
          textBox.selectWord(mousePos)
          buttonDown[MOUSE_LEFT] = false
        elif multiClick == 2:
          textBox.selectParagraph(mousePos)
          buttonDown[MOUSE_LEFT] = false
        elif multiClick == 3:
          textBox.selectAll()
          buttonDown[MOUSE_LEFT] = false
        else:
          textBox.mouseAction(mousePos, click = true, keyboard.shiftKey)

  if textBox != nil and
      mouse.down and
      not mouse.click and
      keyboard.focusNode == node:
    # Dragging the mouse:
    textBox.mouseAction(mousePos, click = false, keyboard.shiftKey)

  let editing = keyboard.focusNode == node

  if editing:
    if textBox.size != node.screenBox.wh:
      textBox.resize(node.screenBox.wh)
    node.textLayout = textBox.layout
    ctx.saveTransform()
    ctx.translate(-textBox.scroll)
    for rect in textBox.selectionRegions():
      ctx.fillRect(rect, node.highlightColor)
  else:
    discard

  # draw characters
  for glyphIdx, pos in node.textLayout:
    if pos.character notin font.typeface.glyphs:
      continue
    if pos.rune == Rune(32):
      # Don't draw space, even if font has a char for it.
      continue

    let
      font = pos.font
      subPixelShift = floor(pos.subPixelShift * 10) / 10
      fontFamily = node.textStyle.fontFamily

    var
      hashFill = hash((
        2344,
        fontFamily,
        pos.character,
        (font.size*100).int,
        (subPixelShift*100).int,
        0
      ))
      hashStroke: Hash

    if node.strokeWeight > 0:
      hashStroke = hash((
        9812,
        fontFamily,
        pos.character,
        (font.size*100).int,
        (subPixelShift*100).int,
        node.strokeWeight
      ))

    if hashFill notin ctx.entries:
      var
        glyph = font.typeface.glyphs[pos.character]
        glyphOffset: Vec2
      let glyphFill = font.getGlyphImage(
        glyph,
        glyphOffset,
        subPixelShift = subPixelShift
      )
      ctx.putImage(hashFill, glyphFill)
      glyphOffsets[hashFill] = glyphOffset

    if node.strokeWeight > 0 and hashStroke notin ctx.entries:
      var
        glyph = font.typeface.glyphs[pos.character]
        glyphOffset: Vec2
      let glyphFill = font.getGlyphImage(
        glyph,
        glyphOffset,
        subPixelShift = subPixelShift
      )
      let glyphStroke = glyphFill.outlineBorder(node.strokeWeight.int)
      ctx.putImage(hashStroke, glyphStroke)

    let
      glyphOffset = glyphOffsets[hashFill]
      charPos = vec2(pos.rect.x + glyphOffset.x, pos.rect.y + glyphOffset.y)

    if node.strokeWeight > 0 and node.stroke.a > 0:
      ctx.drawImage(
        hashStroke,
        charPos - vec2(node.strokeWeight, node.strokeWeight),
        node.stroke
      )

    ctx.drawImage(hashFill, charPos, node.fill)

  if editing:
    if textBox.cursor == textBox.selector and node.editableText:
      # draw cursor
      ctx.fillRect(textBox.cursorRect, node.cursorColor)
    # debug
    # ctx.fillRect(textBox.selectorRect, rgba(0, 0, 0, 255).color)
    # ctx.fillRect(rect(textBox.mousePos, vec2(4, 4)), rgba(255, 128, 128, 255).color)
    ctx.restoreTransform()

  #ctx.clearMask()

proc capture*(mouse: Mouse) =
  captureMouse()

proc release*(mouse: Mouse) =
  releaseMouse()

proc hide*(mouse: Mouse) =
  hideMouse()

proc remove*(node: Node) =
  ## Removes the node.
  discard

proc removeExtraChildren*(node: Node) =
  ## Deal with removed nodes.
  node.nodes.setLen(node.diffIndex)

template isOnZLayer(): bool =
  # if currLevel == 1: echo "islevel: ", node.zLevel == currLevel, " ", node.zLevel, " ", currLevel
  node.zLevel == currLevel

proc draw*(node, parent: Node) =
  ## Draws the node.
  ## 
  ## This is the primary routine that handles setting up the OpenGL
  ## context that will get rendered. This doesn't trigger the actual
  ## OpenGL rendering, but configures the various shaders and elements.
  ## 
  ## Note that visiable draw calls need to check they're on the current
  ## active ZLevel (z-index). 

  # handles setting up scrollbar region
  if isOnZLayer and node.id == "$scrollbar":
    ctx.saveTransform()
    ctx.translate(parent.offset)

  # setup the opengl context to match the current node size and position
  ctx.saveTransform()
  ctx.translate(node.screenBox.xy)

  # handles setting up scrollbar region
  if node.rotation != 0:
    ctx.translate(node.screenBox.wh/2)
    ctx.rotate(node.rotation/180*PI)
    ctx.translate(-node.screenBox.wh/2)

  # handle clipping children content based on this node
  if isOnZLayer and node.clipContent:
    ctx.beginMask()
    if node.cornerRadius[0] != 0:
      ctx.fillRoundedRect(rect(
        0, 0,
        node.screenBox.w, node.screenBox.h
      ), rgba(255, 0, 0, 255).color, node.cornerRadius[0])
    else:
      ctx.fillRect(rect(
        0, 0,
        node.screenBox.w, node.screenBox.h
      ), rgba(255, 0, 0, 255).color)
    ctx.endMask()

  # hacky method to draw drop shadows... should probably be done in opengl sharders
  if isOnZLayer and node.shadows.len() > 0:
    let shadow = node.shadows[0]

    let blur = shadow.blur / 7.0
    for i in 0..6:
      # for j in 0..4:
      let j = i
      ctx.fillRoundedRect(rect(
        shadow.x + uiScale*i.toFloat()*blur, shadow.y + uiScale*j.toFloat()*blur,
        node.screenBox.w, node.screenBox.h
      ), shadow.color, node.cornerRadius[0])
      

  # draw visiable decorations for node
  if node.kind == nkText:
    if isOnZLayer:
      drawText(node)
  elif isOnZLayer:
    if node.fill.a > 0:
      if node.imageName == "":
        if node.cornerRadius[0] != 0:
          ctx.fillRoundedRect(rect(
            0, 0,
            node.screenBox.w, node.screenBox.h
          ), node.fill, node.cornerRadius[0])
        else:
          ctx.fillRect(rect(
            0, 0,
            node.screenBox.w, node.screenBox.h
          ), node.fill)

    if node.stroke.a > 0 and node.strokeWeight > 0 and node.kind != nkText:
      ctx.strokeRoundedRect(rect(
        0, 0,
        node.screenBox.w, node.screenBox.h
      ), node.stroke, node.strokeWeight, node.cornerRadius[0])

    if node.imageName != "":
      let path = dataDir / node.imageName
      ctx.drawImage(path, pos = vec2(0, 0), color = node.imageColor, size = vec2(node.screenBox.w, node.screenBox.h))

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  if node.scrollBars:
    # handles drawing actual scrollbars
    ctx.saveTransform()
    ctx.translate(-node.offset)

  for j in 1 .. node.nodes.len:
    node.nodes[^j].draw(node)

  if node.scrollBars:
    ctx.restoreTransform()

  if isOnZLayer and node.clipContent:
    ctx.popMask()

  if isOnZLayer and node.id == "$scrollbar":
    ctx.restoreTransform()


proc openBrowser*(url: string) =
  ## Opens a URL in a browser
  discard

# proc windowLoop() {.thread.} =
#   base.start(openglVersion, msaa, mainLoopMode)
#   while true:
#     echo "window: "

proc setupFidget(
  openglVersion: (int, int),
  msaa: MSAA,
  mainLoopMode: MainLoopMode,
  pixelate: bool,
  forcePixelScale: float32,
  atlasSize: int = 1024
) =
  pixelScale = forcePixelScale

  base.start(openglVersion, msaa, mainLoopMode)
  # var thr: Thread[void]
  # createThread(thr, timerFunc)

  setWindowTitle(windowTitle)
  ctx = newContext(atlasSize = atlasSize, pixelate = pixelate, pixelScale = pixelScale)
  requestedFrame = true

  base.drawFrame = proc() =
    clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
    ctx.beginFrame(windowFrame)
    ctx.saveTransform()
    ctx.scale(ctx.pixelScale)

    mouse.cursorStyle = Default

    setupRoot()
    scrollBox.x = float 0
    scrollBox.y = float 0
    scrollBox.w = windowLogicalSize.x
    scrollBox.h = windowLogicalSize.y
    root.setBox(scrollBox, raw=true)

    if textBox != nil:
      keyboard.input = textBox.text

    drawMain()

    root.removeExtraChildren()

    computeLayout(nil, root)
    computeScreenBox(nil, root)
    processHooks(nil, root)

    # Only draw the root after everything was done:
    for zidx in ZLevel:
      # draw root for each level
      currLevel = zidx
      root.draw(root)

    ctx.restoreTransform()
    ctx.endFrame()

    # Only set mouse style when it changes.
    if mouse.prevCursorStyle != mouse.cursorStyle:
      mouse.prevCursorStyle = mouse.cursorStyle
      echo mouse.cursorStyle
      case mouse.cursorStyle:
        of Default:
          setCursor(cursorDefault)
        of Pointer:
          setCursor(cursorPointer)
        of Grab:
          setCursor(cursorGrab)
        of NSResize:
          setCursor(cursorNSResize)

    when defined(testOneFrame):
      ## This is used for test only
      ## Take a screen shot of the first frame and exit.
      var img = takeScreenshot()
      img.writeFile("screenshot.png")
      quit()

  useDepthBuffer(false)

  if loadMain != nil:
    loadMain()

proc asyncPoll() =
  when not defined(emscripten) and not defined(fidgetNoAsync):
    if hasPendingOperations():
      poll()
      if isEvent:
        isEvent = false
        eventTimePost = epochTime()
        echo "user input event delay: ", eventTimePost - eventTimePre

    # var haveCalls = false
    # for call in httpCalls.values:
    #   if call.status == Loading:
    #     haveCalls = true
    #     break
    # if haveCalls:
    #   poll()

import os
proc timerFunc() {.thread.} =
  while true:
    echo fmt"dtAvg: {dtAvg=} fps: {fps=} avgFrameTime: {avgFrameTime=}"
    os.sleep(1_000)

type
  MainProc* = proc () 

proc startFidget*(
  draw: proc() = nil,
  tick: proc() = nil,
  load: proc() = nil,
  fullscreen = false,
  w: Positive = 1280,
  h: Positive = 800,
  openglVersion = (3, 3),
  msaa = msaaDisabled,
  mainLoopMode: MainLoopMode = RepaintOnEvent,
  pixelate = false,
  pixelScale = 1.0,
  uiScale = 1.0
) =
  ## Starts Fidget UI library
  common.fullscreen = fullscreen
  common.uiScale = uiScale
  if not fullscreen:
    windowSize = vec2(w.float32, h.float32)
  drawMain = draw
  tickMain = tick
  loadMain = load
  let atlasStartSz = 1024 shl uiScale.round().toInt()
  echo fmt"{atlasStartSz=}"
  setupFidget(openglVersion, msaa, mainLoopMode, pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale
  when defined(emscripten):
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    proc mainLoop() {.cdecl.} =
      asyncPoll()
      updateLoop()
    emscripten_set_main_loop(main_loop, 0, true)
  else:

    # updateLoop(false)
    # refresh()
    # updateLoop(false)

    while base.running:
      updateLoop()
      asyncPoll()
    exit()

proc getTitle*(): string =
  ## Gets window title
  windowTitle

proc setTitle*(title: string) =
  ## Sets window title
  if (windowTitle != title):
    windowTitle = title
    setWindowTitle(title)
    refresh()

proc setWindowBounds*(min, max: Vec2) =
  base.setWindowBounds(min, max)

proc getUrl*(): string =
  windowUrl

proc setUrl*(url: string) =
  windowUrl = url
  refresh()

proc loadFontAbsolute*(name: string, pathOrUrl: string) =
  ## Loads fonts anywhere in the system.
  ## Not supported on js, emscripten, ios or android.
  if pathOrUrl.endsWith(".svg"):
    fonts[name] = readFontSvg(pathOrUrl)
  elif pathOrUrl.endsWith(".ttf"):
    fonts[name] = readFontTtf(pathOrUrl)
  elif pathOrUrl.endsWith(".otf"):
    fonts[name] = readFontOtf(pathOrUrl)
  else:
    raise newException(Exception, "Unsupported font format")

proc loadFont*(name: string, pathOrUrl: string) =
  ## Loads the font from the dataDir.
  loadFontAbsolute(name, dataDir / pathOrUrl)

proc setItem*(key, value: string) =
  ## Saves value into local storage or file.
  writeFile(&"{key}.data", value)

proc getItem*(key: string): string =
  ## Gets a value into local storage or file.
  readFile(&"{key}.data")

when not defined(emscripten) and not defined(fidgetNoAsync):
  proc httpGetCb(future: Future[string]) =
    refresh()

  proc httpGet*(url: string): HttpCall =
    if url notin httpCalls:
      result = HttpCall()
      var client = newAsyncHttpClient()
      echo "new call"
      result.future = client.getContent(url)
      result.future.addCallback(httpGetCb)
      httpCalls[url] = result
      result.status = Loading
    else:
      result = httpCalls[url]

    if result.status == Loading and result.future.finished:
      result.status = Ready
      try:
        result.data = result.future.read()
        result.json = parseJson(result.data)
      except HttpRequestError:
        echo getCurrentExceptionMsg()
        result.status = Error

    return

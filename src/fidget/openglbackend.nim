import chroma, common, hashes, input, internal, opengl/base,
    opengl/context, os, strformat, strutils, tables, times, typography,
    typography/textboxes, unicode, vmath, bumpy,
    typography/svgfont, pixie

import opengl/draw

when not defined(emscripten) and not defined(fidgetNoAsync):
  import httpClient, asyncdispatch, asyncfutures, json

export input, draw

var
  windowTitle, windowUrl: string

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

proc removeExtraChildren*(node: Node) =
  ## Deal with removed nodes.
  node.nodes.setLen(node.diffIndex)

proc processHooks(parent, node: Node) =
  for child in node.nodes:
    processHooks(node, child)

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
    root.drawRoot()

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
# 
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
  ## 
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
    while base.running:
      updateLoop()
      asyncPoll()
    exit()

proc openBrowser*(url: string) =
  ## Opens a URL in a browser
  discard

proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = true

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

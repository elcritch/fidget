import std/hashes, unicode, os, strformat, tables, times

import typography, typography/textboxes
import pixie, chroma, vmath, bumpy

import context, formatflippy
import ../input, ../common

type
  Context = context.Context

var
  ctx*: Context
  glyphOffsets: Table[Hash, Vec2]

  # Used for double-clicking
  multiClick: int
  lastClickTime: float
  currLevel: ZLevel

proc sum*(rect: Rect): float32 =
  result = rect.x + rect.y + rect.w + rect.h
proc sum*(rect: (float32, float32, float32, float32)): float32 =
  result = rect[0] + rect[1] + rect[2] + rect[3]

proc atXY*(rect: Rect, x, y: float64|float32|int): Rect =
  result = rect
  result.x = x.float32
  result.y = y.float32

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

    requestedFrame = true


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
      # FIXME: use unicode 'is whitespace' ?
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

import macros

macro ifdraw(check, code: untyped, post: untyped = nil) =
  ## check if code should be drawn
  result = newStmtList()
  let checkval = genSym(nskLet, "checkval")
  result.add quote do:
    let `checkval` = node.zLevel == currLevel and `check`
    if `checkval`: `code`
  if post != nil:
    post.expectKind(nnkFinally)
    let postBlock = post[0]
    result.add quote do:
      defer:
        if `checkval`: `postBlock`

proc drawMasks*(node: Node) =
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

proc drawShadows*(node: Node) =
  ## drawing shadows
  let shadow = node.shadows[0]
  let blurAmt = shadow.blur / 7.0
  for i in 0..6:
    let blurs = uiScale * i.toFloat() * blurAmt
    let box = node.screenBox.atXY(x = shadow.x + blurs,
                                  y = shadow.y + blurs)
    ctx.fillRoundedRect(rect = box,
                        color = shadow.color,
                        radius = node.cornerRadius[0])

proc drawBoxes*(node: Node) =
  ## drawing boxes for rectangles
  if node.fill.a > 0'f32:
    if node.cornerRadius.sum() > 0:
      ctx.fillRoundedRect(rect = node.screenBox.atXY(0, 0),
                          color = node.fill,
                          radius = node.cornerRadius[0])
    else:
      ctx.fillRect(node.screenBox.atXY(0, 0), node.fill)

  if node.highlightColor.a > 0'f32:
    if node.cornerRadius.sum() > 0:
      ctx.fillRoundedRect(rect = node.screenBox.atXY(0, 0),
                          color = node.highlightColor,
                          radius = node.cornerRadius[0])
    else:
      ctx.fillRect(node.screenBox.atXY(0, 0), node.highlightColor)

  if node.stroke.a > 0 and node.strokeWeight > 0:
    ctx.strokeRoundedRect(rect = node.screenBox.atXY(0, 0),
                          color = node.stroke,
                          weight = node.strokeWeight,
                          radius = node.cornerRadius[0])

  if node.imageName != "":
    let path = dataDir / node.imageName
    let size = vec2(node.screenBox.w, node.screenBox.h)
    ctx.drawImage(path,
                  pos = vec2(0, 0),
                  color = node.imageColor,
                  size = size)

proc draw*(node, parent: Node) =
  ## Draws the node.
  ##
  ## This is the primary routine that handles setting up the OpenGL
  ## context that will get rendered. This doesn't trigger the actual
  ## OpenGL rendering, but configures the various shaders and elements.
  ##
  ## Note that visiable draw calls need to check they're on the current
  ## active ZLevel (z-index).

  # setup the opengl context to match the current node size and position
  ctx.saveTransform()
  ctx.translate(node.screenBox.xy)

  # handles setting up scrollbar region
  ifdraw node.id == "$scrollbar":
    ctx.saveTransform()
    ctx.translate(parent.offset)
  finally:
    ctx.restoreTransform()

  # handle node rotation
  ifdraw node.rotation != 0:
    ctx.translate(node.screenBox.wh/2)
    ctx.rotate(node.rotation/180*PI)
    ctx.translate(-node.screenBox.wh/2)

  # handle clipping children content based on this node
  ifdraw node.clipContent:
    ctx.beginMask()
    node.drawMasks()
    ctx.endMask()
  finally:
    ctx.popMask()

  # hacky method to draw drop shadows... should probably be done in opengl sharders
  ifdraw node.shadows.len() > 0:
    node.drawShadows()

  ifdraw true:
    # draw visiable decorations for node
    if node.kind == nkText:
      node.drawText()
    else:
      node.drawBoxes()

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  ifdraw node.scrollBars:
    # handles drawing actual scrollbars
    ctx.saveTransform()
    ctx.translate(-node.offset)
  finally:
    ctx.restoreTransform()

  for j in 1 .. node.nodes.len:
    node.nodes[^j].draw(node)

  # finally blocks will be run here, in reverse order

proc drawRoot*(root: Node) =
  for zidx in ZLevel:
    # draw root for each level
    currLevel = zidx
    root.draw(root)

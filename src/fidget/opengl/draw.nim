import std/hashes, unicode, os, strformat, tables, times

import ../patches/textboxes
import pixie, chroma

import context, formatflippy
import ../input
import ../common
import ../commonutils

type
  Context = context.Context

var
  ctx*: Context
  glyphOffsets: Table[Hash, Vec2]

  # Used for double-clicking
  multiClick: int
  lastClickTime: float
  currLevel: ZLevel

proc focus*(keyboard: Keyboard, node: Node, textBox: TextBox) =
  if keyboard.focusNode != node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = node
    keyboard.focusNode = node

    # keyboard.input = node.text
    currTextBox = node.text
    currTextBox.editable = node.editableText
    currTextBox.scrollable = true
    requestedFrame.inc

proc focus*(keyboard: Keyboard, node: Node) =
  # var font = fonts[node.textStyle.fontFamily]
  # font.size = node.textStyle.fontSize.scaled
  # font.lineHeight = node.textStyle.lineHeight.scaled
  # if font.lineHeight == 0:
  #   font.lineHeight = defaultLineHeight(node.textStyle).scaled
  keyboard.focus(node)


proc unFocus*(keyboard: Keyboard, node: Node) =
  if keyboard.focusNode == node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = nil
    keyboard.focusNode = nil

proc hashFontFill(node: Node, font: Font, rune: Rune): Hash {.inline.} =
  result = hash((
    2344,
    cast[int](font),
    rune.int,
    (font.size*100).int,
    node.stroke.weight
  ))

proc hashFontStroke(node: Node, font: Font, rune: Rune): Hash {.inline.} =
  result = hash((
    9812,
    cast[int](font),
    rune.int,
    (font.size*100).int,
    node.stroke.weight
  ))

proc getGlyphPath(font: Font, rune: Rune): Image = 
  let path = font.typeface.getGlyphPath(rune)
  let bound = path.computeBounds()
  result = newImage(bound.w.int, bound.h.int)
  result.fillPath(path, rgba(255, 255, 255, 255))

proc drawBoxes*(node: Node)

proc drawDrawable*(node: Node) =
  # ctx: Context, poly: seq[Vec2], weight: float32, color: Color
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point.scaled
      bx = node.box.scaled.atXY(pos.x, pos.y)
    ctx.fillRect(bx, node.fill)

proc drawGlyph(node: Node, span, idx: int) =
  let layout = node.text.layout
  let rune = layout.runes[idx]
  let pos = layout.positions[idx]
  let font = layout.fonts[span]

  if font.typeface.hasGlyph(rune):
    return

  if rune == Rune(32):
    # Don't draw space, even if font has a char for it.
    # FIXME: use unicode 'is whitespace' ?
    return

  let
    hashFill = hashFontFill(node, font, rune)

  var
    hashStroke: Hash

  if hashFill notin ctx.entries:
    var
      glyphOffset: Vec2
    let
      glyphFill = font.getGlyphPath(rune)

    ctx.putImage(hashFill, glyphFill)
    glyphOffsets[hashFill] = glyphOffset

  # if node.stroke.weight > 0:
  #   hashStroke = hashFontStroke(node, font, rune)
  #   if hashStroke notin ctx.entries:
  #     let glyphFill = font.getGlyphImage(rune)
  #     let glyphStroke = glyphFill.outlineBorder(node.stroke.weight.int)
  #     ctx.putImage(hashStroke, glyphStroke)

  let
    glyphOffset = glyphOffsets[hashFill]
    charPos = vec2(pos.x + glyphOffset.x, pos.y + glyphOffset.y)

  if node.stroke.weight > 0 and node.stroke.color.a > 0:
    ctx.drawImage(
      hashStroke,
      charPos - vec2(node.stroke.weight,
                      node.stroke.weight),
      node.stroke.color
    )

  ctx.drawImage(hashFill, charPos, node.fill)

proc drawText(node: Node) =
  if node.textStyle.fontFamily notin fonts:
    quit &"font not found: {node.textStyle.fontFamily}"

  # var font = fonts[node.textStyle.fontFamily]
  # font.size = node.textStyle.fontSize.scaled
  # font.lineHeight = node.textStyle.lineHeight.scaled
  # if font.lineHeight == 0:
  #   font.lineHeight = defaultLineHeight(node.textStyle).scaled

  # draw characters
  for spanIndex, (start, stop) in node.text.layout.spans:
    for idx in start..stop:
      node.drawGlyph(spanIndex, idx)
  
import macros

macro ifdraw(check, code: untyped, post: untyped = nil) =
  ## check if code should be drawn
  result = newStmtList()
  let checkval = genSym(nskLet, "checkval")
  result.add quote do:
    let `checkval` = node.zlevel == currLevel and `check`
    if `checkval`: `code`
  if post != nil:
    post.expectKind(nnkFinally)
    let postBlock = post[0]
    result.add quote do:
      defer:
        if `checkval`: `postBlock`

proc drawMasks*(node: Node) =
  if node.cornerRadius[0] != 0'ui:
    ctx.fillRoundedRect(rect(
      0, 0,
      node.screenBox.w.scaled, node.screenBox.h.scaled
    ), rgba(255, 0, 0, 255).color, node.cornerRadius[0].scaled)
  else:
    ctx.fillRect(rect(
      0, 0,
      node.screenBox.w.scaled, node.screenBox.h.scaled
    ), rgba(255, 0, 0, 255).color)

proc drawShadows*(node: Node) =
  ## drawing shadows
  let shadow = node.shadows[0]
  let blurAmt = shadow.blur / 7.0'ui
  for i in 0..6:
    let blurs = i.toFloat().UICoord * blurAmt
    let box = node.screenBox.atXY(x = shadow.x + blurs,
                                  y = shadow.y + blurs)
    ctx.fillRoundedRect(rect = box.scaled,
                        color = shadow.color,
                        radius = node.cornerRadius[0].scaled)

proc drawBoxes*(node: Node) =
  ## drawing boxes for rectangles
  if node.fill.a > 0'f32:
    if node.cornerRadius.sum() > 0'ui:
      ctx.fillRoundedRect(rect = node.screenBox.scaled.atXY(0'f32, 0'f32),
                          color = node.fill,
                          radius = node.cornerRadius[0].scaled)
    else:
      ctx.fillRect(node.screenBox.scaled.atXY(0'f32, 0'f32), node.fill)

  if node.highlightColor.a > 0'f32:
    if node.cornerRadius.sum() > 0'ui:
      ctx.fillRoundedRect(rect = node.screenBox.scaled.atXY(0'f32, 0'f32),
                          color = node.highlightColor,
                          radius = node.cornerRadius[0].scaled)
    else:
      ctx.fillRect(node.screenBox.scaled.atXY(0'f32, 0'f32), node.highlightColor)

  if node.image.name != "":
    let path = dataDir / node.image.name
    let size = vec2(node.screenBox.scaled.w, node.screenBox.scaled.h)
    ctx.drawImage(path,
                  pos = vec2(0, 0),
                  color = node.image.color,
                  size = size)
  
  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    ctx.strokeRoundedRect(rect = node.screenBox.scaled.atXY(0'f32, 0'f32),
                          color = node.stroke.color,
                          weight = node.stroke.weight,
                          radius = node.cornerRadius[0].scaled)

import print

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
  node.hasRendered = true

  ctx.saveTransform()
  ctx.translate(node.screenBox.scaled.xy)

  # handles setting up scrollbar region
  ifdraw node.kind == nkScrollBar:
    ctx.saveTransform()
    ctx.translate(parent.offset.scaled)
  finally:
    ctx.restoreTransform()

  # handle node rotation
  ifdraw node.rotation != 0:
    ctx.translate(node.screenBox.scaled.wh/2)
    ctx.rotate(node.rotation/180*PI)
    ctx.translate(-node.screenBox.scaled.wh/2)

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
    if node.kind == nkText:
      node.drawText()
    elif node.kind == nkDrawable:
      node.drawDrawable()
    else:
      node.drawBoxes()

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  ifdraw node.scrollBars:
    # handles scrolling panel
    ctx.saveTransform()
    ctx.translate(-node.offset.scaled)
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

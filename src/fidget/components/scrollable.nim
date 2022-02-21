import sequtils, typography, unicode, vmath, bumpy

#[
It's hard to implement a text. A text box has many complex features one does not think about
because it is so natural. Here is a small list of the most important ones:

* Typing at location of cursor
* Cursor going left and right
* Backspace and delete
* Cursor going up and down must take into account font and line wrap
* Clicking should select a character edge. Closet edge wins.
* Click and drag should select text, selected text will be between text cursor and select cursor
* Any insert when typing or copy pasting and have selected text, it should get removed and then do normal action
* Copy text should set it to system clipboard
* Cut text should copy and remove selected text
* Paste text should paste at current text cursor, if there is selection it needs to be removed
* Clicking before text should select first character
* Clicking at the end of text should select last character
* Click at the end of the end of the line should select character before the new line
* Click at the end of the start of the line should select character first character and not the newline
* Double click should select current word and space (TODO: stops non world characters, TODO: and enter into word selection mode)
* Double click again should select current paragraph
* Double click again should select everything
* TODO: Selecting during world selection mode should select whole words.
* Text area needs to be able to have margins that can be clicked
* There should be a scroll bar and a scroll window
* Scroll window should stay with the text cursor
* Backspace and delete with selected text remove selected text and don't perform their normal action
]#

type ScrollBox* = ref object
  cursor*: int      # The typing cursor.
  selector*: int    # The selection cursor.
  runes*: seq[Rune] # The runes we are typing.
  width*: int       # Width of text box in px.
  height*: int      # Height of text box in px.
  vAlign*: VAlignMode
  hAling*: HAlignMode
  scrollable*: bool
  wasScrolled*: bool
  editable*: bool
  scroll*: Vec2     # Scroll position.
  font*: Font
  fontSize*: float
  lineHeight*: float
  mousePos*: Vec2
  hasChange*: bool

  multiline*: bool  # Single line only (good for input fields).
  wordWrap*: bool   # Should the lines wrap or not.

  glyphs: seq[GlyphPosition]
  savedX: float

  boundsMin: Vec2
  boundsMax: Vec2

proc clamp(v, a, b: int): int =
  max(a, min(b, v))

proc newScrollBox*(
  font: Font,
  width: int,
  height: int,
  text: string = "",
  hAlign = Left,
  vAlign = Top,
  multiline = true,
  worldWrap = true,
  scrollable = true,
  editable = true,
): ScrollBox =
  ## Creates new empty text box.
  result = ScrollBox()
  result.runes = toRunes(text)
  result.font = font
  result.fontSize = font.size
  result.lineHeight = font.lineHeight
  result.width = width
  result.height = height
  result.hAling = hAlign
  result.vAlign = vAlign
  result.multiline = multiline
  result.wordWrap = worldWrap
  result.scrollable = scrollable
  result.editable = editable

proc cursorWidth*(font: Font): float =
  min(font.size / 12, 1)

proc text*(scrollBox: ScrollBox): string =
  ## Converts internal runes to string.
  $scrollBox.runes

proc `text=`*(scrollBox: ScrollBox, text: string) =
  ## Converts string to internal runes.
  scrollBox.runes = toRunes(text)
  scrollBox.hasChange = true

proc multilineCheck(scrollBox: ScrollBox) =
  ## Makes sure there are not new lines in a single line text box.
  if not scrollBox.multiline:
    scrollBox.runes.keepIf(proc (r: Rune): bool = r != Rune(10))

proc size*(scrollBox: ScrollBox): Vec2 =
  ## Returns with and height as a Vec2.
  vec2(float scrollBox.width, float scrollBox.height)

proc selection*(scrollBox: ScrollBox): HSlice[int, int] =
  ## Returns current selection from.
  result.a = min(scrollBox.cursor, scrollBox.selector)
  result.b = max(scrollBox.cursor, scrollBox.selector)

proc layout*(scrollBox: ScrollBox): seq[GlyphPosition] =
  if scrollBox.glyphs.len == 0:
    scrollBox.font.size = scrollBox.fontSize
    scrollBox.font.lineHeight = scrollBox.lineHeight
    scrollBox.multilineCheck()
    scrollBox.glyphs = scrollBox.font.typeset(
      scrollBox.runes,
      vec2(0, 0),
      size = scrollBox.size,
      scrollBox.hAling,
      scrollBox.vAlign,
      clip = false,
      boundsMin = scrollBox.boundsMin,
      boundsMax = scrollBox.boundsMax
    )
  return scrollBox.glyphs

proc innerHeight*(scrollBox: ScrollBox): int =
  ## Rectangle where selection cursor should be drawn.
  let layout = scrollBox.layout()
  if layout.len > 0:
    let lastPos = layout[^1].selectRect
    return int(lastPos.y + lastPos.h)
  else:
    return int(scrollBox.font.lineHeight)

proc locationRect*(scrollBox: ScrollBox, loc: int): Rect =
  ## Rectangle where cursor should be drawn.
  let layout = scrollBox.layout()
  if layout.len > 0:
    if loc >= layout.len:
      let g = layout[^1]
      # if last char is a new line go to next line.
      if g.character == "\n":
        result.x = 0
        result.y = g.selectRect.y + scrollBox.font.lineHeight
      else:
        result = g.selectRect
        result.x += g.selectRect.w
    else:
      let g = layout[loc]
      result = g.selectRect
  result.w = scrollBox.font.cursorWidth
  result.h = max(scrollBox.font.size, scrollBox.font.lineHeight)

proc cursorRect*(scrollBox: ScrollBox): Rect =
  ## Rectangle where cursor should be drawn.
  scrollBox.locationRect(scrollBox.cursor)

proc cursorPos*(scrollBox: ScrollBox): Vec2 =
  ## Position where cursor should be drawn.
  scrollBox.cursorRect.xy

proc selectorRect*(scrollBox: ScrollBox): Rect =
  ## Rectangle where selection cursor should be drawn.
  scrollBox.locationRect(scrollBox.selector)

proc selectorPos*(scrollBox: ScrollBox): Vec2 =
  ## Position where selection cursor should be drawn.
  scrollBox.cursorRect.xy

proc selectionRegions*(scrollBox: ScrollBox): seq[Rect] =
  ## Selection regions to draw selection of text.
  let sel = scrollBox.selection
  scrollBox.layout.getSelection(sel.a, sel.b)

proc removedSelection*(scrollBox: ScrollBox): bool =
  ## Removes selected runes if they are selected.
  ## Returns true if anything was removed.
  let sel = scrollBox.selection
  if sel.a != sel.b:
    scrollBox.runes.delete(sel.a, sel.b - 1)
    scrollBox.glyphs.setLen(0)
    scrollBox.cursor = sel.a
    scrollBox.selector = scrollBox.cursor
    scrollBox.hasChange = true
    return true
  return false

proc removeSelection(scrollBox: ScrollBox) =
  ## Removes selected runes if they are selected.
  discard scrollBox.removedSelection()

proc adjustScroll*(scrollBox: ScrollBox) =
  ## Adjust scroll to make sure cursor is in the window.
  if scrollBox.scrollable and not scrollBox.wasScrolled:
    let
      r = scrollBox.cursorRect
    # is pos.y inside the window?
    if r.y < scrollBox.scroll.y:
      scrollBox.scroll.y = r.y
    if r.y + r.h > scrollBox.scroll.y + float scrollBox.height:
      scrollBox.scroll.y = r.y + r.h - float scrollBox.height
    # is pos.x inside the window?
    if r.x < scrollBox.scroll.x:
      scrollBox.scroll.x = r.x
    if r.x + r.w > scrollBox.scroll.x + float scrollBox.width:
      scrollBox.scroll.x = r.x + r.w - float scrollBox.width

proc typeCharacter*(scrollBox: ScrollBox, rune: Rune) =
  ## Add a character to the text box.
  if not scrollBox.editable:
    return
  scrollBox.removeSelection()
  # don't add new lines in a single line box.
  if not scrollBox.multiline and rune == Rune(10):
    return
  if scrollBox.cursor == scrollBox.runes.len:
    scrollBox.runes.add(rune)
  else:
    scrollBox.runes.insert(rune, scrollBox.cursor)
  inc scrollBox.cursor
  scrollBox.selector = scrollBox.cursor
  scrollBox.glyphs.setLen(0)
  scrollBox.adjustScroll()
  scrollBox.hasChange = true

proc typeCharacter*(scrollBox: ScrollBox, letter: char) =
  ## Add a character to the text box.
  scrollBox.typeCharacter(Rune(letter))

proc typeCharacters*(scrollBox: ScrollBox, s: string) =
  ## Add a character to the text box.
  if not scrollBox.editable:
    return
  scrollBox.removeSelection()
  for rune in runes(s):
    scrollBox.runes.insert(rune, scrollBox.cursor)
    inc scrollBox.cursor
  scrollBox.selector = scrollBox.cursor
  scrollBox.glyphs.setLen(0)
  scrollBox.adjustScroll()
  scrollBox.hasChange = true

proc copy*(scrollBox: ScrollBox): string =
  ## Returns the text that was copied.
  let sel = scrollBox.selection
  if sel.a != sel.b:
    return $scrollBox.runes[sel.a ..< sel.b]

proc paste*(scrollBox: ScrollBox, s: string) =
  ## Pastes a string.
  if not scrollBox.editable:
    return
  scrollBox.typeCharacters(s)
  scrollBox.savedX = scrollBox.cursorPos.x

proc cut*(scrollBox: ScrollBox): string =
  ## Returns the text that was cut.
  result = scrollBox.copy()
  if not scrollBox.editable:
    return
  scrollBox.removeSelection()
  scrollBox.savedX = scrollBox.cursorPos.x

proc setCursor*(scrollBox: ScrollBox, loc: int) =
  scrollBox.cursor = clamp(loc, 0, scrollBox.runes.len + 1)
  scrollBox.selector = scrollBox.cursor

proc backspace*(scrollBox: ScrollBox, shift = false) =
  ## Backspace command.
  if not scrollBox.editable:
    return
  if scrollBox.removedSelection(): return
  if scrollBox.cursor > 0:
    scrollBox.runes.delete(scrollBox.cursor - 1)
    scrollBox.glyphs.setLen(0)
    scrollBox.adjustScroll()
    dec scrollBox.cursor
    scrollBox.selector = scrollBox.cursor
    scrollBox.hasChange = true

proc delete*(scrollBox: ScrollBox, shift = false) =
  ## Delete command.
  if not scrollBox.editable:
    return
  if scrollBox.removedSelection(): return
  if scrollBox.cursor < scrollBox.runes.len:
    scrollBox.runes.delete(scrollBox.cursor)
    scrollBox.glyphs.setLen(0)
    scrollBox.adjustScroll()
    scrollBox.hasChange = true

proc backspaceWord*(scrollBox: ScrollBox, shift = false) =
  ## Backspace word command. (Usually ctr + backspace).
  if not scrollBox.editable:
    return
  if scrollBox.removedSelection(): return
  if scrollBox.cursor > 0:
    while scrollBox.cursor > 0 and
      not scrollBox.runes[scrollBox.cursor - 1].isWhiteSpace():
      scrollBox.runes.delete(scrollBox.cursor - 1)
      dec scrollBox.cursor
    scrollBox.glyphs.setLen(0)
    scrollBox.adjustScroll()
    scrollBox.selector = scrollBox.cursor
    scrollBox.hasChange = true

proc deleteWord*(scrollBox: ScrollBox, shift = false) =
  ## Delete word command. (Usually ctr + delete).
  if not scrollBox.editable:
    return
  if scrollBox.removedSelection(): return
  if scrollBox.cursor < scrollBox.runes.len:
    while scrollBox.cursor < scrollBox.runes.len and
      not scrollBox.runes[scrollBox.cursor].isWhiteSpace():
      scrollBox.runes.delete(scrollBox.cursor)
    scrollBox.glyphs.setLen(0)
    scrollBox.adjustScroll()
    scrollBox.hasChange = true

proc left*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor left.
  if scrollBox.cursor > 0:
    dec scrollBox.cursor
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
    scrollBox.savedX = scrollBox.cursorPos.x

proc right*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor right.
  if scrollBox.cursor < scrollBox.runes.len:
    inc scrollBox.cursor
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
    scrollBox.savedX = scrollBox.cursorPos.x

proc down*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor down.
  if scrollBox.layout.len == 0:
    return
  let pos = scrollBox.layout.pickGlyphAt(
    vec2(scrollBox.savedX, scrollBox.cursorPos.y + scrollBox.font.lineHeight * 1.5))
  if pos.character != "":
    scrollBox.cursor = pos.count
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
  elif scrollBox.cursorPos.y == scrollBox.layout[^1].selectRect.y:
    # Are we on the last line? Then jump to start location last.
    scrollBox.cursor = scrollBox.runes.len
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor

proc up*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor up.
  if scrollBox.layout.len == 0:
    return
  let pos = scrollBox.layout.pickGlyphAt(
    vec2(scrollBox.savedX, scrollBox.cursorPos.y - scrollBox.font.lineHeight * 0.5))
  if pos.character != "":
    scrollBox.cursor = pos.count
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
  elif scrollBox.cursorPos.y == scrollBox.layout[0].selectRect.y:
    # Are we on the first line? Then jump to start location 0.
    scrollBox.cursor = 0
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor

proc leftWord*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor left by a word (Usually ctr + left).
  if scrollBox.cursor > 0:
    dec scrollBox.cursor
  while scrollBox.cursor > 0 and
    not scrollBox.runes[scrollBox.cursor - 1].isWhiteSpace():
    dec scrollBox.cursor
  scrollBox.adjustScroll()
  if not shift:
    scrollBox.selector = scrollBox.cursor
  scrollBox.savedX = scrollBox.cursorPos.x

proc rightWord*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor right by a word (Usually ctr + right).
  if scrollBox.cursor < scrollBox.runes.len:
    inc scrollBox.cursor
  while scrollBox.cursor < scrollBox.runes.len and
    not scrollBox.runes[scrollBox.cursor].isWhiteSpace():
    inc scrollBox.cursor
  scrollBox.adjustScroll()
  if not shift:
    scrollBox.selector = scrollBox.cursor
  scrollBox.savedX = scrollBox.cursorPos.x

proc startOfLine*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor left by a word.
  while scrollBox.cursor > 0 and
    scrollBox.runes[scrollBox.cursor - 1] != Rune(10):
    dec scrollBox.cursor
  scrollBox.adjustScroll()
  if not shift:
    scrollBox.selector = scrollBox.cursor
  scrollBox.savedX = scrollBox.cursorPos.x

proc endOfLine*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor right by a word.
  while scrollBox.cursor < scrollBox.runes.len and
    scrollBox.runes[scrollBox.cursor] != Rune(10):
    inc scrollBox.cursor
  scrollBox.adjustScroll()
  if not shift:
    scrollBox.selector = scrollBox.cursor
  scrollBox.savedX = scrollBox.cursorPos.x

proc pageUp*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor up by half a text box height.
  if scrollBox.layout.len == 0:
    return
  let
    pos = vec2(scrollBox.savedX, scrollBox.cursorPos.y - float(scrollBox.height) * 0.5)
    g = scrollBox.layout.pickGlyphAt(pos)
  if g.character != "":
    scrollBox.cursor = g.count
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
  elif pos.y <= scrollBox.layout[0].selectRect.y:
    # Above the first line? Then jump to start location 0.
    scrollBox.cursor = 0
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor

proc pageDown*(scrollBox: ScrollBox, shift = false) =
  ## Move cursor down up by half a text box height.
  if scrollBox.layout.len == 0:
    return
  let
    pos = vec2(scrollBox.savedX, scrollBox.cursorPos.y + float(scrollBox.height) * 0.5)
    g = scrollBox.layout.pickGlyphAt(pos)
  if g.character != "":
    scrollBox.cursor = g.count
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor
  elif pos.y > scrollBox.layout[^1].selectRect.y:
    # Bellow the last line? Then jump to start location last.
    scrollBox.cursor = scrollBox.runes.len
    scrollBox.adjustScroll()
    if not shift:
      scrollBox.selector = scrollBox.cursor

proc mouseAction*(
  scrollBox: ScrollBox,
  mousePos: Vec2,
  click = true,
  shift = false
) =
  ## Click on this with a mouse.
  scrollBox.wasScrolled = false
  scrollBox.mousePos = mousePos + scrollBox.scroll
  # Pick where to place the cursor.
  let pos = scrollBox.layout.pickGlyphAt(scrollBox.mousePos)
  if pos.character != "":
    scrollBox.cursor = pos.count
    scrollBox.savedX = scrollBox.mousePos.x
    if pos.character != "\n":
      # Select to the right or left of the character based on what is closer.
      let pickOffset = scrollBox.mousePos - pos.selectRect.xy
      if pickOffset.x > pos.selectRect.w / 2 and
          scrollBox.cursor == scrollBox.runes.len - 1:
        inc scrollBox.cursor
  else:
    # If above the text select first character.
    if scrollBox.mousePos.y < 0:
      scrollBox.cursor = 0
    # If below text select last character + 1.
    if scrollBox.mousePos.y > float scrollBox.innerHeight:
      scrollBox.cursor = scrollBox.glyphs.len
  scrollBox.savedX = scrollBox.mousePos.x
  scrollBox.adjustScroll()

  if not shift and click:
    scrollBox.selector = scrollBox.cursor

proc selectWord*(scrollBox: ScrollBox, mousePos: Vec2, extraSpace = true) =
  ## Select word under the cursor (double click).
  scrollBox.mouseAction(mousePos, click = true)
  while scrollBox.cursor > 0 and
    not scrollBox.runes[scrollBox.cursor - 1].isWhiteSpace():
    dec scrollBox.cursor
  while scrollBox.selector < scrollBox.runes.len and
    not scrollBox.runes[scrollBox.selector].isWhiteSpace():
    inc scrollBox.selector
  if extraSpace:
    # Select extra space to the right if its there.
    if scrollBox.selector < scrollBox.runes.len and
      scrollBox.runes[scrollBox.selector] == Rune(32):
      inc scrollBox.selector

proc selectParagraph*(scrollBox: ScrollBox, mousePos: Vec2) =
  ## Select paragraph under the cursor (triple click).
  scrollBox.mouseAction(mousePos, click = true)
  while scrollBox.cursor > 0 and
    scrollBox.runes[scrollBox.cursor - 1] != Rune(10):
    dec scrollBox.cursor
  while scrollBox.selector < scrollBox.runes.len and
    scrollBox.runes[scrollBox.selector] != Rune(10):
    inc scrollBox.selector

proc selectAll*(scrollBox: ScrollBox) =
  ## Select all text (quad click).
  scrollBox.cursor = 0
  scrollBox.selector = scrollBox.runes.len

proc resize*(scrollBox: ScrollBox, size: Vec2) =
  ## Resize text box.
  scrollBox.width = int size.x
  scrollBox.height = int size.y
  scrollBox.glyphs.setLen(0)
  scrollBox.adjustScroll()

proc scrollBy*(scrollBox: ScrollBox, amount: float) =
  ## Scroll text box with a scroll wheel.
  scrollBox.wasScrolled = true
  scrollBox.scroll.y += amount
  # Make sure it does not scroll off the top.
  scrollBox.scroll.y = max(0, scrollBox.scroll.y)
  # Or the bottom.
  scrollBox.scroll.y = min(
    float(scrollBox.innerHeight - scrollBox.height),
    scrollBox.scroll.y
  )
  # Check if there is not enough text to scroll.
  if scrollBox.innerHeight < scrollBox.height:
    scrollBox.scroll.y = 0
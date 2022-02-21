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

proc setCursor*(scrollBox: ScrollBox, loc: int) =
  scrollBox.cursor = clamp(loc, 0, scrollBox.runes.len + 1)
  scrollBox.selector = scrollBox.cursor


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
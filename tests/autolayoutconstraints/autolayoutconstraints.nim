import fidget, random, bumpy

setTitle("Auto Layout Vertical")

var heights: seq[int]
for i in 0 ..< 7:
  heights.add(27)

var
  first = true
  obox: Rect

template autoOrg*() =
  if first:
    obox = current.box
    first = false
  orgBox obox

proc drawMain() =
  frame "autoLayout":
    # orgBox 0, 0, 400, 400
    boxOf parent
    fill "#ffffff"

    frame "autoFrame":
      box 100, 75, parent.box.w - 300, parent.box.h - 200
      autoOrg
      layout lmVertical
      counterAxisSizingMode csAuto
      constraints cMin, cStretch
      itemSpacing 15

      rectangle "area1":
        box 0, 0, 200, 27
        constraints cScale, cMin
        fill "#90caff"
      rectangle "area2":
        box 0, 0, 200, 27
        constraints cScale, cScale
        fill "#379fff"
      rectangle "area3":
        box 0, 0, 200, 27
        constraints cScale, cScale
        fill "#007ff4"
      rectangle "area4":
        box 0, 0, 200, 27
        constraints cScale, cScale
        fill "#0074df"
      rectangle "area5":
        box 0, 0, 200, 27
        constraints cScale, cScale
        fill "#0062bd"
      rectangle "area6":
        box 0, 0, 200, 27
        constraints cScale, cMin
        fill "#005fb7"

  # for i in 0 ..< 7:
    # heights[i] = max(heights[i] + rand(-1 .. 2), 10)

startFidget(drawMain, w = 800, h = 640, uiScale=1.5)

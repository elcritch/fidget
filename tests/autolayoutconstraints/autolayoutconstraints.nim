import fidget_dev, random

setTitle("Auto Layout Vertical")

var heights: seq[int]
for i in 0 ..< 7:
  heights.add(27)

var
  first = true
  obox: Rect

proc drawMain() =
  frame "autoLayout":
    fill "#ffffff"
    box 10, 10, 100'vw, 100'vh

    frame "autoFrame":
      box 100, 75, parent.box.w - 100'ui, parent.box.h - 100'ui
      # autoOrg()
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

startFidget(drawMain, w = 400, h = 400, uiScale=1.0)

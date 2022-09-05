import fidget_dev, random

setTitle("Auto Layout Vertical")

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    box 0, 0, 100'vw, 100'vh
    fill "#cccccc"

    frame "autoLayout":
      box 0, 0, 80'pw, 80'ph
      centeredX 80'pw
      centeredY 80'ph
      clipContent true

      fill "#ffffff"

      frame "autoFrame":
        box 0, 0, 100'pw, 100'ph

        scrollBars true
        layout lmVertical
        counterAxisSizingMode csAuto

        itemSpacing 10

        rectangle "area1":
          box 0, 0, 100'pw, 70'vh
          fill "#90caff"

          layout lmGrid
          gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]
          gridTemplateRows ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]

          rectangle "area2":
            box 0, 0, 100'pw, 70'vh
            fill "#379fff"

          rectangle "area3":
            box 0, 0, 100'pw, 70'vh
            fill "#007ff4"
          rectangle "area4":
            box 0, 0, 100'pw, 70'vh
            fill "#0074df"
          rectangle "area5":
            box 0, 0, 100'pw, 70'vh
            fill "#0062bd"
          rectangle "area6":
            box 0, 0, 100'pw, 70'vh
            fill "#005fb7"
          rectangle "area7":
            box 0, 0, 100'pw, 70'vh
            fill "#00407b"

startFidget(drawMain, w = 400, h = 400, uiScale = 2.0)

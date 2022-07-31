import fidget, random

setTitle("Auto Layout Vertical")

import print

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    box 0, 0, 100'vw, 100'vh
    fill "#cccccc"

    frame "autoFrame":
      box 0, 0, 80'pw, 80'ph
      centeredX 80'pw
      centeredY 80'ph
      fill "#FFFFFF"

      # if not current.gridTemplate.isNil:
      #   for col in current.gridTemplate.columns:
      #     rectangle "column":
      #       fill "#cccccc"
      #       box col.start, 0, 0.2'em, 100'ph

      layout lmGrid
      gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto ["col4-start"] 50'ui ["five"] 40'ui ["end"]
      gridTemplateRows ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto ["last-line"]

      rectangle "area2":
        fill "#379fff"
        cornerRadius 0.3'em
        columnStart 2.mkIndex
        columnEnd "five".mkIndex
        rowStart "row1-start".mkIndex
        rowEnd 3.mkIndex

      rectangle "area3":
        fill "#379fff"
        box 0, 0, 1'em, 1'em

      rectangle "area2":
        fill "#379fff"
        cornerRadius 0.3'em

        columnStart 1.mkIndex
        columnEnd 2.mkIndex
        rowStart 3.mkIndex
        rowEnd "last-line".mkIndex

      

      

startFidget(drawMain, w = 400, h = 400, uiScale = 2.0)

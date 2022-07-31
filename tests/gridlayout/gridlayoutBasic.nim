import fidget, random

setTitle("Auto Layout Vertical")

import print

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    box 0, 0, 100'vw, 100'vh
    fill rgb(224, 239, 255).to(Color)

    frame "autoFrame":
      box 0, 0, 80'pw, 80'ph
      centeredX 80'pw
      centeredY 80'ph
      fill "#FFFFFF"
      cornerRadius 0.5'em
      clipContent true
      # strokeLine 0.1'em.float32, "#444444" # wow this is slow!!

      layout lmGrid
      gridTemplateColumns ["first"] 40'ui ["second", "line2"] 50'ui ["line3"] auto \
                              ["col4-start"] 50'ui ["five"] 40'ui ["end"]
      gridTemplateRows ["row1-start"] 25'perc ["row1-end"] 100'ui ["third-line"] auto \ 
                              ["last-line"]

      rectangle "area2":
        # fill rgb(248, 152, 87).to(Color)
        fill rgba(245, 129, 49, 123).to(Color)
        cornerRadius 0.5'em
        columnStart 2.mkIndex
        columnEnd "five".mkIndex
        rowStart "row1-start".mkIndex
        rowEnd 3.mkIndex
        rectangle "area2":
          box 0.5'em, 0.5'em, 100'pw - 0.5'em, 100'ph - 0.5'em 
          cornerRadius 0.5'em
          # fill rgb(245, 129, 49).to(Color)
          fill rgba(245, 129, 49, 80).to(Color)

      for col in current.gridTemplate.columns[1..^1]:
        rectangle "column":
          fill "#222222"
          box col.start, 0, 0.1'em, 100'ph
      for row in current.gridTemplate.rows[1..^1]:
        rectangle "row":
          fill "#222222"
          box 0, row.start, 100'pw, 0.1'em


      

      

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

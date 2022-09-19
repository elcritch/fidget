import fidget_dev, random

setTitle("Auto Layout Vertical")

import print
const hasGaps = false

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    box 0, 0, 100'vw, 100'vh
    fill rgb(224, 239, 255).to(Color)

    frame "css grid area":
      # setup frame for css grid
      box 0, 0, 80'pw, 80'ph
      centeredX 80'pw
      centeredY 80'ph
      fill "#FFFFFF"
      cornerRadius 0.5'em
      # clipContent true
      if hasGaps:
        columnGap 1'em
        rowGap 1'em
      
      # Setup CSS Grid Template
      gridTemplateColumns ["first"] 40'ux \
                            ["line2"] 50'ux \
                            ["line3"] auto \
                            ["col4-start"] 50'ux \
                            ["five"] 40'ux \
                            ["end"]

      gridTemplateRows ["row1-start"] 25'pp \
                        ["row1-end"] 100'ux \
                        ["third-line"] auto \ 
                        ["last-line"]

      rectangle "css grid item":
        # Setup CSS Grid Template
        cornerRadius 1'em
        columnStart 2
        columnEnd "five"
        rowStart "row1-start"
        rowEnd 3
        # some color stuff
        fill rgba(245, 129, 49, 123).to(Color)
        # rectangle "area2":
        #   box 0.5'em, 0.5'em, 100'pw - 0.5'em, 100'ph - 0.5'em 
        #   fill rgba(245, 129, 49, 80).to(Color)

      # draw debug lines
      gridTemplateDebugLines true
      

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

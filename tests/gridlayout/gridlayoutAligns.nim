import fidget_dev, random
import fidget_dev/grids

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
      centeredXY 80'pw, 80'ph
      fill "#FFFFFF"
      cornerRadius 0.5'em
      clipContent true

      if hasGaps:
        columnGap 1'em
        rowGap 1'em
      
      # Setup CSS Grid Template
      justifyItems gcStretch
      alignItems gcEnd
      gridTemplateColumns ["first"] 3'fr \
                            ["middle"] 2'fr \
                            ["last"] 3'fr \
                            ["end"]

      gridTemplateRows ["first"] 3'fr \
                            ["middle"] 2'fr \
                            ["last"] 3'fr \
                            ["end"]
      
      for i in 1..3:
        for j in 1..3:
          rectangle &"css grid item {i}{j}":
            # Setup CSS Grid Template
            size 5'em, 2'em
            cornerRadius 1'em
            gridColumn i, i+1
            gridRow j, j+1
            # some color stuff
            fill rgba(245, 129, 49, 123).to(Color)
            onOverlapped:
              fill rgba(245, 129, 49, 40).to(Color)
            rectangle &"subarea2 {i}{j}":
              box 0.5'em, 0.5'em, 100'pw - 0.5'em, 100'ph - 0.5'em 
              fill rgba(245, 129, 49, 80).to(Color)
              onHover:
                fill rgba(245, 129, 49, 40).to(Color)

      # draw debug lines
      gridTemplateDebugLines true
      

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

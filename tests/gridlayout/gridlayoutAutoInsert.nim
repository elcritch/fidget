import fidget, random
import fidget/grids

setTitle("Auto Layout Vertical")

import print
const hasGaps = false

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    box 0, 0, 100'vw, 100'vh
    fill rgb(224, 239, 255).to(Color)

    frame "css grid area":
      if current.gridTemplate != nil:
        echo "grid template: ", repr current.gridTemplate
      # setup frame for css grid
      box 0, 0, 80'pw, 80'ph
      centeredX 80'pw
      centeredY 80'ph
      fill "#FFFFFF"
      cornerRadius 0.5'em
      clipContent true
      
      # Setup CSS Grid Template
      gridTemplateColumns 60'ui 60'ui
      gridTemplateRows 90'ui 90'ui

      rectangle "item a":
        # Setup CSS Grid Template
        cornerRadius 1'em
        gridColumn 1 // 2
        gridRow 2 // 3
        # some color stuff
        fill rgba(245, 129, 49, 123).to(Color)

      rectangle "item b":
        # Setup CSS Grid Template
        cornerRadius 1'em
        gridColumn 5 // 6
        gridRow 2 // 3
        # some color stuff
        fill rgba(245, 129, 49, 123).to(Color)

      # draw debug lines
      gridTemplateDebugLines true
      

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

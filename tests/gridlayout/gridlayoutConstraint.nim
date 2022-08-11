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
      gridTemplateColumns ["left"] 20'ui \
                          ["middle-left"] 1'fr \
                          ["center-left"] 40'ui \
                          ["center-right"] 1'fr \
                          ["middle-right"] 20'ui \
                          ["right"]

      gridTemplateRows ["top"] 20'ui \
                       ["middle-top"] 1'fr \
                       ["center-top"] 40'ui \
                       ["center-bottom"] 1'fr \
                       ["middle-bottom"] 20'ui \
                       ["bottom"]

      rectangle "Center":
        # box 150, 150, 100, 100
        gridColumn "center-left", "center-right"
        gridRow "center-top", "center-bottom"
        constraints cCenter, cCenter
        fill "#FFFFFF", 0.50
      rectangle "Scale":
        # box 100, 100, 200, 200
        gridColumn "center-left", "center-right"
        gridRow "center-top", "center-bottom"
        constraints cScale, cScale
        fill "#FFFFFF", 0.25
      rectangle "LRTB":
        box 40, 40, 320, 320
        constraints cStretch, cStretch
        fill "#70BDCF"

      rectangle "TR":
        box 360, 20, 20, 20
        constraints cMax, cMin
        fill "#70BDCF"
      rectangle "TL":
        box 20, 20, 20, 20
        constraints cMin, cMin
        fill "#70BDCF"
      rectangle "BR":
        box 360, 360, 20, 20
        constraints cMax, cMax
        fill "#70BDCF"
      rectangle "BL":
        box 20, 360, 20, 20
        constraints cMin, cMax
        fill "#70BDCF"


        # draw debug lines
        gridTemplateDebugLines true
        

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

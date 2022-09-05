import fidget_dev, random
import fidget_dev/grids

setTitle("Auto Layout Vertical")

import print
const hasGaps = false

proc drawMain() =
  frame "autoLayout":
    font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
    # setup frame for css grid
    box 10'pw, 10'ph, 80'pw, 80'ph
    fill "#FFFFFF"
    cornerRadius 0.5'em
    clipContent true
    if hasGaps:
      columnGap 1'em
      rowGap 1'em
    
    # Setup columns using inline syntax
    gridTemplateColumns ["left"] 30'ui ["outer-left"] 2'fr ["middle-left"] 3'fr ["center-left"] 100'ui \
                        ["center-right"] 3'fr ["middle-right"] 2'fr ["outer-right"] 30'ui ["right"]

    # Setup rows using a command-style syntax (one per row)
    gridTemplateRows:
      ["top"] 30'ui
      ["outer-top"] 2'fr
      ["middle-top"] 3'fr
      ["center-top"] 100'ui
      ["center-bottom"] 3'fr
      ["middle-bottom"] 2'fr
      ["outer-bottom"] 30'ui
      ["bottom"]

    rectangle "TR":
      gridColumn "right" // "outer-right"
      gridRow "top" // "outer-top"
      fill "#70BDCF"
    rectangle "TL":
      gridColumn "left" // "outer-left"
      gridRow "top" // "outer-top"
      fill "#70BDCF"
    rectangle "BR":
      gridColumn "right" // "outer-right"
      gridRow "bottom" // "outer-bottom"
      fill "#70BDCF"
    rectangle "BL":
      gridColumn "left" // "outer-left"
      gridRow "bottom" // "outer-bottom"
      fill "#70BDCF"

    rectangle "Center":
      # box 150, 150, 100, 100
      gridColumn "center-left" // "center-right"
      gridRow "center-top" // "center-bottom"
      fill "#FFFFFF", 0.50
    rectangle "Scale":
      # box 100, 100, 200, 200
      gridColumn "middle-left" // "middle-right"
      gridRow "middle-top" // "middle-bottom"
      fill "#FFFFFF", 0.25
    rectangle "LRTB":
      gridColumn "outer-left" // "outer-right"
      gridRow "outer-top" // "outer-bottom"
      fill "#70BDCF"


    # draw debug lines
    # gridTemplateDebugLines true
      

startFidget(drawMain, w = 600, h = 400, uiScale = 2.0)

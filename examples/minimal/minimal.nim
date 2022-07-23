## This minimal example shows 5 blue squares.

import fidget

proc drawMain() =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      group "block":
        box 20 + i * 120, 20, 100, 100
        fill "#2B9FEA"
        cornerRadius 10

startFidget(drawMain, w = 620, h = 140, uiScale=2.0)

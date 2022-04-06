import bumpy, fidget
import std/strformat

import fidgets

export fidget, fidgets

type
  UnitRange* = range[0.0'f32..1.0'f32]

proc progressBar*(value: var UnitRange) {.basicFidget.} =
  ## Draw a progress bars 

  init:
    ## called before `setup` and used for setting defaults like
    ## the default box size
    box 0, 0, 100.WPerc, 2.Em

  let
    # some basic calcs
    bw = current.box().w
    bh = current.box().h
    sw = 2.0'f32
    sb = 4.0'f32
    barW = bw * float(value) - sb*sw + 0.001
    barH = bh - sb*sw

  group "progress":
    text "text":
      box 0, 0, bw, bh
      fill "#565555"
      characters fmt"progress: {float(value):4.2f}"

  rectangle "barFg":
    box sb, sb, barW, barH
    cornerRadius 2.2
    clipContent true
    rectangle "barFg":
      cornerRadius 2.2
      box 0, 0, 100'pw, 100'ph
      image "shadow-button-middle.png"
      current.imageColor = color(1,1,1,0.27)
    strokeLine 1.0, "#707070", 0.57

  rectangle "barFg":
    box sb, sb, barW, barH
    fill "#87E3FF"
    cornerRadius 2.2

  # Draw the bar itself.
  group "bar":
    box 0, 0, bw, bh
    fill "#BDBDBD"
    strokeLine sw, "#707070", 1.0
    cornerRadius 3
    clipContent true

  cornerRadius 3
  dropShadow 4, 0, 0, "#000000", 0.05
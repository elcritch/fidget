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
    barW = bw
    sw = 2.0'f32
    sb = 4.0'f32

  group "progress":
    text "text":
      box 0, 0, bw, bh
      fill "#565555"
      characters fmt"progress: {float(value):4.2f}"

  # Draw the bar itself.
  group "bar":
    box 0, 0, barW, bh
    dropShadow 3, 0, 0, "#000000", 0.03
    fill "#BDBDBD"
    strokeLine sw, "#707070", 2.0
    cornerRadius 5
    rectangle "barFg":
      box sb, sb, barW * float(value) - sb*sw + 0.001, bh - sb*sw
      fill "#87E3FF"
      cornerRadius 5
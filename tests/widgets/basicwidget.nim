
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

type
  UnitRange* = range[0.0'f32..1.0'f32]

proc progressBar*(value: var UnitRange) {.basicWidget.} =
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

  group "progress":
    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters fmt"progress: {float(value):4.2f}"

  # Draw the bar itself.
  group "bar":
    box 0, 0, barW, bh
    dropShadow 3, 0, 0, "#000000", 0.03
    fill "#F7F7F9"
    stroke "#46D15F", 1.0
    strokeWeight sw
    cornerRadius 5
    rectangle "barFg":
      box 2, 2, barW * float(value) - 2*sw + 0.001, bh - 2*sw
      fill "#46D15F"
      cornerRadius 5

proc button*(
    message {.property: text.}: string,
    clicker {.property: onClick.}: WidgetProc = proc () = discard
): bool {.basicWidget, discardable.} =
  # Draw a progress bars 
  init:
    box 0, 0, 8.Em, 2.Em

  let
    bw = current.box().w
    bh = current.box().h

  cornerRadius 5
  rectangle "button":
    box 0, 0, bw, bh
    dropShadow 3, 0, 0, "#000000", 0.03
    cornerRadius parent.cornerRadius
    fill "#72bdd0"
    stroke "#72bdd0", 1.0
    strokeWeight 2
    onHover: 
      fill "#5C8F9C"
    onClick:
      clicker()
      result = true

    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters message

proc exampleApp*() {.statefulWidget.} =
  properties:
    count: int
    value: UnitRange

  frame "main":
    setTitle("Fidget Animated Progress Example")
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
    fill "#F7F7F9"

    group "center":
      box 50, 0, 100.Vw - 100, 100.Vh
      orgBox 50, 0, 100.Vw, 100.Vw
      fill "#DFDFE0"
      strokeWeight 1

      self.value = (self.count.toFloat * 0.10) mod 1.0
      progressBar(self.value) do:
        box 10.WPerc, 20, 80.WPerc, 2.Em

      Horizontal:
        box 90.WPerc - 16.Em, 100, 8.Em, 2.Em
        itemSpacing 0.Em

        # Click to make the bar increase
        # basic syntax just calling a proc
        if button(fmt"Clicked1: {self.count:4d}"):
          self.count.inc()

        # Alternate format using `Widget` macro that enables
        # a YAML like syntax using property labels
        # (see parameters on `button` widget proc)
        Widget button:
          text: fmt"Clicked2: {self.count:4d}"
          onClick: self.count.inc()

      Vertical:
        box 10.WPerc, 160, 8.Em, 2.Em
        itemSpacing 1.Em

        # basic syntax just calling a proc
        Button:
          text: fmt"Clicked3: {self.count:4d}"
          setup: size 8.Em, 2.Em
          onClick: self.count.inc()

        Widget button:
          text: fmt"Clicked4: {self.count:4d}"
          setup: size 8.Em, 2.Em
          onClick: self.count.inc()

var state = ExampleApp(count: 0, value: 0.33)

proc drawMain() =
  frame "main":
    exampleApp(state)

startFidget(drawMain, uiScale=2.0)

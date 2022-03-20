
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

type
  Unit* = range[0.0'f32..1.0'f32]

proc progressBar*(value: var Unit) {.widget.} =

  # Draw a progress bars 
  init:
    box 0, 0, parent.box().w, 1.Em

  let
    bw = current.box().w
    bh = 2.Em
    barW = bw - 1.Em

  group "progress":
    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters fmt"progress: {float(value):4.2f}"

    value = value.clamp(0.001, 1.0)

    # Draw the bar itself.
    group "bar":
      box 0, 0, barW, bh
      fill "#F7F7F9"
      cornerRadius 5
      rectangle "barFg":
        box 0, 0, barW * float(value), bh
        fill "#46D15F"
        cornerRadius 5

proc button*(msg: string, clicker: proc()) {.widget.} =

  # Draw a progress bars 
  init:
    box 0, 0, parent.box().w, 1.Em

  cornerRadius 3

  let
    bw = 8.Em
    bh = 2.Em

  rectangle "button":
    box 0, 0, bw, bh
    cornerRadius parent.cornerRadius
    fill "#AEB5C0"
    onHover:
      fill "#46DE5F"
    onClick:
      clicker()

    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters msg


AppWidget(exampleApp):

  properties:
    count: int
    value: Unit

  init:
    count = 1
    value = Unit(0.33)

  frame "main":
    box 0, 0, root.box().w, root.box().h

    # Set the window title.
    setTitle("Fidget Animated Progress Example")
    fill "#F7F7F9"
    # Use simple math to layout things.
    let barH = root.box().h
    let barW = root.box().w - 100

    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

    group "center":
      box 50, 0, barW, barH
      orgBox 50, 0, barW, barH
      fill "#DFDFE0"
      strokeWeight 1

      progressBar(self.value) do:
        box 20, 20, barW - 30, 1.Em

      # Draw the decrement button to make the bar go down.
      button(fmt"Clicked: {self.count:4d}"):
        self.count.inc()
        self.value = (self.value + 0.07) mod 1.0
      do:
        box root.box().w-16.Em, 100, 8.Em, 2.Em


var state = ExampleApp(count: 1, value: 0.33)

proc drawMain() =
  widget(state)

startFidget(drawMain, uiScale=2.0)

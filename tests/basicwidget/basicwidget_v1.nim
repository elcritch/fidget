
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
  Init:
    box 0, 0, parent.box().w, 1.Em

  let
    bw = current.box().w
    bh = 2.Em
    barW = bw

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

proc button*(
    message {.property: text.}: string,
    clicker {.property: onClick.}: WidgetProc
) {.widget.} =
  # Draw a progress bars 
  Init:
    box 0, 0, parent.box().w, 1.Em
  let
    bw = 8.Em
    bh = 2.Em
  cornerRadius 3
  rectangle "button":
    box 0, 0, bw, bh
    cornerRadius parent.cornerRadius
    fill "#AEB5C0"
    onHover: fill "#46DE5F"
    onClick: clicker()

    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters message

AppWidget(ExampleApp):
  Properties:
    count: int
    value: Unit
  Init:
    count = 1
    value = Unit(0.33)

  frame "main":
    setTitle("Fidget Animated Progress Example")
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
    fill "#F7F7F9"

    group "center":
      box 50, 0, 100.Vw - 100, 100.Vh
      orgBox 50, 0, 100.Vw, 100.Vw
      fill "#DFDFE0"
      strokeWeight 1

      progressBar(self.value) do:
        box 10.WPerc, 20, 80.WPerc, 1.Em

      # Draw the decrement button to make the bar go down.
      button(fmt"Clicked: {self.count:4d}"):
        self.count.inc()
        self.value = (self.value + 0.07) mod 1.0
      do:
        box 90.WPerc - 8.Em, 100, 8.Em, 2.Em

      with button:
        text: fmt"Clicked2: {self.count:4d}"
        setup: box 90.WPerc - 8.Em, 140, 8.Em, 2.Em
        onClick:
          self.count.inc()
          self.value = (self.value + 0.07) mod 1.0

      Button:
        text: fmt"Clicked3: {self.count:4d}"
        setup: box 90.WPerc - 8.Em, 190, 8.Em, 2.Em
        onClick:
          self.count.inc()
          self.value = (self.value + 0.07) mod 1.0


var state = ExampleApp(count: 1, value: 0.33)

proc drawMain() =
  widget(state)

startFidget(drawMain, uiScale=2.0)

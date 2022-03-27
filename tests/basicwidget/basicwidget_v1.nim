
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

    # Draw the bar itself.
    group "bar":
      box 0, 0, barW, bh
      dropShadow 4, 0, 0, "#000000", 0.03
      fill "#F7F7F9"
      stroke "#46D15F", 1.0
      strokeWeight 5
      cornerRadius 5
      rectangle "barFg":
        box 2, 2, barW * float(value) - 4 + 0.001, bh - 4
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
  cornerRadius 5
  rectangle "button":
    box 0, 0, bw, bh
    dropShadow 4, 0, 0, "#000000", 0.03
    cornerRadius parent.cornerRadius
    fill "#72bdd0"
    stroke "#72bdd0", 1.0
    strokeWeight 5
    onHover: 
      fill "#5C8F9C"
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
    count = 0
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

      self.value = (self.count.toFloat * 0.10) mod 1.0
      progressBar(self.value) do:
        box 10.WPerc, 20, 80.WPerc, 1.Em

      Vertical:
        box 90.WPerc - 8.Em, 160, 8.Em, 2.Em
        itemSpacing 2.Em

        # Draw the decrement button to make the bar go down.
        button(fmt"Clicked1: {self.count:4d}"):
          self.count.inc()

        with button:
          text: fmt"Clicked2: {self.count:4d}"
          onClick: self.count.inc()

      Horizontal:
        box 10.WPerc, 100, 8.Em, 2.Em
        itemSpacing 1.Em

        Button:
          text: fmt"Clicked4: {self.count:4d}"
          setup: size 8.Em, 2.Em
          onClick: self.count.inc()

        with button:
          text: fmt"Clicked3: {self.count:4d}"
          setup: size 8.Em, 2.Em
          onClick: self.count.inc()


var state = ExampleApp(count: 0, value: 0.33)

proc drawMain() =
  widget(state)

startFidget(drawMain, uiScale=2.0)

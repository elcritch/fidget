
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import button
import progressBar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

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
        # creates an horizontal spacing box

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
        # creates a vertical spacing box

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

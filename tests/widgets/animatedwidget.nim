
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import button
import progressBar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc exampleApp*(
    myName {.property: name.}: string,
) {.appWidget.} =
  ## defines a stateful app widget
  
  properties:
    count: int
    value: UnitRange

  frame "main":
    setTitle(fmt"Fidget Animated Progress Example - {myName}")
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

      # Alternate format using `Widget` macro that enables
      # a YAML like syntax using property labels
      # (see parameters on `button` widget proc)
      Widget button:
        text: fmt"Clicked2: {self.count:4d}"
        onClick: self.count.inc()


var state = ExampleApp(count: 0, value: 0.33)

proc drawMain() =
  frame "main":
    exampleApp("basic widgets", state)


startFidget(drawMain, uiScale=2.0)

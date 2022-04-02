
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import button
import progressBar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc animatedDropdown*(
    delta: float32,
) {.statefulFidget.} =

  init:
    ## called before `setup` and used for setting defaults like
    ## the default box size
    box 0, 0, 100.WPerc, 2.Em

  proc ticker() {.async.} =
    ## This simple procedure will "tick" ten times delayed 1,000ms each.
    ## Every tick will increment the progress bar 10% until its done. 
    let
      n = 70
      duration = 600
      curr = self.value
    for i in 1..n:
      await sleepAsync(duration / n)
      self.value += tickChange
      refresh()

  properties:
    value: UnitRange
    ticks: Future[void] = emptyFuture() ## Create an completed "empty" future


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

      Widget progressBar:
        value: self.value
        setup: box 10.WPerc, 20, 80.WPerc, 2.Em

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

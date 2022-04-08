
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import button
import progressBar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc animatedProgress*(
    delta: float32 = 0.1,
) {.statefulFidget.} =

  init:
    ## called before `setup` and used for setting defaults like
    ## the default box size
    box 0, 0, 100.WPerc, 2.Em

  properties:
    value: UnitRange
    ticks: Future[void] = emptyFuture() ## Create an completed "empty" future

  proc ticker(self: AnimatedProgress, target: float32) {.async.} =
    ## This simple procedure will "tick" ten times delayed 1,000ms each.
    ## Every tick will increment the progress bar 10% until its done. 
    let
      n = 70
      duration = 600
      curr = self.value
    for i in 1..n:
      await sleepAsync(duration / n)
      self.value += delta
      refresh()

  triggers:
    gotoValue(target: float32):
      if self.ticks.finished():
        echo "setup new ticker"
        self.ticks = ticker(target)
      else:
        echo "ticker already running!"

template gotoTrigger(name: untyped) =
  echo "injecting goto"
  var `name` {.inject.} = gotoValue

type Trigger = distinct string

template trigger*(x: untyped): Trigger = 
  Trigger(x)

template `<-`*(x: Trigger, blk: untyped) = 
  discard

proc exampleApp*(
    myName {.property: name.}: string,
) {.appFidget.} =
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

      # Alternate format using `Widget` macro that enables
      # a YAML like syntax using property labels
      # (see parameters on `button` widget proc)
      Widget button:
        text: fmt"Clicked2: {self.count:4d}"
        onClick:
          self.count.inc()
          trigger("pb1") <- gotoValue(self.count*0.1)

      Widget animatedProgress:
        id: "pb1"
        delta: 0.1'f32
        setup: box 10.WPerc, 20, 80.WPerc, 2.Em


var state = ExampleApp(count: 0, value: 0.33)

proc drawMain() =
  frame "main":
    exampleApp("basic widgets", state)


startFidget(drawMain, uiScale=2.0)

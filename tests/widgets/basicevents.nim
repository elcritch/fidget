
import bumpy, fidget, math, random
import std/strformat, std/hashes
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output
import tables
import variant
import patty

import button
import progressbar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

var
  frameCount = 0

# type
  # JumpToValue = object
    # target: float

# variant AnimatedProgressEvents:
  # IncrementBar(increment: float)
  # JumpToValue(target: float)

proc animatedProgress*(
    delta: float32 = 0.1,
  ): AnimatedProgress {.statefulFidget.} =

  init:
    box 0, 0, 100.WPerc, 2.Em

  properties:
    value: float
    ticks: Future[void] = emptyFuture() ## Create an completed "empty" future
  
  events(AnimatedEvents):
    IncrementBar(increment: float)
    JumpToValue(target: float)

  onEvents(evt: AnimatedEvents):
    IncrementBar(increment):
      echo "pbar event: ", evt.repr()
      self.value = self.value + increment
      refresh()
    JumpToValue(target):
      echo "jump where? ", $target

  render:
    self.value = self.value + delta

    group "anim":
      boxOf parent
      font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
      progressbar(self.value) do:
        boxOf parent

proc exampleApp*(
    myName {.property: name.}: string,
) {.appFidget.} =
  ## defines a stateful app widget
  
  properties:
    count1: int
    count2: int
    value: UnitRange

  render:
    if current.hookEvents.isNil:
      current.hookEvents = newTable[string, Variant]()
    let currEvents = current.hookEvents

    frame "main":
      setTitle(fmt"Fidget Animated Progress Example")
      font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
      fill "#F7F7F9"
      # echo fmt"main-main: {current.box()=}"

      group "center":
        box 50, 0, 100.Vw - 100, 100.Vh
        orgBox 50, 0, 100.Vw, 100.Vw
        fill "#DFDFE0"
        strokeWeight 1

        self.value = (self.count1.toFloat * 0.10) mod 1.0
        var delta = 0.0

        Vertical:
          # Trigger an animation on animatedProgress below
          Widget button:
            text: fmt"Arg Incr {self.count1:4d}"
            onClick:
              self.count1.inc()
              delta = 0.02

          Widget button:
            text: fmt"Animate {self.count2:4d}"
            onClick:
              self.count2.inc()
              currEvents["pbc1"] = newVariant(IncrementBar(increment = 0.02))
        
          let ap1 = Widget animatedProgress:
            delta: delta
            setup:
              box 0'em, 0'em, 14'em, 2.Em
              current.code = "pbc1"
              current.hookEvents = currEvents
          echo "AP1: ", repr(ap1)
          
          Widget button:
            text: fmt"Animate2 {self.count2:4d}"
            onClick:
              self.count2.inc()
              currEvents["pbc1"] = newVariant(IncrementBar(increment = 0.02))
        


var state = ExampleApp(count1: 0, count2: 0, value: 0.33)

proc drawMain() =
  # frameCount.inc
  # echo "\n" & fmt"drawMain: {frameCount=} "
  frame "main":
    exampleApp("basic widgets", state)


startFidget(drawMain, uiScale=2.0)


import bumpy, fidget, math, random
import std/strformat, std/hashes
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output
import tables
import variant

import button
import progressbar

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

var
  events*: TableRef[string, Variant] = newTable[string, Variant]()

type
  TickerGotoValue = object
    target: float

proc animatedProgress*(
    delta: float32 = 0.1,
) {.statefulFidget.} =

  init:
    ## called before `setup` and used for setting defaults like
    ## the default box size
    box 0, 0, 100.WPerc, 2.Em

  properties:
    value: float
    ticks: Future[void] = emptyFuture() ## Create an completed "empty" future

  # box 0, 0, 100.WPerc, 2.Em
  # boxOf parent

  echo "pbar event: check: ", events.len(), " id: ", id()
  for k, v in events.pairs():
    echo "pbar event: check: ", (k, v, ).repr
  
  if events.hasKey(getId()):
    let v = events[getId()]
    variantMatch case v as evt
      of TickerGotoValue:
        echo "pbar event: ", evt.repr()
        self.value = evt.target
      else:
        echo "dont know what v is"


  group "anim":
    boxOf parent
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
    echo fmt"anim-wid: {current.box()=}"

    echo fmt"progressbar-horz: {current.box()=}"
    progressbar(self.value) do:
      boxOf parent
# proc ticker(self: AnimatedProgress, target, delta: float32) {.async.} =
#   ## This simple procedure will "tick" ten times delayed 1,000ms each.
#   ## Every tick will increment the progress bar 10% until its done. 
#   let
#     n = 70
#     duration = 600
#     curr = self.value
#   for i in 1..n:
#     await sleepAsync(duration / n)
#     self.value += delta
#     refresh()


proc exampleApp*(
    myName {.property: name.}: string,
) {.appFidget.} =
  ## defines a stateful app widget
  
  properties:
    count1: int
    count2: int
    value: UnitRange

  frame "main":
    setTitle(fmt"Fidget Animated Progress Example")
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
    fill "#F7F7F9"
    echo fmt"main-main: {current.box()=}"

    group "center":
      box 50, 0, 100.Vw - 100, 100.Vh
      orgBox 50, 0, 100.Vw, 100.Vw
      fill "#DFDFE0"
      strokeWeight 1

      self.value = (self.count1.toFloat * 0.10) mod 1.0

      echo fmt"main-inner: {current.box()=}"

      Horizontal:
        # Trigger an animation on animatedProgress below
        Widget button:
          text: fmt"Normal {self.count1:4d}"
          onClick:
            self.count1.inc()

        Widget button:
          text: fmt"Animate {self.count2:4d}"
          onClick:
            self.count2.inc()
            let evt = TickerGotoValue(target: self.count2.toFloat*0.1)
            events["pbc1"] = newVariant(evt)
            # trigger("pb1") <- gotoValue(self.count*0.1)
      
      let ct = self.count1.toFloat * 0.1
      Widget animatedProgress:
        delta: 0.1'f32
        setup:
          id "pbc1"
          box 2'em, 2'em, 80'pw, 2.Em


var state = ExampleApp(count1: 0, count2: 0, value: 0.33)

proc drawMain() =
  echo "drawMain\n"
  frame "main":
    exampleApp("basic widgets", state)


startFidget(drawMain, uiScale=2.0)

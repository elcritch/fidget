
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc `||`[N: int | float32 | float](a, b: N): N =
  if a == 0: b
  else: a

type
  Percent* = range[0.0'f32..100.0'f32]

proc progressBar*(value: var Percent) {.widget.} =

  properties:
    size: Rect

  let
    bw = self.size.w || parent.box().w
    bh = self.size.h || Em(1.5)
    bx = self.size.x
    by = self.size.y

  # Draw a progress bars 
  box bx, by, bw, bh
  text "text":
    box 0, 0, bw, bh
    fill "#46607e"
    font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
    characters fmt"progress: "

  value = value.clamp(0.001, 1.0)

  # Draw the bar itself.
  group "bar":
    box bx, by, bw, bh
    fill "#F7F7F9"
    cornerRadius 5
    rectangle "barFg":
      box 0, 0, bw * float(value), bh
      fill "#46D15F"
      cornerRadius 5


# Widget(drawWidget):
  
#   type ProgressBar = ref object
#     value: float
#     speed: float
#     ticks: Future[void] # = emptyFuture()

#   proc ticker(bar: ProgressBar) {.async.} =
#     ## This simple procedure will "tick" ten times delayed 1,000ms each.
#     ## Every tick will increment the progress bar 10% until its done. 
#     let n = 130
#     let durs = 2_000
#     for i in 1..n:
#       await sleepAsync(durs / n)
#       bar.value = 1.0/n.toFloat() * i.toFloat()
#       # echo fmt"tick {bar.value}"
#     refresh()

#   let barW = root.box().w - 100

#   group "bar":
#     # Draw a progress bars 
#     box 20, 20 + 60 * 0, root.box().w - 100, 60
#     text "text":
#       box 0, 0, 70, 40
#       fill "#46607e"
#       font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
#       characters fmt"progress: {self.value:5.3f}"

#     rectangle "animate":
#       # add a button to trigger "animation"
#       box barW-80, 0, 40, 40
#       fill "#AEB5C0"
#       cornerRadius 3
#       onClick:
#         if self.ticks.finished():
#           echo "setup new ticker"
#           self.ticks = ticker(self)
#         else:
#           echo "ticker already running!"

#       text "text":
#         box 0, 0, 36, 36
#         fill "#46607e"
#         characters "Run"

#     self.value = self.value.clamp(0.001, 1.0)

#     # Draw the bar itself.
#     group "bar":
#       box 100, 0, barW - 100*2, 40
#       fill "#F7F7F9"
#       cornerRadius 5
#       rectangle "barFg":
#         box 0, 0, (barW - 100*2) * float(self.value), 40
#         fill "#46D15F"
#         cornerRadius 5


# Widget(drawWidget):

#   properties:
#     count: int
#     progress1: ProgressBar

#   constructor:
#     count = 1
#     progress1 = ProgressBar(val: 0.2)

#   body:
#     # Set the window title.
#     setTitle("Fidget Animated Progress Example")
#     # Use simple math to layout things.
#     let barH = 1.0'f32 * 60 + 20
#     let barW = root.box().w - 100

#     frame "main":
#       box 0, 40, root.box().w, root.box().h - 20
#       fill "#F7F7F9"
#       font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

#       group "center":
#         box 50, 0, barW, barH
#         orgBox 50, 0, barW, barH
#         fill "#DFDFE0"
#         strokeWeight 1

#         widget progress1

#         group "counter":
#           box 0, 20 + 60 * 2, barW, 60
#           font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

#           # Draw the decrement button to make the bar go down.
#           rectangle "count":
#             box barW-80-20.Em, 0, 20.Em, 2.Em
#             fill "#AEB5C0"
#             cornerRadius 3
#             onHover:
#               fill "#46DE5F"
#             onClick:
#               count.inc()

#             text "text":
#               box 0, 0, 20.Em, 2.Em
#               fill "#46607e"
#               characters "Clicked: " & $count

# proc drawMain() =
#   drawWidget()

# startFidget(drawMain, uiScale=2.0)

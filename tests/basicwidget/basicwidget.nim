
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")


proc progressBar(): WidgetProcEmpty =

  var
    bar: float = 0.2
    count: int = 0
    ticks: Future[void] = emptyFuture() ## Create an completed "empty" future

  proc impl() {.closure.} = 
    let barW = root.box().w - 100

    proc ticker() {.async.} =
      ## This simple procedure will "tick" ten times delayed 1,000ms each.
      ## Every tick will increment the progress bar 10% until its done. 
      let n = 130
      let durs = 2_000
      for i in 1..n:
        await sleepAsync(durs / n)
        bar = 1.0/n.toFloat() * i.toFloat()
        # echo fmt"tick {bar}"
        refresh()

    group "bar":
      # Draw a progress bars 
      box 20, 20 + 60 * 0, root.box().w - 100, 60
      text "text":
        box 0, 0, 70, 40
        fill "#46607e"
        font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
        characters fmt"progress: {bar:5.3f}"

      rectangle "animate":
        # add a button to trigger "animation"
        box barW-80, 0, 40, 40
        fill "#AEB5C0"
        cornerRadius 3
        onClick:
          if ticks.finished():
            echo "setup new ticker"
            ticks = ticker()
          else:
            echo "ticker already running!"

        text "text":
          box 0, 0, 36, 36
          fill "#46607e"
          characters "Run"

      bar = bar.clamp(0.001, 1.0)

      # Draw the bar itself.
      group "bar":
        box 100, 0, barW - 100*2, 40
        fill "#F7F7F9"
        cornerRadius 5
        rectangle "barFg":
          box 0, 0, (barW - 100*2) * float(bar), 40
          fill "#46D15F"
          cornerRadius 5
  impl

var
  bar1: float = 0.02
  count: int = 0

proc drawMain() =

  # Set the window title.
  setTitle("Fidget Animated Progress Example")
  # Use simple math to layout things.
  let barH = 1.0'f32 * 60 + 20
  let barW = root.box().w - 100

  frame "main":
    box 0, 40, root.box().w, root.box().h - 20
    fill "#F7F7F9"
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

    group "center":
      box 50, 0, barW, barH
      orgBox 50, 0, barW, barH
      fill "#DFDFE0"
      strokeWeight 1

      var progress1 = progressBar()
      progress1()

      group "counter":
        box 0, 20 + 60 * 2, barW, 60
        font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

        # Draw the decrement button to make the bar go down.
        rectangle "count":
          box barW-80-20.Em, 0, 20.Em, 2.Em
          fill "#AEB5C0"
          cornerRadius 3
          onHover:
            fill "#46DE5F"
          onClick:
            count.inc()

          text "text":
            box 0, 0, 20.Em, 2.Em
            fill "#46607e"
            characters "Clicked: " & $count

startFidget(drawMain, uiScale=2.0)

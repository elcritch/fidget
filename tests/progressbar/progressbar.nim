import bumpy, fidget, math, random
import std/strformat

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

# Create an array of 30 bars.
var bar: float = 0.5

proc drawMain() =
  # Set the window title.
  setTitle("Fidget Bars Example")

  # Use simple math to layout things.
  let barH = 1.0'f32 * 60 + 20
  let barW = root.box().w - 100

  group "button":
    box 0, 0, 90, 20
    cornerRadius 5
    fill "#72bdd0"
    onHover:
      fill "#5C8F9C"
    onDown:
      fill "#3E656F"
    onClick:
      echo "dump: "
      dumpTree(root)
    text "text":
      box 0, 0, 90, 20
      fill "#ffffff"
      font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
      characters "dump"

  frame "main":
    box 0, 40, root.box().w, root.box().h - 20
    fill "#F7F7F9"
    # clipContent true

    group "center":
      box 50, 0, barW, barH
      orgBox 50, 0, barW, barH
      fill "#DFDFE0"
      font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
      strokeWeight 1

      # Draw a list of bars using a simple for loop.
      group "bar":
        box 20, 20 + 60 * 0, barW, 60

        text "text":
          box 0, 0, 70, 40
          fill "#46607e"
          font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
          characters fmt"progress: {bar:4.2f}"

        # Draw the decrement button to make the bar go down.
        bar = bar.clamp(0.001, 1.0)

        # Draw the bar itself.
        group "bar":
          box 100, 0, barW - 80*2, 40
          fill "#F7F7F9"
          cornerRadius 5
          rectangle "barFg":
            box 0, 0, (barW - 80*2) * float(bar), 40
            fill "#46D15F"
            cornerRadius 5
          onScroll:
            # echo "scrolled: ", mouse.wheelDelta
            bar += mouse.wheelDelta * 1.0e-3


startFidget(drawMain, uiScale=2.0)

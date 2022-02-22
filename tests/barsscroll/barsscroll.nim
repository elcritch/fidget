import bumpy, fidget, math, random

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

# Create an array of 30 bars.
var bars = newSeq[float](30)
for i, bar in bars:
  bars[i] = rand(1.0)

proc drawMain() =
  # Set the window title.
  setTitle("Fidget Bars Example")

  # Use simple math to layout things.
  let barH = bars.len.float32 * 60 + 20
  let barW = root.box().w - 100

  frame "main":
    box 0, 0, root.box().w, root.box().h - 20
    fill "#F7F7F9"
    clipContent true

    group "center":
      scrollable true

      box 50, 0, barW, barH
      fill "#DFDFE0"
      font "IBM Plex Sans", 16, 200, 0, hLeft, vCenter
      strokeWeight 1

      # Draw a list of bars using a simple for loop.
      for i, bar in bars.mpairs:
        group "bar":
          box 20, 20 + 60 * i, barW, 60

          text "text":
            box 61, 0, 70, 20
            fill "#46607e"
            characters "scroll " & $i

          # Draw the decrement button to make the bar go down.
          rectangle "dec":
            box 0, 0, 40, 40
            fill "#AEB5C0"
            cornerRadius 3
            onHover:
              fill "#46DE5F"
            onClick:
              bar -= 0.05
            instance "arrow":
              box 0, 0, 40, 40
              rotation -180
              image "arrow.png"

          # Draw the increment button to make the bar go up.
          rectangle "inc":
            box barW-80, 0, 40, 40
            fill "#AEB5C0"
            cornerRadius 3
            onHover:
              fill "#46DE5F"
            onClick:
              bar += 0.05
            instance "arrow":
              box 0, 0, 40, 40
              image "arrow.png"

          bar = bar.clamp(0.001, 1.0)

          # Draw the bar itself.
          group "bar":
            box 60, 0, barW - 80*2, 40
            fill "#F7F7F9"
            cornerRadius 5
            rectangle "barFg":
              box 0, 0, (barW - 80*2) * float(bar), 40
              fill "#46D15F"
              cornerRadius 5
            onScroll:
              # echo "scrolled: ", mouse.wheelDelta
              bar += mouse.wheelDelta * 1.0e-3


startFidget(drawMain, uiScale=1.5)

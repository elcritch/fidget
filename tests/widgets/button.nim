import bumpy, fidget
import fidgets

export fidget, fidgets

proc button*(
    message {.property: text.}: string,
    clicker {.property: onClick.}: WidgetProc = proc () = discard
): bool {.basicFidget, discardable.} =
  # Draw a progress bars 
  init:
    box 0, 0, 8.Em, 2.Em

  let
    bw = current.box().w
    bh = current.box().h

  cornerRadius 2
  rectangle "button":
    box 0, 0, bw, bh
    dropShadow 3, 0, 0, "#000000", 0.03
    cornerRadius 2
    fill "#BDBDBD"
    strokeLine 2, "#707070", 2.0
    onHover: 
      fill "#BEEBFD"
      strokeLine 4, "#4CA2D0", 2.0
    onClick:
      clicker()
      result = true

    text "text":
      box 0, 0, bw, bh
      fill "#565555"
      characters message

import bumpy, fidget
import widgets

export fidget, widgets

proc button*(
    message {.property: text.}: string,
    clicker {.property: onClick.}: WidgetProc = proc () = discard
): bool {.basicWidget, discardable.} =
  # Draw a progress bars 
  init:
    box 0, 0, 8.Em, 2.Em

  let
    bw = current.box().w
    bh = current.box().h

  cornerRadius 5
  rectangle "button":
    box 0, 0, bw, bh
    dropShadow 3, 0, 0, "#000000", 0.03
    cornerRadius parent.cornerRadius
    fill "#72bdd0"
    stroke "#72bdd0", 1.0
    strokeWeight 2
    onHover: 
      fill "#5C8F9C"
    onClick:
      clicker()
      result = true

    text "text":
      box 0, 0, bw, bh
      fill "#46607e"
      characters message

import fidget

type DropdownState = object
  open*: bool

proc dropdown*(state: var DropdownState) =

  group "dropdown":
    box 260, 115, 100, 20
    fill "#72bdd0"
    cornerRadius 5
    strokeWeight 1
    onHover:
      fill "#5C8F9C"
    onClick:
      state.open = not state.open
    instance "arrow":
      box 80, 0, 20, 20
      if state.open:
        rotation -90
      image "arrow.png"
    text "text":
      box 0, 0, 80, 20
      fill "#ffffff"
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
      characters "Dropdown"

    if state.open:
      frame "dropDown":
        box 0, 30, 100, 100
        fill "#ffffff"
        cornerRadius 5
        layout lmVertical
        counterAxisSizingMode csAuto
        horizontalPadding 0
        verticalPadding 0
        itemSpacing 0
        clipContent true
        for buttonName in reverse(@["Nim", "UI", "in", "100%", "Nim"]):
          group "button":
            box 0, 80, 100, 20
            layoutAlign laCenter
            fill "#72bdd0"
            onHover:
              fill "#5C8F9C"
            onClick:
              state.open = false
            text "text":
              box 0, 0, 100, 20
              fill "#ffffff"
              font "IBM Plex Sans", 12, 400, 0, hCenter, vCenter
              characters buttonName

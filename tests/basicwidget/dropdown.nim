
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc dropdown*(
    dropItems {.property: items.}: seq[string],
    dropSelected: var int,
) {.widget.} =
  ## dropdown widget 
  var
    dropDownOpen: bool
    dropDownToClose: bool

  group "dropdown":
    font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
    box 260, 115, 100, Em 1.8
    orgBox 260, 115, 100, Em 1.8
    fill "#72bdd0"
    cornerRadius 5
    strokeWeight 1
    onHover:
      fill "#5C8F9C"
    text "text":
      # textPadding: 0.375.em.int
      box 0, 0, 80, Em 1.8
      fill "#ffffff"
      strokeWeight 1
      characters "Dropdown"
    text "text":
      box 100-1.5.Em, 0, 1.Em, Em 1.8
      fill "#ffffff"
      if dropDownOpen:
        rotation -90
      characters ">"

    if dropDownOpen:
      group "dropDownScroller":
        box 0, Em 2.0, 100, 80
        clipContent true

        group "dropDown":
          box 0, 0, 100, 4.Em
          orgBox 0, 0, 100, 4.Em
          layout lmVertical
          counterAxisSizingMode csAuto
          horizontalPadding 0
          verticalPadding 0
          itemSpacing 0
          scrollBars true

          onClickOutside:
            dropDownOpen = false
            dropDownToClose = true

          for idx, buttonName in reversePairs(dropItems):
            rectangle "dash":
              box 0, 0.Em, 100, 0.1.Em
              fill "#ffffff", 0.6
            group "button":
              box 0, 0.Em, 100, 1.4.Em
              layoutAlign laCenter
              fill "#72bdd0", 0.9
              onHover:
                fill "#5C8F9C", 0.8
                dropDownOpen = true
              onClick:
                dropDownOpen = false
                echo "clicked: ", buttonName
                dropSelected = idx
              text "text":
                box 0, 0, 100, 1.4.Em
                fill "#ffffff"
                characters buttonName
    onClickOutside:
      dropDownToClose = false
    onClick:
      if not dropDownToClose:
        dropDownOpen = not dropDownOpen
      dropDownToClose = false

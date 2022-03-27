
import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output
import macros

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

var hooksCount {.compileTime.} = 0

proc dropdown*(
    dropItems {.property: items.}: seq[string],
    dropSelected: var int,
    state: Dropdown = nil,
) {.statefulwidget.} =
  ## dropdown widget 
  properties:
    dropDownOpen: bool
    dropDownToClose: bool

  group "dropdown":
    useState(Dropdown)

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
      if dropSelected < 0:
        characters "Dropdown"
      else:
        characters dropItems[dropSelected]
    text "text":
      box 100-1.5.Em, 0, 1.Em, Em 1.8
      fill "#ffffff"
      if self.dropDownOpen:
        rotation -90
      characters ">"

    if self.dropDownOpen:
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
            self.dropDownOpen = false
            self.dropDownToClose = true

          for idx, buttonName in reverseIndex(dropItems):
            rectangle "dash":
              box 0, 0.Em, 100, 0.1.Em
              fill "#ffffff", 0.6
            group "button":
              box 0, 0.Em, 100, 1.4.Em
              layoutAlign laCenter
              fill "#72bdd0", 0.9
              onHover:
                fill "#5C8F9C", 0.8
                self.dropDownOpen = true
              onClick:
                self.dropDownOpen = false
                echo "clicked: ", buttonName
                dropSelected = idx
              text "text":
                box 0, 0, 100, 1.4.Em
                fill "#ffffff"
                characters buttonName
    onClickOutside:
      self.dropDownToClose = false
    onClick:
      echo "dropdown"
      if not self.dropDownToClose:
        self.dropDownOpen = not self.dropDownOpen
      self.dropDownToClose = false

let dropItems = @["Nim", "UI", "in", "100%", "Nim", "to", 
                  "OpenGL", "Immediate", "mode"]
var dropIdx = 0

proc drawMain() =
  dropdown(dropItems, dropIdx)

startFidget(drawMain, uiScale=2.0)


import bumpy, fidget, math, random
import std/strformat
import asyncdispatch # This is what provides us with async and the dispatcher
import times, strutils # This is to provide the timing output
import macros

import widgets

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

proc dropdown*(
    dropItems {.property: items.}: seq[string],
    dropSelected: var int,
) {.statefulWidget.} =
  ## dropdown widget with internal state using `useState`
  properties:
    dropDownOpen: bool
    dropDownToClose: bool

  var
    cb = current.box()
    bw = cb.w || 8.Em
    bh = cb.h || 1.5.Em
    # bh = 1.8.Em
    bth = bh
    bih = bh * 0.8 # 1.4.Em
    # bdh = 100.Vh - 3*bth
    bdh = bih * min(5, dropItems.len()).float32
    tw = bw - 1.Em
  
  box cb.x, cb.y, bw, bh

  component "dropdown":

    font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
    box 0, 0, bw, bh
    orgBox 0, 0, bw, bh
    fill "#72bdd0"
    cornerRadius 5
    strokeWeight 1
    onHover:
      fill "#5C8F9C"
    text "text":
      box 0, 0, bw, bth
      fill "#ffffff"
      strokeWeight 1
      if dropSelected < 0:
        characters "Dropdown"
      else:
        characters dropItems[dropSelected]
    text "text":
      box tw, 0, 1.Em, bth
      fill "#ffffff"
      if self.dropDownOpen:
        rotation -90
      else:
        rotation 0
      characters ">"

    if self.dropDownOpen:
      group "dropDownScroller":
        box 0, bh, bw, bdh
        clipContent true

        group "dropDown":
          box 0, 0, bw+1, bdh
          orgBox 0, 0, bw, bdh
          layout lmVertical
          counterAxisSizingMode csAuto
          horizontalPadding 0
          verticalPadding 0
          itemSpacing -1
          scrollBars true

          onClickOutside:
            self.dropDownOpen = false
            self.dropDownToClose = true

          for idx, buttonName in pairs(dropItems):
            group "itembtn":
              box 0, 0, bw, bih
              layoutAlign laCenter
              fill "#72bdd0", 0.93
              stroke "#ffffff", 1.0
              strokeWeight 1.4
              onHover:
                fill "#5C8F9C", 1.0
                self.dropDownOpen = true
              onClick:
                self.dropDownOpen = false
                echo "clicked: ", buttonName
                dropSelected = idx
              text "text":
                box 0, 0, bw, bih
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
var dropIndexes = [-1, -1, -1]

var dstate = Dropdown()

proc drawMain() =
  frame "main":
    font "IBM Plex Sans", 16, 200, 0, hLeft, vBottom
    box 1.Em, 1.Em, 100.WPerc - 1.Em, 100.HPerc - 1.Em
    # offset 1.Em, 1.Em
    # size 100.WPerc - 1.Em, 100.HPerc - 1.Em

    Vertical:
      strokeLine 1.0, "#46D15F", 1.0
      itemSpacing 1.Em

      text "first desc":
        size 100.WPerc, 1.Em
        fill "#000d00"
        characters "Dropdown example: "

      dropdown(dropItems, dropIndexes[0], dstate)
      dropdown(dropItems, dropIndexes[1], nil)
      text "desc":
        size 100.WPerc, 1.Em
        fill "#000d00"
        characters "linked dropdowns: "
      dropdown(dropItems, dropIndexes[2])
      Widget dropdown:
        items: dropItems
        dropSelected: dropIndexes[2]
        setup: box 0, 0, 12.Em, 2.Em
      Widget dropdown:
        self: dstate
        items: dropItems
        dropSelected: dropIndexes[2]
        setup: box 0, 0, 12.Em, 2.Em
      
    # dropdown(dropItems, dropIndexes[2], nil) do:
      # box 30, 80, 10.Em, 1.5.Em
    # dropdown(dropItems, dropIndexes[2], nil) do:
      # box 30, 120, 10.Em, 1.5.Em

startFidget(drawMain, uiScale=2.0)

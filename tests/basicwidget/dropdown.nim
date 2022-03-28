
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
) {.statefulwidget.} =
  ## dropdown widget 
  properties:
    dropDownOpen: bool
    dropDownToClose: bool

  let
    bw = current.box().w
    bh = 1.8.Em
    bth = 1.8.Em
    bih = 1.4.Em
    bdh = 10.Em
    tw = bw - 1.Em

  group "dropdown":

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
          box 0, 0, bw, bdh
          orgBox 0, 0, bw, bdh
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
              box 0, 0, bw, 0.1.Em
              fill "#ffffff", 0.6
            group "itembtn":
              box 0, 0, bw, bih
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
var dropIndexes: array[3, int]

proc drawMain() =
  frame "main":
    font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
    box 0, 0, 100.WPerc, 100.HPerc

    Horizontal:
      box 0, 0, 100.WPerc, 100.HPerc
      itemSpacing 1.Em

      dropdown(dropItems, dropIndexes[0], nil) do:
        box 0, 0, 10.Em, 2.Em
      dropdown(dropItems, dropIndexes[1], nil) do:
        box 0, 0, 10.Em, 2.Em
      dropdown(dropItems, dropIndexes[2], nil) do:
        box 0, 0, 10.Em, 2.Em

startFidget(drawMain, uiScale=2.0)

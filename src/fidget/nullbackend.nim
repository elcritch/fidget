## Backend null is a dummy backend used for testing / dec gen
## Not a real backend will not draw anything

import internal, tables, times, uibase

var
  windowTitle: string
  values = newTable[string, string]()

proc draw*(group: Group) =
  ## Draws the group

proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = true

proc openBrowser*(url: string) =
  ## Opens a URL in a browser
  discard

proc goto*(url: string) =
  ## Goes to a new URL, inserts it into history so that back button works
  discard

proc startFidget*(draw: proc()) =
  ## Starts fidget UI library
  ## Null backend only draws drawMain() once
  drawMain = draw
  let startTime = epochTime()
  setupRoot()
  drawMain()
  echo "drawMain walk took: ", epochTime() - startTime, "ms"

proc setTitle*(title: string) =
  ## Sets window title
  windowTitle = title

proc getTitle*(): string =
  ## Gets window title
  windowTitle

proc `url=`*(win: uibase.Window, url: string) =
  ## Sets window url
  win.innerUrl = url

proc `url`*(win: uibase.Window): string =
  ## Gets window url
  return win.innerUrl

proc loadFont*(name: string, pathOrUrl: string) =
  ## Loads a font.
  discard

proc setItem*(key, value: string) =
  ## Saves value in memory only.
  values[key] = value

proc getItem*(key: string): string =
  ## Gets a value in memory only.
  values[key]

import macros, tables, strutils, strformat

macro Widget(name, blk: untyped) =
  echo treeRepr(blk)

Widget(progressBar):
  
  type Properties = object
    bar*: BarValue
    speed: int 
    count: int = 1

  constructor:
    count = 1

  body:
    # Set the window title.
    setTitle("Fidget Animated Progress Example")

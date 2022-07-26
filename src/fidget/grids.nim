import prelude
import rationals
import variant
import commonutils
import hashes
import sets

type
  GridConstraint* = enum
    gcStart
    gcEnd
    gcScale
    gcStretch
    gcCenter

  GridUnits* = enum
    grFrac
    grAuto
    grUICoord

  TrackSize* = object
    case kind*: GridUnits
    of grFrac:
      frac*: int
    of grAuto:
      discard
    of grUICoord:
      coord*: UICoord
  
  ItemLocation* = object
    line*: int8
    isSpan*: bool
    isAuto*: bool
  
  GridName* = distinct Hash

  GridLine* = object
    lineNames*: HashSet[GridName]
    trackSize*: TrackSize

  GridTemplate* = ref object
    columns*: seq[GridLine]
    rowGap*: UICoord
    columnGap*: UICoord
    justifyItems*: GridConstraint
    alignItems*: GridConstraint

  GridStyle* = ref object
    columnStart*: ItemLocation
    columnEnd*: ItemLocation
    rowStart*: ItemLocation
    rowEnd*: ItemLocation

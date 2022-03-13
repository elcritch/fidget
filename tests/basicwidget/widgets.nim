import macros, tables, strutils, strformat

iterator attributes(blk: NimNode): (int, string, NimNode) =
  for idx, item in blk:
    if item.kind == nnkCall:
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, code)

# iterator splitAttributes(blk: var NimNode): TableRef[string, NimNode] =
#   result = newTable[string, NimNode]()
#   var others = newStmtList()
#   for item in blk:
#     if item.kind == nnkCall:
#       var name = item[0].repr
#       var code = item[1]
#       result[name] = code
#     else:
#       others.add item
#   blk = others

proc makeType(name: string, body: NimNode): NimNode =
  echo "\nprops: "
  var propDefs = newTable[string, NimNode]()
  var propTypes = newTable[string, NimNode]()

  for prop in body:
    prop.expectKind(nnkCall)
    prop[0].expectKind(nnkIdent)
    # echo "prop: ", treeRepr prop
    let pname = prop[0].strVal
    let pHasDefault = prop[1][0].kind == nnkAsgn
    if pHasDefault:
      propTypes[pname] = prop[1][0][0]
      propDefs[pname] = prop[1][0][1]
    else:
      propTypes[pname] = prop[1][0]
  
  echo "propTypes: "
  result = newStmtList()
  let tpName = ident(name)
  var tp = quote do:
    type `tpName` = ref object
      a: int
  # echo "tp: ", tp.treeRepr
  var rec = newNimNode(nnkRecList)
  for pd, pv in propTypes:
    echo "pd: ", pd, " => ", pv.treeRepr
    rec.add newIdentDefs(ident pd, pv)
  # echo "tp:Rec: ", tp.treeRepr
  tp[0][^1][0][^1] = rec
  # echo "tp:Rec: ", tp.treeRepr
  result.add tp
  # echo "propDefs: "
  # for pd, pv in propDefs:
    # echo "pd: ", pd, " => ", pv.treeRepr

macro Widget*(name, blk: untyped) =
  var body = blk
  let typeName = name.strVal.capitalizeAscii()
  var impl: NimNode
  for idx, name, code in body.attributes():
    echo fmt"{idx=} {name=}"
    body[idx] = newStmtList()
    echo "widget:property: ", name
    case name:
    of "body":
      impl = code
    of "properties":
      # echo code.treeRepr
      let wType = typeName.makeType(code)
      echo fmt"{wType.repr=}"
      let wInit = typeName.makeType(code)
      echo fmt"{wType.repr=}"
      body[idx] = wType

  result = newStmtList()
  result.add quote do:
    `body`
    proc `name`() = 
      echo "hi" # `impl`
  echo "Widget: "
  echo result.repr

macro WidgetBody*(blk: untyped) =
  result = newStmtList()
  result = quote do:
    var obj: MyWidget
    while true:
      `blk`
      yield

macro Properties*(blk: untyped) =
  result = newStmtList()
  result = quote do:
    type
      `blk`
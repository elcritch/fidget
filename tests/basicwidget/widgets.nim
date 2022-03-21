import macros, tables, strutils, strformat

type
  WidgetProc* = proc()

template property*(name: untyped) {.pragma.}

iterator attributes*(blk: NimNode): (int, string, NimNode) =
  for idx, item in blk:
    if item.kind == nnkCall:
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, code)

iterator propertyNames*(params: NimNode): (int, string, string, NimNode) =
  for idx, item in params[1..^1]:
    echo "PROPERTYNAMES: KIND: ", item.kind
    echo "PROPERTYNAMES: ", item.treeRepr
    if item.kind == nnkEmpty:
      continue
    elif item.kind == nnkIdentDefs:
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, "", code)
    elif item.kind == nnkPragmaExpr:
      var item = item[0]
      var name = item[0].repr
      var pname = item[1][0][1].strVal
      var code = item[1]
      yield (idx, name, pname, code)
    elif item.kind == nnkPragmaExpr:
      var item = item[0]
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, "", code)

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
  var rec = newNimNode(nnkRecList)
  for pd, pv in propTypes:
    echo "pd: ", pd, " => ", pv.treeRepr
    rec.add newIdentDefs(ident pd, pv)
  tp[0][^1][0][^1] = rec
  result.add tp

macro widget*(blk: untyped) =
  var
    procDef = blk
    body = procDef.body()
    params = procDef.params()
    preBody = newStmtList()

  let
    procName = procDef.name().strVal
    typeName = procName.capitalizeAscii()
    preName = ident("setup")
    postName = ident("post")

  echo "typeName: ", typeName
  # echo "widget: ", treeRepr bl
  var impl: NimNode
  var hasProperty = false

  for idx, name, code in body.attributes():
    echo fmt"{idx=} {name=}"
    body[idx] = newStmtList()
    echo "widget:property: ", name
    case name:
    of "Body":
      impl = code
    of "Properties":
      hasProperty = true
      let wType = typeName.makeType(code)
      preBody.add wType

  procDef.body= quote do:
    group `typeName`:
      if `preName` != nil:
        `preName`()
      `body`
      if `postName` != nil:
        `postName`()
  
  let
    nilValue = quote do: nil
    stateArg = newIdentDefs(ident("self"), ident(typeName))
    preArg = newIdentDefs(preName, bindSym"WidgetProc", nilValue)
    postArg = newIdentDefs(ident("post"), bindSym"WidgetProc", nilValue)
  
  echo "procTp: ", preArg.treeRepr
  if hasProperty:
    params.add stateArg
  params.add preArg
  params.add postArg 
  echo "params: ", treeRepr params

  let ptable = ident "ptable"
  var propTableDecl = newStmtList()
  propTableDecl.add quote do:
    var `ptable` = initTable[string, (string, bool)]()
  
  for idx, argname, propname, argtype in params.propertyNames():
    let pname = if propname == "": argname else: propname
    echo "prop label: ", pname, " => ", argname
    echo "prop type: ", argtype.treeRepr
    let isProc = newLit(argtype.repr == "WidgetProc")

    propTableDecl.add quote do:
      `ptable`[`pname`] = (`argname`, `isProc`, )

  var
    dbTpName = newStrLitNode typeName
    labelMacroName = ident typeName
    labelMacroDef = quote do:
      macro `labelMacroName`*(body: untyped) =
        `propTableDecl`
        var args = newSeq[NimNode]()
        for idx, name, code in body.attributes():
          if `ptable`.hasKey(name):
            let pn = `ptable`[name][0]
            echo "LABEL:", `dbTpName`, ": ", name, " => ", pn
            var pa = newNimNode(nnkExprEqExpr)
            pa.add(ident(pn)).add(code)
            args.add pa
        result = newCall(`procName`, args)
        echo "\n=== Widget Call === "
        echo result.repr

  result = newStmtList()
  result.add preBody 
  result.add procDef
  result.add labelMacroDef 
  echo "\n=== Widget === "
  echo result.repr

macro AppWidget*(pname, blk: untyped) =
  var
    # procDef = blk
    # body = procDef.body()
    body = blk
    preBody = newStmtList()

  let
    procName = ident "widget"
    typeName = pname.strVal().capitalizeAscii()
    groupName = newNimNode(nnkStrLit, pname)
    preName = ident("setup")
    postName = ident("post")

  # echo "typeName: ", typeName
  # echo "widget: ", treeRepr blk

  var impl: NimNode
  var hasProperty = false

  for idx, name, code in body.attributes():
    echo fmt"{idx=} {name=}"
    body[idx] = newStmtList()
    # echo "widget:property: ", name
    case name:
    of "Body":
      impl = code
    of "Properties":
      hasProperty = true
      let wType = typeName.makeType(code)
      preBody.add wType

  var procDef = quote do:
    proc `procName`*() =
      group `groupName`:
        if `preName` != nil:
          `preName`()
        `body`
        if `postName` != nil:
          `postName`()
  var
    params = procDef.params()

  let
    nilValue = quote do: nil
    stateArg = newIdentDefs(ident("self"), ident(typeName))
    preArg = newIdentDefs(preName, bindSym"WidgetProc", nilValue)
    postArg = newIdentDefs(ident("post"), bindSym"WidgetProc", nilValue)
  
  # echo "procTp: ", preArg.treeRepr
  if hasProperty:
    params.add stateArg
  params.add preArg
  params.add postArg 
  # echo "params: ", treeRepr params

  result = newStmtList()
  result.add preBody 
  result.add procDef
  # echo "\n=== Widget === "
  # echo result.repr


import macros, tables, strutils, strformat

type
  WidgetProc* = proc()

template property*(name: untyped) {.pragma.}

proc makeLambdaDecl(
    pargname: NimNode,
    argtype: NimNode,
    code: NimNode,
): NimNode =
  result = nnkLetSection.newTree(
    nnkIdentDefs.newTree(
      pargname,
      argtype,
      nnkLambda.newTree(
        newEmptyNode(),
        newEmptyNode(),
        newEmptyNode(),
        nnkFormalParams.newTree(newEmptyNode()),
        newEmptyNode(),
        newEmptyNode(),
        code,
      )
    )
  )

iterator attributes*(blk: NimNode): (int, string, NimNode) =
  for idx, item in blk:
    if item.kind == nnkCall:
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, code)

iterator propertyNames*(params: NimNode): (int, string, string, NimNode) =
  for idx, item in params:
    # echo "PROPERTYNAMES: KIND: ", item.kind
    # echo "PROPERTYNAMES: ", item.treeRepr
    if item.kind == nnkEmpty:
      continue
    elif item.kind == nnkIdentDefs and item[0].kind == nnkPragmaExpr:
      var name = item[0][0].repr
      var pname = item[0][1][0][1].strVal
      var code = item[1]
      yield (idx, name, pname, code)
    elif item.kind == nnkIdentDefs and item[0].kind == nnkIdent:
      var name = item[0].repr
      var code = item[1]
      yield (idx, name, "", code)

proc makeType(name: string, body: NimNode): NimNode =
  # echo "\nprops: "
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
  
  # echo "propTypes: "
  result = newStmtList()
  let tpName = ident(name)
  var tp = quote do:
    type `tpName` = ref object
      a: int
  var rec = newNimNode(nnkRecList)
  for pd, pv in propTypes:
    # echo "pd: ", pd, " => ", pv.treeRepr
    rec.add newIdentDefs(ident pd, pv)
  tp[0][^1][0][^1] = rec
  result.add tp

var widgetArgsTable* {.compileTime.} = initTable[string, seq[(string, string, NimNode, )]]()

macro with*(widget, body: untyped): untyped =
  echo "WITH: ", widget.repr
  echo "WITH: ", body.repr
  let procName = widget.strVal

  result = newStmtList()
  var attrs = initTable[string, NimNode]()
  for idx, name, code in body.attributes():
    attrs[name] = code
  var args = newSeq[NimNode]()
  let widgetArgs = widgetArgsTable[procName]
  echo "WITH: widgetArgs: ", widgetArgs.repr
  
  result = newStmtList()
  for (argname, propname, argtype) in widgetArgs:
    # echo "ARGNAME: ", argname
    # echo "PROPNAME: ", propname
    if argtype.repr == "WidgetProc" and attrs.hasKey(propname):
      let pargname = genSym(nskLet, argname & "Arg")
      let code =
        if attrs.hasKey(propname): attrs[propname]
        else: nnkDiscardStmt.newTree(newEmptyNode())
      let pdecl = makeLambdaDecl(pargname, argtype, code)
      # echo "PROCDECL: ", pdecl.repr
      result.add pdecl
      args.add newNimNode(nnkExprEqExpr).
        add(ident(argname)).add(pargname)
    elif argtype.repr == "WidgetProc":
      args.add newNimNode(nnkExprEqExpr).
        add(ident(argname)).add(newNilLit())
    else:
      let code =
        if attrs.hasKey(propname): attrs[propname]
        else: newNilLit()
      # echo "CODE: ", code.repr
      args.add newNimNode(nnkExprEqExpr).
        add(ident(argname)).add(code)
  result.add newCall(`procName`, args)

proc makeWidgetPropertyMacro(procName, typeName: string): NimNode =
  let
    labelMacroName = ident typeName
    wargsTable = ident "widgetArgsTable"

  var labelMacroDef = quote do:
    template `labelMacroName`*(body: untyped) =
      with `procName`, body

  result = newStmtList()
  result.add labelMacroDef
  echo "\n=== Widget: makeWidgetPropertyMacro === "
  echo result.repr

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

  # echo "typeName: ", typeName
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
  
  # echo "procTp: ", preArg.treeRepr
  if hasProperty:
    params.add stateArg
  params.add preArg
  params.add postArg 
  # echo "params: ", treeRepr params

  var widgetArgs = newSeq[(string, string, NimNode)]()
  for idx, argname, propname, argtype in params.propertyNames():
    let pname = if propname == "": argname else: propname
    # echo "PROP label: ", pname, " => ", argname
    # echo "PROP type: ", argtype.treeRepr
    widgetArgs.add( (argname, pname, argtype,) )

  widgetArgsTable[procName] = widgetArgs


  result = newStmtList()
  result.add preBody 
  result.add procDef
  result.add makeWidgetPropertyMacro(procName, typeName) 
  # echo "\n=== Widget === "
  # echo result.repr

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

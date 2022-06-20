## A bunch of nice looking controls.

import fidget

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")
loadFont("IBM Plex Sans Bold", "IBMPlexSans-Bold.ttf")

var
  textInputVar = ""
  checkBoxValue: bool
  radioBoxValue: int
  selectedTab = "Controls"
  selectedButton = @["This"]
  pipDrag = false
  pipPos = 89
  progress = 20.0
  dropDownOpen = false
  dropDownToClose = false
  dropSelected = ""

proc basicText() =
  frame "autoLayoutText":
    box 130, 0, root.box.w - 130, root.box.h
    fill "#ffffff"
    layout lmVertical
    counterAxisSizingMode csFixed
    horizontalPadding 30
    verticalPadding 30
    itemSpacing 10
    scrollBars true
    text "p2":
      box 30, 361, 326, 100
      fill "#000000"
      font "IBM Plex Sans", 14, 400, 0, hLeft, vTop
      characters "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
      textAutoResize tsHeight
      layoutAlign laStretch
    text "title2":
      box 30, 319, 326, 32
      fill "#000000"
      font "IBM Plex Sans", 20, 400, 0, hLeft, vTop
      characters "Lorem Ipsum"
      textAutoResize tsHeight
      layoutAlign laStretch
    text "imgCaption":
      box 30, 289, 326, 20
      fill "#9c9c9c"
      font "IBM Plex Sans", 14, 400, 0, hCenter, vTop
      characters "Lorem ipsum dolor sit ame"
      textAutoResize tsHeight
      layoutAlign laStretch
    rectangle "imgPlaceholder":
      box 125.5, 182, 135, 97
      fill "#5C8F9C"
      layoutAlign laCenter
    text "p1":
      box 30, 72, 326, 100
      fill "#000000"
      font "IBM Plex Sans", 14, 400, 20, hLeft, vTop
      characters "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
      textAutoResize tsHeight
      layoutAlign laStretch
    text "title1":
      box 30, 30, 326, 32
      fill "#000000"
      font "IBM Plex Sans", 20, 400, 32, hLeft, vTop
      characters "Lorem Ipsum"
      textAutoResize tsHeight
      layoutAlign laStretch

proc basicControls() =

  let dropItems = @["Nim", "UI", "in", "100%", "Nim", "to", 
                    "OpenGL", "Immediate", "mode"]

  group "dropdown":
    font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
    box 260, 115, 100, Em 1.8
    orgBox 260, 115, 100, Em 1.8
    fill "#72bdd0"
    cornerRadius 5
    strokeWeight 1
    onHover:
      highlight "#5C8F9C"
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
        highlight clearColor

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

          for buttonName in reverse(dropItems):
            rectangle "dash":
              box 0, 0.Em, 100, 0.1.Em
              fill "#ffffff", 0.6
            group "button":
              box 0, 0.Em, 100, 1.4.Em
              layoutAlign laCenter
              fill "#72bdd0", 0.9
              onHover:
                highlight "#5C8F9C", 0.8
                dropDownOpen = true
              onClick:
                dropDownOpen = false
                # echo "clicked: ", buttonName
                dropSelected = buttonName
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

  group "progress":
    font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
    text "text":
      box 370, 115, 250, 1.8.Em
      fill "#72bdd0"
      strokeWeight 1
      characters "selected: " & dropSelected
    

  group "progress":
    box 260, 149, 250, 12
    fill "#ffffff"
    stroke "#70bdcf"
    cornerRadius 5
    strokeWeight 1
    rectangle "fill":
      progress = selectedButton.len / 5 * 100 + 1
      let pw = progress/100 * (parent.box.w - 4).
                clamp(1.0, parent.box.w)
      box 2, 2, pw, 8
      fill "#9fe7f8"
      cornerRadius 5

  group "checkbox":
    box 152, 85, 91, 20
    onClick:
      checkBoxValue = not checkBoxValue
    rectangle "square":
      box 0, 2, 16, 16
      if checkBoxValue:
        fill "#9FE7F8"
        text "text":
          font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter
          box 0, 0, 12, 16
          fill "#46607e"
          characters "✓"
      else:
        fill "#ffffff"
      stroke "#70bdcf"
      cornerRadius 5
      strokeWeight 1
    
    text "text":
      box 21, 0, 70, 20

      fill "#46607e"
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
      characters "Checkbox"

  group "radiobox":
    box 152, 115, 100, 20
    orgBox 152, 115, 100, 20
    layout lmVertical
    counterAxisSizingMode csAuto
    horizontalPadding 0
    verticalPadding 0
    itemSpacing 0

    for i in countdown(2,0):
      group "radiobox":
        box 0, 0, 100, 20
        onClick:
          radioBoxValue = i
        rectangle "circle":
          box 0, 2, 16, 16
          if radioBoxValue == i:
            fill "#9FE7F8"
            text "text":
              box 0, 0, 14, 16
              fill "#46607e"
              strokeWeight 1
              font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
              characters "✓"
          else:
            fill "#ffffff"
          stroke "#72bdd0"
          cornerRadius 8
          strokeWeight 1
        text "text":
          box 21, 0, 70, 20
          fill "#46607e"
          strokeWeight 1
          font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
          characters "Radio " & $i
    
    text "text":
      box 0, 0, 100, 20
      fill "#46607e"
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
      characters "Radiobox"


  group "slider":
    box 260, 90, 250, 10
    onClick:
      pipDrag = true
    if pipDrag:
      pipPos = int(mouse.x - current.screenBox.x)
      pipPos = clamp(pipPos, 1, 240)
      pipDrag = buttonDown[MOUSE_LEFT]
    rectangle "pip":
      box pipPos, 0, 10, 10
      fill "#72bdd0"
      cornerRadius 5
    rectangle "fill":
      box 0, 3, pipPos, 4
      fill "#70bdcf"
      cornerRadius 2
      strokeWeight 1
    rectangle "bg":
      box 0, 3, 250, 4
      fill "#c2e3eb"
      cornerRadius 2
      strokeWeight 1

  frame "segmentedControl":
    box 260, 55, 250, 20
    fill "#72bdd0"
    cornerRadius 5
    clipContent true
    layout lmHorizontal
    counterAxisSizingMode csAuto
    horizontalPadding 0
    verticalPadding 0
    itemSpacing 0
    for buttonName in @["This", "is", "a", "segmented", "button"]:
      group "Button":
        box 0, 0, buttonName.len * 9 + 10, 20
        layoutAlign laCenter
        fill clearColor
        if buttonName in selectedButton:
          fill "#ffffff", 0.5
        onHover:
          highlight "#5C8F9C", 0.33
        onClick:
          if buttonName in selectedButton:
            selectedButton.del(selectedButton.find(buttonName))
          else:
            selectedButton.add(buttonName)
        text "text":
          box 0, 0, buttonName.len * 9 + 10, 20
          fill "#ffffff"
          font "IBM Plex Sans", 12, 400, 0, hCenter, vCenter
          characters buttonName
      rectangle "separator":
        box 0, 0, 1, 20
        fill "#ffffff", 0.5

  group "button":
    box 150, 55, 90, 20
    cornerRadius 5
    fill "#72bdd0"
    onHover:
      highlight "#5C8F9C"
    onDown:
      fill "#3E656F"
    text "text":
      box 0, 0, 90, 20
      fill "#ffffff"
      font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
      characters "Button"

  group "input":
    box 260, 15, 250, 30
    text "text":
      box 9, 8, 232, 15
      fill "#46607e"
      highlight "#46607e", 0.4
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
      binding textInputVar
    text "textPlaceholder":
      box 9, 8, 232, 15
      fill "#46607e", 0.5
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
      if textInputVar.len() > 0:
        fill clearColor
      characters "Start typing here"
    rectangle "bg":
      box 0, 0, 250, 30
      stroke "#72bdd0"
      cornerRadius 5
      strokeWeight 1

  group "label":
    box 150, 15, 100, 30
    text "Text field:":
      box 0, 0, 100, 30
      fill "#46607e"
      strokeWeight 1
      font "IBM Plex Sans", 12, 200, 0, hLeft, vCenter
      characters "Text field:"

proc basicImage() =
  frame "images":
    box 130, 0, 400, 400
    fill "#ffffff"
    scrollBars true
    group "img1":
      box 260, 260, 100, 100
      image "img1.png"
    group "img2":
      box 260, 150, 100, 100
      image "img2.png"
    group "img3":
      box 260, 40, 100, 100
      image "img3.png"
    group "img4":
      box 150, 260, 100, 100
      image "img4.png"
    group "img5":
      box 150, 150, 100, 100
      image "img5.png"
    group "img6":
      box 150, 40, 100, 100
      image "img6.png"
    group "img7":
      box 40, 260, 100, 100
      image "img7.png"
    group "img8":
      box 40, 150, 100, 100
      image "img8.png"
    group "img9":
      box 40, 40, 100, 100
      image "img9.png"

proc basicConstraints() =
  frame "constraints":
    # Got to specify orgBox for constraints to work.
    # Then grow the normal box.
    box 130, 0, root.box.w - 130, root.box.h
    orgBox 0, 0, 400, 400
    # Constraints will work on the difference between orgBox and box.
    fill "#ffffff"

    rectangle "Center":
      box 150, 150, 100, 100
      constraints cCenter, cCenter
      fill "#FFFFFF", 0.50
    rectangle "Scale":
      box 100, 100, 200, 200
      constraints cScale, cScale
      fill "#FFFFFF", 0.25
    rectangle "LRTB":
      box 40, 40, 320, 320
      constraints cStretch, cStretch
      fill "#70BDCF"

    rectangle "TR":
      box 360, 20, 20, 20
      constraints cMax, cMin
      fill "#70BDCF"
    rectangle "TL":
      box 20, 20, 20, 20
      constraints cMin, cMin
      fill "#70BDCF"
    rectangle "BR":
      box 360, 360, 20, 20
      constraints cMax, cMax
      fill "#70BDCF"
    rectangle "BL":
      box 20, 360, 20, 20
      constraints cMin, cMax
      fill "#70BDCF"

proc drawMain() =
  setTitle("Fidget Example")

  group "button":
    box 0, 0, 90, 20
    cornerRadius 5
    fill "#72bdd0", 0.2
    onHover:
      highlight "#5C8F9C"
    onDown:
      fill "#3E656F"
    onClick:
      echo "button: "
      dumpTree(root)
    text "text":
      box 0, 0, 90, 20
      fill "#ffffff"
      font "IBM Plex Sans", 12, 200, 0, hCenter, vCenter
      characters "Button"

  component "iceUI":
    orgBox 0, 0, 530, 185
    boxOf root
    fill "#ffffff"

    group "shadow":
      orgBox 0, 0, 530, 3
      box 0, 0, root.box.w, 3
      rectangle "l1":
        box 0, 0, 530, 1
        constraints cStretch, cMin
        fill "#000000", 0.10
      rectangle "l2":
        box 0, 1, 530, 1
        constraints cStretch, cMin
        fill "#000000", 0.07
      rectangle "l3":
        box 0, 2, 530, 1
        constraints cStretch, cMin
        fill "#000000", 0.03

    frame "verticalTabs":
      box 0, 15, 130, 120
      layout lmVertical
      counterAxisSizingMode csAuto
      horizontalPadding 0
      verticalPadding 0
      itemSpacing 0

      for tabName in ["Constraints", "Image", "Text", "Controls"]:
        group "tab":
          box 0, 0, 130, 30
          fill clearColor
          layoutAlign laCenter
          onHover:
            highlight "#70bdcf", 0.5
          if selectedTab == tabName:
            fill "#70bdcf"
          onClick:
            selectedTab = tabName
          text "text":
            box 25, 0, 105, 30
            if selectedTab == tabName:
              fill "#ffffff"
            else:
              fill "#46607e"
            font "IBM Plex Sans", 12, 400, 0, hLeft, vCenter
            characters tabName

    rectangle "bg":
      box 0, 0, 130, 185
      constraints cMin, cStretch
      fill "#e5f7fe"

    case selectedTab:
      of "Controls":
        basicControls()
      of "Text":
        basicText()
      of "Image":
        basicImage()
      of "Constraints":
        basicConstraints()

startFidget(drawMain, w = 530, h = 300, uiScale=3.0)
